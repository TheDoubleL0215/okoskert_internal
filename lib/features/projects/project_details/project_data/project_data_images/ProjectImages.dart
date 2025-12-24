import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_images/ProjectImageFSView.dart';

class ProjectImagesScreen extends StatefulWidget {
  final String projectId;
  const ProjectImagesScreen({super.key, required this.projectId});

  @override
  State<ProjectImagesScreen> createState() => _ProjectImagesScreenState();
}

class _ProjectImagesScreenState extends State<ProjectImagesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _sections = [
    'Munka előtt',
    'Munka közben',
    'Munka után',
    'Egyéb',
  ];

  Future<void> _pickAndUploadImage(String sectionName) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      // Loading dialog megjelenítése
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Fájl feltöltése Firebase Storage-ba
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String storagePath =
            'images/${widget.projectId}/$sectionName/$fileName';

        final Reference storageRef = FirebaseStorage.instance.ref(storagePath);
        final bytes = await File(image.path).readAsBytes();
        final UploadTask uploadTask = storageRef.putData(bytes);

        await uploadTask;

        // URL lekérése
        final String downloadUrl = await storageRef.getDownloadURL();

        // Firestore-ba mentés
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .collection('images')
            .add({
              'url': downloadUrl,
              'sectionName': sectionName,
              'uploadedAt': FieldValue.serverTimestamp(),
            });

        if (!mounted) return;

        Navigator.pop(context); // Loading dialog bezárása

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kép sikeresen feltöltve')),
        );
      } catch (error) {
        if (!mounted) return;
        Navigator.pop(context); // Loading dialog bezárása
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba történt a feltöltéskor: $error')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a kép kiválasztásakor: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('images')
              .orderBy('uploadedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Hiba történt a képek betöltésekor: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Képek kategorizálása szekciók szerint
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        imagesBySection = {};

        for (final section in _sections) {
          imagesBySection[section] = [];
        }

        final docs = snapshot.data?.docs ?? [];
        for (final doc in docs) {
          final data = doc.data();
          final sectionName = data['sectionName'] as String?;
          if (sectionName != null && imagesBySection.containsKey(sectionName)) {
            imagesBySection[sectionName]!.add(doc);
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _sections.length,
          itemBuilder: (context, index) {
            final sectionName = _sections[index];
            final sectionImages = imagesBySection[sectionName] ?? [];

            return _buildSection(sectionName, sectionImages);
          },
        );
      },
    );
  }

  Widget _buildSection(
    String sectionName,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> images,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Text(
            sectionName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: images.length + 1, // upload gomb + képek
          itemBuilder: (context, index) {
            if (index == images.length) {
              // Upload button at the END
              return _buildUploadButton(sectionName);
            }

            // Image item
            final imageDoc = images[index];
            final imageUrl = imageDoc.data()['url'] as String?;
            if (imageUrl == null) return const SizedBox.shrink();

            return _buildImageItem(imageUrl, imageDoc.id);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildUploadButton(String sectionName) {
    return InkWell(
      onTap: () => _pickAndUploadImage(sectionName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Kép hozzáadása',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(String imageUrl, String imageId) {
    return GestureDetector(
      onLongPress: () => _showDeleteDialog(imageId),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ProjectImageFSView(
            imageUrl: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover, // Preview: cropped square
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String imageId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kép törlése'),
            content: const Text('Biztosan törölni szeretnéd ezt a képet?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Mégse'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteImage(imageId);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Törlés'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteImage(String imageId) async {
    try {
      // Firestore dokumentum lekérése az URL-ért
      final doc =
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('images')
              .doc(imageId)
              .get();

      if (!doc.exists) return;

      final data = doc.data();
      final imageUrl = data?['url'] as String?;

      // Firebase Storage-ból törlés
      if (imageUrl != null) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          // Ha a Storage törlés nem sikerül, folytatjuk a Firestore törléssel
          debugPrint('Hiba a Storage törléskor: $e');
        }
      }

      // Firestore-ból törlés
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('images')
          .doc(imageId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kép sikeresen törölve')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a törléskor: $error')),
      );
    }
  }
}
