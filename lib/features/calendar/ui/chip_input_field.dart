import 'dart:async';

import 'package:flutter/material.dart';

class ChipInputField extends StatefulWidget {
  final List<String>? options;
  final FutureOr<List<String>> Function(String)? suggestionCallback;
  final ValueChanged<List<String>>? onChanged;
  final List<String>? initialValues;
  final String? labelText;
  final String? hintText;
  final bool allowNewItems;

  const ChipInputField({
    super.key,
    this.options,
    this.suggestionCallback,
    this.onChanged,
    this.initialValues,
    this.labelText,
    this.hintText,
    this.allowNewItems = true,
  });

  @override
  ChipInputFieldState createState() {
    return ChipInputFieldState();
  }
}

class ChipInputFieldState extends State<ChipInputField> {
  final FocusNode _chipFocusNode = FocusNode();
  final GlobalKey<ChipsInputState<String>> _chipsInputKey =
      GlobalKey<ChipsInputState<String>>();
  late List<String> _toppings;
  List<String> _suggestions = <String>[];

  @override
  void initState() {
    super.initState();
    _toppings =
        widget.initialValues != null
            ? List<String>.from(widget.initialValues!)
            : <String>[];
  }

  @override
  void didUpdateWidget(ChipInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValues != oldWidget.initialValues) {
      _toppings =
          widget.initialValues != null
              ? List<String>.from(widget.initialValues!)
              : <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Kiválasztott címkék vízszintesen görgethető sorban
        if (_toppings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SizedBox(
              height: 40,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _toppings.map((topping) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ToppingInputChip(
                            topping: topping,
                            onDeleted: _onChipDeleted,
                            onSelected: _onChipTapped,
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        // Keresőmező
        ChipsInput<String>(
          key: _chipsInputKey,
          values: _toppings,
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'Kiválasztott opciók',
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
          ),
          strutStyle: const StrutStyle(fontSize: 15),
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          chipBuilder: _chipBuilder,
          onTextChanged: _onSearchChanged,
          showChipsInline: false,
        ),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (BuildContext context, int index) {
                return ToppingSuggestion(
                  _suggestions[index],
                  onTap: _selectSuggestion,
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _onSearchChanged(String value) async {
    final List<String> results = await _suggestionCallback(value);
    setState(() {
      _suggestions =
          results
              .where((String topping) => !_toppings.contains(topping))
              .toList();
    });
  }

  Widget _chipBuilder(BuildContext context, String topping) {
    return ToppingInputChip(
      topping: topping,
      onDeleted: _onChipDeleted,
      onSelected: _onChipTapped,
    );
  }

  void _selectSuggestion(String topping) {
    setState(() {
      _toppings.add(topping);
      _suggestions = <String>[];
    });
    // Töröljük a szövegmező tartalmát
    _chipsInputKey.currentState?.clearText();
    // Értesítjük a szülő widget-et a változásról
    widget.onChanged?.call(_toppings);
  }

  void _onChipTapped(String topping) {}

  void _onChipDeleted(String topping) {
    setState(() {
      _toppings.remove(topping);
      _suggestions = <String>[];
    });
    // Értesítjük a szülő widget-et a változásról
    widget.onChanged?.call(_toppings);
  }

  void _onSubmitted(String text) {
    if (text.trim().isNotEmpty) {
      // Ha az új elemek hozzáadása nincs engedélyezve, nem adhatunk hozzá új elemet
      if (!widget.allowNewItems) {
        // Csak töröljük a szöveget, de nem adunk hozzá új elemet
        _chipsInputKey.currentState?.clearText();
        return;
      }

      setState(() {
        _toppings = <String>[..._toppings, text.trim()];
      });
      // Töröljük a szövegmező tartalmát
      _chipsInputKey.currentState?.clearText();
      // Értesítjük a szülő widget-et a változásról
      widget.onChanged?.call(_toppings);
    } else {
      _chipFocusNode.unfocus();
      setState(() {
        _toppings = <String>[];
      });
      // Értesítjük a szülő widget-et a változásról
      widget.onChanged?.call(_toppings);
    }
  }

  void _onChanged(List<String> data) {
    setState(() {
      _toppings = data;
    });
    widget.onChanged?.call(_toppings);
  }

  FutureOr<List<String>> _suggestionCallback(String text) {
    if (text.isEmpty) {
      return <String>[];
    }

    // Ha van egyedi suggestionCallback, azt használjuk
    if (widget.suggestionCallback != null) {
      return widget.suggestionCallback!(text);
    }

    // Ha van options lista, azt használjuk
    if (widget.options != null && widget.options!.isNotEmpty) {
      return widget.options!.where((String option) {
        return option.toLowerCase().contains(text.toLowerCase());
      }).toList();
    }

    return <String>[];
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
    this.showChipsInline = true,
  });

  final List<T> values;
  final InputDecoration decoration;
  final TextStyle? style;
  final StrutStyle? strutStyle;

  final ValueChanged<List<T>> onChanged;
  final ValueChanged<T>? onChipTapped;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onTextChanged;
  final bool showChipsInline;

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

    controller = ChipsInputEditingController<T>(
      <T>[...widget.values],
      widget.chipBuilder,
      showChipsInline: widget.showChipsInline,
    );
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

  void clearText() {
    controller.clearText();
  }

  @override
  Widget build(BuildContext context) {
    controller.updateValues(<T>[...widget.values]);

    return TextField(
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      decoration: widget.decoration.copyWith(
        labelText: widget.decoration.labelText,
        border: OutlineInputBorder(),
      ),
      style: widget.style,
      strutStyle: widget.strutStyle,
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
  ChipsInputEditingController(
    this.values,
    this.chipBuilder, {
    this.showChipsInline = true,
  }) : super(
         text:
             showChipsInline
                 ? String.fromCharCode(kObjectReplacementChar) * values.length
                 : '',
       );

  // This constant character acts as a placeholder in the TextField text value.
  // There will be one character for each of the InputChip displayed.
  static const int kObjectReplacementChar = 0xFFFE;

  List<T> values;
  final bool showChipsInline;

  final Widget Function(BuildContext context, T data) chipBuilder;

  /// Called whenever chip is either added or removed
  /// from the outside the context of the text field.
  void updateValues(List<T> values) {
    if (values.length != this.values.length) {
      if (showChipsInline) {
        final String char = String.fromCharCode(kObjectReplacementChar);
        final int length = values.length;
        value = TextEditingValue(
          text: char * length,
          selection: TextSelection.collapsed(offset: length),
        );
      } else {
        // Ha nem inline, csak a szöveget tartjuk meg
        final currentText = textWithoutReplacements;
        value = TextEditingValue(
          text: currentText,
          selection: TextSelection.collapsed(offset: currentText.length),
        );
      }
      this.values = values;
    }
  }

  String get textWithoutReplacements {
    final String char = String.fromCharCode(kObjectReplacementChar);
    return text.replaceAll(RegExp(char), '');
  }

  String get textWithReplacements => text;

  void clearText() {
    if (showChipsInline) {
      final String char = String.fromCharCode(kObjectReplacementChar);
      final int length = values.length;
      value = TextEditingValue(
        text: char * length,
        selection: TextSelection.collapsed(offset: length),
      );
    } else {
      value = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!showChipsInline) {
      // Ha nem inline módban vagyunk, csak a szöveget jelenítjük meg
      return TextSpan(style: style, text: textWithoutReplacements);
    }

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

class ToppingSuggestion extends StatelessWidget {
  const ToppingSuggestion(this.topping, {super.key, this.onTap});

  final String topping;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ObjectKey(topping),
      leading: CircleAvatar(child: Text(topping[0].toUpperCase())),
      title: Text(topping),
      onTap: () => onTap?.call(topping),
    );
  }
}

class ToppingInputChip extends StatelessWidget {
  const ToppingInputChip({
    super.key,
    required this.topping,
    required this.onDeleted,
    required this.onSelected,
  });

  final String topping;
  final ValueChanged<String> onDeleted;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      child: InputChip(
        key: ObjectKey(topping),
        label: Text(topping),
        avatar: CircleAvatar(child: Text(topping[0].toUpperCase())),
        onDeleted: () => onDeleted(topping),
        onSelected: (bool value) => onSelected(topping),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(2),
      ),
    );
  }
}
