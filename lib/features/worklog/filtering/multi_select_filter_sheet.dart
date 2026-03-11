import 'package:flutter/material.dart';

/// Egy bottom sheet többszörös választással: id + megjelenített címke listája.
/// A [future] a {id, label} párok listáját adja; a kiválasztott id-kat [selectedIds]-ként kapja,
/// és "Alkalmaz" esetén ezt a Set<String>-et adja vissza a Navigator.pop-kal.
class MultiSelectFilterSheet extends StatefulWidget {
  final String title;
  final Future<List<Map<String, String>>> future;
  final Set<String> selectedIds;

  const MultiSelectFilterSheet({
    super.key,
    required this.title,
    required this.future,
    required this.selectedIds,
  });

  @override
  State<MultiSelectFilterSheet> createState() => _MultiSelectFilterSheetState();
}

class _MultiSelectFilterSheetState extends State<MultiSelectFilterSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.25,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, String>>>(
                  future: widget.future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Hiba: ${snapshot.error}'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Nincs megjeleníthető elem.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final id = item['id'] ?? '';
                        final label = item['label'] ?? id;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _selected.contains(id),
                          title: Text(label),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(id);
                              } else {
                                _selected.remove(id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Mégse'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context, _selected),
                      child: const Text('Alkalmaz'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
