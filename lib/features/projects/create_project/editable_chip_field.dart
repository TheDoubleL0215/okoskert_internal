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

  @override
  void initState() {
    super.initState();
    _loadTeamId();
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

  Widget _chipBuilder(BuildContext context, String workType) {
    return WorkTypeInputChip(
      workType: workType,
      onDeleted: _onChipDeleted,
      onSelected: _onChipTapped,
    );
  }

  void _selectSuggestion(String workType) {
    if (!widget.selectedTags.contains(workType)) {
      final newTags = [...widget.selectedTags, workType];
      widget.onChanged(newTags);
    }
    setState(() {
      _suggestions = <String>[];
    });
  }

  void _onChipTapped(String workType) {}

  void _onChipDeleted(String workType) {
    final newTags = widget.selectedTags.where((t) => t != workType).toList();
    widget.onChanged(newTags);
    setState(() {
      _suggestions = <String>[];
    });
  }

  void _onSubmitted(String text) {
    if (text.trim().isNotEmpty) {
      final trimmedText = text.trim();
      if (!widget.selectedTags.contains(trimmedText)) {
        final newTags = [...widget.selectedTags, trimmedText];
        widget.onChanged(newTags);
      }
    }
  }

  void _onChanged(List<String> data) {
    widget.onChanged(data);
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
        ChipsInput<String>(
          values: widget.selectedTags,
          decoration: const InputDecoration(
            hintText: 'Add meg a projekt típusát',
            border: OutlineInputBorder(),
          ),
          strutStyle: const StrutStyle(fontSize: 15),
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          chipBuilder: _chipBuilder,
          onTextChanged: _onSearchChanged,
        ),
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

class ChipsInput<T> extends StatefulWidget {
  const ChipsInput({
    super.key,
    required this.values,
    this.decoration = const InputDecoration(),
    this.style,
    this.strutStyle,
    required this.chipBuilder,
    required this.onChanged,
    this.onChipTapped,
    this.onSubmitted,
    this.onTextChanged,
  });

  final List<T> values;
  final InputDecoration decoration;
  final TextStyle? style;
  final StrutStyle? strutStyle;

  final ValueChanged<List<T>> onChanged;
  final ValueChanged<T>? onChipTapped;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onTextChanged;

  final Widget Function(BuildContext context, T data) chipBuilder;

  @override
  ChipsInputState<T> createState() => ChipsInputState<T>();
}

class ChipsInputState<T> extends State<ChipsInput<T>> {
  @visibleForTesting
  late final ChipsInputEditingController<T> controller;

  String _previousText = '';
  TextSelection? _previousSelection;

  @override
  void initState() {
    super.initState();

    controller = ChipsInputEditingController<T>(<T>[
      ...widget.values,
    ], widget.chipBuilder);
    controller.addListener(_textListener);
  }

  @override
  void dispose() {
    controller.removeListener(_textListener);
    controller.dispose();

    super.dispose();
  }

  void _textListener() {
    final String currentText = controller.text;

    if (_previousSelection != null) {
      final int currentNumber = countReplacements(currentText);
      final int previousNumber = countReplacements(_previousText);

      final int cursorEnd = _previousSelection!.extentOffset;
      final int cursorStart = _previousSelection!.baseOffset;

      final List<T> values = <T>[...widget.values];

      // If the current number and the previous number of replacements are different, then
      // the user has deleted the InputChip using the keyboard. In this case, we trigger
      // the onChanged callback. We need to be sure also that the current number of
      // replacements is different from the input chip to avoid double-deletion.
      if (currentNumber < previousNumber && currentNumber != values.length) {
        if (cursorStart == cursorEnd) {
          values.removeRange(cursorStart - 1, cursorEnd);
        } else {
          if (cursorStart > cursorEnd) {
            values.removeRange(cursorEnd, cursorStart);
          } else {
            values.removeRange(cursorStart, cursorEnd);
          }
        }
        widget.onChanged(values);
      }
    }

    _previousText = currentText;
    _previousSelection = controller.selection;
  }

  static int countReplacements(String text) {
    return text.codeUnits
        .where(
          (int u) => u == ChipsInputEditingController.kObjectReplacementChar,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    controller.updateValues(<T>[...widget.values]);

    return TextField(
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      style: widget.style,
      strutStyle: widget.strutStyle,
      decoration: widget.decoration,
      controller: controller,
      onChanged:
          (String value) =>
              widget.onTextChanged?.call(controller.textWithoutReplacements),
      onSubmitted:
          (String value) =>
              widget.onSubmitted?.call(controller.textWithoutReplacements),
    );
  }
}

class ChipsInputEditingController<T> extends TextEditingController {
  ChipsInputEditingController(this.values, this.chipBuilder)
    : super(text: String.fromCharCode(kObjectReplacementChar) * values.length);

  // This constant character acts as a placeholder in the TextField text value.
  // There will be one character for each of the InputChip displayed.
  static const int kObjectReplacementChar = 0xFFFE;

  List<T> values;

  final Widget Function(BuildContext context, T data) chipBuilder;

  /// Called whenever chip is either added or removed
  /// from the outside the context of the text field.
  void updateValues(List<T> values) {
    if (values.length != this.values.length) {
      final String char = String.fromCharCode(kObjectReplacementChar);
      final int length = values.length;
      value = TextEditingValue(
        text: char * length,
        selection: TextSelection.collapsed(offset: length),
      );
      this.values = values;
    }
  }

  String get textWithoutReplacements {
    final String char = String.fromCharCode(kObjectReplacementChar);
    return text.replaceAll(RegExp(char), '');
  }

  String get textWithReplacements => text;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final Iterable<WidgetSpan> chipWidgets = values.map(
      (T v) => WidgetSpan(child: chipBuilder(context, v)),
    );

    return TextSpan(
      style: style,
      children: <InlineSpan>[
        ...chipWidgets,
        if (textWithoutReplacements.isNotEmpty)
          TextSpan(text: textWithoutReplacements),
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
    required this.onSelected,
  });

  final String workType;
  final ValueChanged<String> onDeleted;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      child: InputChip(
        key: ObjectKey(workType),
        label: Text(workType),
        avatar: CircleAvatar(child: Text(workType[0].toUpperCase())),
        onDeleted: () => onDeleted(workType),
        onSelected: (bool value) => onSelected(workType),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(2),
      ),
    );
  }
}
