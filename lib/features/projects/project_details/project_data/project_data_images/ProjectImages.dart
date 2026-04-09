import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/data/services/employee_name_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

typedef _DiaryViewData =
    ({
      QuerySnapshot<Map<String, dynamic>> snapshot,
      Map<String, String> authorNames,
    });

/// Projekt napló: rövid–közepes posztok képekkel (`projects/{projectId}/diary`).
class ProjectImagesScreen extends StatefulWidget {
  final String projectId;
  const ProjectImagesScreen({super.key, required this.projectId});

  @override
  State<ProjectImagesScreen> createState() => _ProjectImagesScreenState();
}

class _ProjectImagesScreenState extends State<ProjectImagesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final List<XFile> _attachments = [];
  bool _isSending = false;

  /// Görgethető tartalom alsó paddingje, hogy a FAB ne takarja az utolsó elemet.
  static const double _kFabScrollPadding = 96;

  /// A bejegyzés naptári napja. Ha nem a mai nap: [createdAt] csak dátum (éjfél), idő nélkül.
  late DateTime _postDate;

  /// Egy példány – ha minden [build]-ben új stream lenne, a billentyűzet (újrarajz)
  /// újrafeliratkozást okozna, és villogna / újratöltene a lista.
  late final Stream<_DiaryViewData> _diaryStreamWithAuthors;

  static final _dateFmt = DateFormat('yyyy. MM. dd. HH:mm', 'hu');
  static final _postDateOnlyFmt = DateFormat('yyyy. MM. dd.', 'hu');

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _postDate = DateTime(n.year, n.month, n.day);
    _diaryStreamWithAuthors = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('diary')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          final uids = <String>{};
          for (final d in snap.docs) {
            final uid = d.data()['authorUid'] as String?;
            if (uid != null && uid.isNotEmpty) uids.add(uid);
          }
          final names = await EmployeeNameService.getEmployeeNames(
            uids.toList(),
          );
          return (snapshot: snap, authorNames: names);
        });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  DateTime _effectiveCreatedAt() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chosenDay = DateTime(_postDate.year, _postDate.month, _postDate.day);
    if (chosenDay == today) {
      return now;
    }
    return chosenDay;
  }

  Future<void> _pickPostDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _postDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _postDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickImages([VoidCallback? onChanged]) async {
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() => _attachments.addAll(picked));
      onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nem sikerült képet választani: $e')),
      );
    }
  }

  void _removeAttachment(int index, [VoidCallback? onChanged]) {
    setState(() => _attachments.removeAt(index));
    onChanged?.call();
  }

  String _contentTypeFor(XFile x) {
    final m = x.mimeType;
    if (m != null && m.isNotEmpty) return m;
    final p = x.path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _extensionForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) return '.jpg';
    return '.jpg';
  }

  Future<bool> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Írj szöveget vagy csatolj legalább egy képet.'),
        ),
      );
      return false;
    }

    setState(() => _isSending = true);

    try {
      final diaryRef =
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('diary')
              .doc();
      final entryId = diaryRef.id;

      final List<String> imageUrls = [];
      for (var i = 0; i < _attachments.length; i++) {
        final x = _attachments[i];
        final ext = _extensionForPath(x.path);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final path =
            'project_diary/${widget.projectId}/$entryId/${stamp}_$i$ext';
        final ref = FirebaseStorage.instance.ref(path);
        final bytes = await File(x.path).readAsBytes();
        await ref.putData(
          bytes,
          SettableMetadata(contentType: _contentTypeFor(x)),
        );
        imageUrls.add(await ref.getDownloadURL());
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      await diaryRef.set({
        'text': text,
        'imageUrls': imageUrls,
        'createdAt': Timestamp.fromDate(_effectiveCreatedAt()),
        if (uid != null) 'authorUid': uid,
      });

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .update({'updatedAt': FieldValue.serverTimestamp()});

      if (!mounted) return false;
      _textController.clear();
      final today = DateTime.now();
      setState(() {
        _attachments.clear();
        _postDate = DateTime(today.year, today.month, today.day);
      });
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bejegyzés elmentve')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mentési hiba: $e')));
      return false;
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openComposerSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      isDismissible: false,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, sheetSetState) {
              final colorScheme = Theme.of(sheetContext).colorScheme;
              final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 8.0,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Új bejegyzés',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed:
                                    () => Navigator.of(sheetContext).pop(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _attachments.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final file = _attachments[index];
                                return _AttachmentThumb(
                                  file: file,
                                  onRemove:
                                      () => _removeAttachment(
                                        index,
                                        () => sheetSetState(() {}),
                                      ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        TextField(
                          controller: _textController,
                          focusNode: _textFocusNode,
                          minLines: 1,
                          maxLines: 6,
                          enabled: !_isSending,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Poszt szövege…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.all(16),
                              ),
                              onPressed:
                                  _isSending
                                      ? null
                                      : () async {
                                        await _pickPostDate();
                                        if (mounted) sheetSetState(() {});
                                      },
                              icon: const Icon(
                                LucideIcons.calendarDays,
                                size: 18,
                              ),
                              label: Text(_postDateOnlyFmt.format(_postDate)),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.all(16),
                              ),
                              onPressed:
                                  _isSending
                                      ? null
                                      : () => _pickImages(
                                        () => sheetSetState(() {}),
                                      ),
                              icon: const Icon(LucideIcons.imagePlus),
                              label: const Text('Kép'),
                            ),
                            const Spacer(),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap:
                                  _isSending
                                      ? null
                                      : () async {
                                        final ok = await _send();
                                        if (ok && sheetContext.mounted) {
                                          Navigator.of(sheetContext).pop();
                                        }
                                        if (mounted) sheetSetState(() {});
                                      },
                              borderRadius: BorderRadius.circular(28),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primaryContainer,
                                ),
                                child: Center(
                                  child:
                                      _isSending
                                          ? SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.primary,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.send_rounded,
                                            size: 24,
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final scrollBottomPad =
        16 + _kFabScrollPadding + MediaQuery.viewPaddingOf(context).bottom + 16;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: StreamBuilder<_DiaryViewData>(
            stream: _diaryStreamWithAuthors,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPad),
                    child: Text(
                      'Nem sikerült betölteni a naplót: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                );
              }

              final view = snapshot.data;
              final docs = view?.snapshot.docs ?? [];
              final authorNames = view?.authorNames ?? {};
              if (docs.isEmpty) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 24, 24, scrollBottomPad),
                      child: Text(
                        'Még nincs bejegyzés.\n'
                        'Írj szöveget és csatolj képeket lent.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, scrollBottomPad),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final uid = doc.data()['authorUid'] as String?;
                    final authorName =
                        uid != null && uid.isNotEmpty
                            ? (authorNames[uid] ?? uid)
                            : 'Ismeretlen szerző';
                    final currentUid = FirebaseAuth.instance.currentUser?.uid;
                    final isOwnPost =
                        uid != null &&
                        uid.isNotEmpty &&
                        currentUid != null &&
                        uid == currentUid;
                    return _DiaryPostCard(
                      doc: doc,
                      dateFmt: _dateFmt,
                      authorName: authorName,
                      isOwnPost: isOwnPost,
                    );
                  },
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
          child: FloatingActionButton.extended(
            onPressed: _isSending ? null : _openComposerSheet,
            icon: const Icon(LucideIcons.notebookPen),
            label: const Text('Új bejegyzés'),
          ),
        ),
      ],
    );
  }
}

class _DiaryPostCard extends StatelessWidget {
  const _DiaryPostCard({
    required this.doc,
    required this.dateFmt,
    required this.authorName,
    required this.isOwnPost,
  });

  static final _headerDateOnlyFmt = DateFormat('yyyy. MM. dd.', 'hu');

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final DateFormat dateFmt;
  final String authorName;
  final bool isOwnPost;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final text = data['text'] as String? ?? '';
    final urls =
        (data['imageUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];
    final created = data['createdAt'];
    String? dateLabel;
    if (created is Timestamp) {
      final d = created.toDate();
      final startOfDay =
          d.hour == 0 && d.minute == 0 && d.second == 0 && d.millisecond == 0;
      dateLabel = startOfDay ? _headerDateOnlyFmt.format(d) : dateFmt.format(d);
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress:
              isOwnPost ? () => _showOwnDiaryPostActions(context, doc) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🔹 Header (avatar + name + date)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        authorName.isNotEmpty
                            ? authorName[0].toUpperCase()
                            : '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (dateLabel != null)
                      Text(
                        dateLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                if (text.isNotEmpty || urls.isNotEmpty)
                  const SizedBox(height: 10),

                // 🔹 Post text
                if (text.isNotEmpty)
                  Text(text, style: theme.textTheme.bodyLarge),

                if (text.isNotEmpty && urls.isNotEmpty)
                  const SizedBox(height: 10),

                // 🔹 Images
                if (urls.isNotEmpty)
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: urls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final url = urls[i];
                        final thumbPx =
                            (112 * MediaQuery.devicePixelRatioOf(context))
                                .round();
                        return GestureDetector(
                          onTap:
                              () => _openDiaryPhotoGallery(
                                context,
                                urls,
                                initialIndex: i,
                              ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 112,
                              height: 112,
                              child: CachedNetworkImage(
                                imageUrl: url,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                memCacheWidth: thumbPx,
                                progressIndicatorBuilder: (
                                  context,
                                  _,
                                  progress,
                                ) {
                                  return ColoredBox(
                                    color: cs.surfaceContainerHighest,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: progress.progress,
                                      ),
                                    ),
                                  );
                                },
                                errorWidget:
                                    (context, _, __) => ColoredBox(
                                      color: cs.errorContainer,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: cs.onErrorContainer,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showOwnDiaryPostActions(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final action = await showModalBottomSheet<_DiaryPostAction>(
    context: context,
    builder:
        (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Bejegyzés szövegének szerkesztése'),
                onTap: () => Navigator.of(ctx).pop(_DiaryPostAction.edit),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error,
                ),
                title: Text(
                  'Törlés',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
                onTap: () => Navigator.of(ctx).pop(_DiaryPostAction.delete),
              ),
            ],
          ),
        ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _DiaryPostAction.edit:
      await _editOwnDiaryPostText(context, doc);
      break;
    case _DiaryPostAction.delete:
      await _confirmAndDeleteOwnDiaryPost(context, doc);
      break;
  }
}

Future<void> _editOwnDiaryPostText(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final data = doc.data();
  final initialText = (data['text'] as String? ?? '').trim();
  final hasImages = ((data['imageUrls'] as List<dynamic>?) ?? []).isNotEmpty;

  final editedText = await showDialog<String>(
    context: context,
    builder:
        (ctx) => _EditDiaryPostDialog(
          initialText: initialText,
          hasImages: hasImages,
        ),
  );
  if (!context.mounted || editedText == null) return;
  if (editedText == initialText) return;

  try {
    await doc.reference.update({
      'text': editedText,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final projectDoc = doc.reference.parent.parent;
    if (projectDoc != null) {
      await projectDoc.update({'updatedAt': FieldValue.serverTimestamp()});
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bejegyzés frissítve')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Szerkesztési hiba: $e')));
  }
}

enum _DiaryPostAction { edit, delete }

class _EditDiaryPostDialog extends StatefulWidget {
  const _EditDiaryPostDialog({
    required this.initialText,
    required this.hasImages,
  });

  final String initialText;
  final bool hasImages;

  @override
  State<_EditDiaryPostDialog> createState() => _EditDiaryPostDialogState();
}

class _EditDiaryPostDialogState extends State<_EditDiaryPostDialog> {
  late final TextEditingController _controller;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.hasImages) {
      setState(() {
        _validationError = 'A bejegyzés nem lehet üres képek nélkül.';
      });
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bejegyzés szövegének szerkesztése'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Poszt szövege…',
            errorText: _validationError,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        FilledButton(onPressed: _save, child: const Text('Mentés')),
      ],
    );
  }
}

void _openDiaryPhotoGallery(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
}) {
  if (urls.isEmpty) return;
  FocusManager.instance.primaryFocus?.unfocus();
  final safe = initialIndex.clamp(0, urls.length - 1);
  Navigator.of(context)
      .push<void>(
        MaterialPageRoute<void>(
          builder:
              (ctx) => _DiaryPhotoGalleryPage(urls: urls, initialIndex: safe),
        ),
      )
      .then((_) => FocusManager.instance.primaryFocus?.unfocus());
}

class _DiaryPhotoGalleryPage extends StatefulWidget {
  const _DiaryPhotoGalleryPage({
    required this.urls,
    required this.initialIndex,
  });

  final List<String> urls;
  final int initialIndex;

  @override
  State<_DiaryPhotoGalleryPage> createState() => _DiaryPhotoGalleryPageState();
}

class _DiaryPhotoGalleryPageState extends State<_DiaryPhotoGalleryPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.urls.length > 1
              ? '${_currentIndex + 1} / ${widget.urls.length}'
              : 'Kép',
        ),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        pageController: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) {
          if (event == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final v =
              event.expectedTotalBytes != null
                  ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                  : null;
          return Center(
            child: CircularProgressIndicator(value: v, color: Colors.white),
          );
        },
        builder: (context, index) {
          final url = widget.urls[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            errorBuilder:
                (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
          );
        },
      ),
    );
  }
}

Future<void> _confirmAndDeleteOwnDiaryPost(
  BuildContext context,
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: const Text('Bejegyzés törlése'),
          content: const Text(
            'Biztosan törlöd ezt a bejegyzést? A csatolt képek is törlődnek a tárolóból.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Mégse'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Törlés'),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return;

  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await _performDiaryEntryDelete(doc);
  } catch (e) {
    if (context.mounted) {
      navigator.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Törlési hiba: $e')));
    }
    return;
  }

  if (context.mounted) {
    navigator.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bejegyzés törölve')));
  }
}

Future<void> _performDiaryEntryDelete(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) async {
  final data = doc.data();
  final urls =
      (data['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [];
  for (final url in urls) {
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
    } catch (e) {
      debugPrint('Naplókép Storage törlés: $e');
    }
  }
  await doc.reference.delete();
  final projectDoc = doc.reference.parent.parent;
  if (projectDoc != null) {
    await projectDoc.update({'updatedAt': FieldValue.serverTimestamp()});
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 88,
            height: 88,
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => ColoredBox(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Material(
            color: Theme.of(context).colorScheme.error,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
