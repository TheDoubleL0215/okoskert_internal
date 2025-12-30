import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';

class EditableChipField extends StatefulWidget {
  final List<String> selectedTags;
  final ValueChanged<List<String>> onChanged;
  final String? labelText;

  const EditableChipField({
    super.key,
    required this.selectedTags,
    required this.onChanged,
    this.labelText,
  });

  @override
  EditableChipFieldState createState() {
    return EditableChipFieldState();
  }
}

class EditableChipFieldState extends State<EditableChipField> {
  List<String> _suggestions = <String>[];
  String? _teamId;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeamId();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamId() async {
    final teamId = await UserService.getTeamId();
    if (mounted) {
      setState(() {
        _teamId = teamId;
      });
    }
  }

  Future<void> _onSearchChanged(String value) async {
    final List<String> results = await _suggestionCallback(value);
    setState(() {
      _suggestions =
          results
              .where(
                (String workType) => !widget.selectedTags.contains(workType),
              )
              .toList();
    });
  }

  void _selectSuggestion(String workType) {
    if (!widget.selectedTags.contains(workType)) {
      final newTags = [...widget.selectedTags, workType];
      widget.onChanged(newTags);
      _textController.clear();
    }
    setState(() {
      _suggestions = <String>[];
    });
  }

  void _onChipDeleted(String workType) {
    final newTags = widget.selectedTags.where((t) => t != workType).toList();
    widget.onChanged(newTags);
  }

  void _onSubmitted(String text) {
    if (text.trim().isNotEmpty) {
      final trimmedText = text.trim();
      if (!widget.selectedTags.contains(trimmedText)) {
        final newTags = [...widget.selectedTags, trimmedText];
        widget.onChanged(newTags);
        _textController.clear();
      }
    }
    setState(() {
      _suggestions = <String>[];
    });
  }

  FutureOr<List<String>> _suggestionCallback(String text) async {
    if (_teamId == null) {
      return const <String>[];
    }

    // Load work types from Firestore workspace subcollection
    try {
      // First, find the workspace by teamId
      final workspaceQuery =
          await FirebaseFirestore.instance
              .collection('workspaces')
              .where('teamId', isEqualTo: _teamId)
              .limit(1)
              .get();

      if (workspaceQuery.docs.isEmpty) {
        return const <String>[];
      }

      final workspaceDoc = workspaceQuery.docs.first;

      // Then, get workTypes from the workspace subcollection
      final querySnapshot =
          await workspaceDoc.reference.collection('workTypes').get();

      final workTypes =
          querySnapshot.docs
              .map((doc) => doc.data()['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList();

      if (text.isNotEmpty) {
        return workTypes.where((String workType) {
          return workType.toLowerCase().contains(text.toLowerCase());
        }).toList();
      }
      return workTypes;
    } catch (e) {
      debugPrint('Hiba a workTypes lekérdezésekor: $e');
      return const <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_teamId == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              widget.labelText!,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        // Horizontal scrolling chips bar
        if (widget.selectedTags.isNotEmpty)
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    widget.selectedTags.map((workType) {
                      return WorkTypeInputChip(
                        workType: workType,
                        onDeleted: _onChipDeleted,
                      );
                    }).toList(),
              ),
            ),
          ),
        // Text input field
        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            hintText: 'Add meg a projekt típusát',
            border: OutlineInputBorder(),
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.done,
        ),
        // Suggestions list
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (BuildContext context, int index) {
                return WorkTypeSuggestion(
                  _suggestions[index],
                  onTap: _selectSuggestion,
                );
              },
            ),
          ),
      ],
    );
  }
}

class WorkTypeSuggestion extends StatelessWidget {
  const WorkTypeSuggestion(this.workType, {super.key, this.onTap});

  final String workType;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ObjectKey(workType),
      leading: CircleAvatar(child: Text(workType[0].toUpperCase())),
      title: Text(workType),
      onTap: () => onTap?.call(workType),
    );
  }
}

class WorkTypeInputChip extends StatelessWidget {
  const WorkTypeInputChip({
    super.key,
    required this.workType,
    required this.onDeleted,
  });

  final String workType;
  final ValueChanged<String> onDeleted;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      child: InputChip(
        key: ObjectKey(workType),
        label: Text(workType),
        avatar: CircleAvatar(child: Text(workType[0].toUpperCase())),
        onDeleted: () => onDeleted(workType),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(2),
      ),
    );
  }
}
