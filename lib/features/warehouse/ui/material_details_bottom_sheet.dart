import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:okoskert_internal/features/warehouse/add_material_screen.dart';

class MaterialDetailsBottomSheet {
  static Future<void> show(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> material,
    Map<String, String> projectsMap,
  ) async {
    final data = material.data();
    final name = data['name'] as String? ?? 'Névtelen alapanyag';
    final quantity = data['quantity'] as num? ?? 0.0;
    final unit = data['unit'] as String? ?? '';
    final price = data['price'] as num?;
    final unitPrice = data['unitPrice'] as num?;
    final date = data['date'] as Timestamp?;
    final priceMode = data['priceMode'] as String?;
    final projectId = data['projectId'] as String?;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => _MaterialDetailsContent(
            material: material,
            name: name,
            quantity: quantity,
            unit: unit,
            price: price,
            unitPrice: unitPrice,
            priceMode: priceMode,
            projectId: projectId,
            date: date,
            projectsMap: projectsMap,
          ),
    );
  }
}

class _MaterialDetailsContent extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> material;
  final String name;
  final num quantity;
  final String unit;
  final num? price;
  final num? unitPrice;
  final String? priceMode;
  final String? projectId;
  final Timestamp? createdAt;
  final Timestamp? date;
  final Map<String, String> projectsMap;

  const _MaterialDetailsContent({
    required this.material,
    required this.name,
    required this.quantity,
    required this.unit,
    this.price,
    this.unitPrice,
    this.priceMode,
    this.projectId,
    this.createdAt,
    required this.projectsMap,
    this.date,
  });

  String _formatPrice(double price) {
    final priceInt = price.toInt();
    final priceStr = priceInt.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < priceStr.length; i++) {
      if (i > 0 && (priceStr.length - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(priceStr[i]);
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color:
              isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight:
                      isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color:
                      isHighlighted
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Alapanyag törlése'),
            content: Text(
              'Biztosan törölni szeretnéd az "$name" alapanyagot? Ez a művelet nem vonható vissza.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Mégse'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Törlés'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('materials')
          .doc(material.id)
          .delete();

      if (!context.mounted) return;

      Navigator.pop(context); // Bezárjuk a bottom sheet-et
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alapanyag sikeresen törölve')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a törléskor: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        child: Icon(LucideIcons.package, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (date != null)
                              Text(
                                'Hozzáadva: ${_formatDate(date!.toDate())}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Mennyiség információ
                  _buildInfoRow(
                    context,
                    icon: LucideIcons.scale,
                    label: 'Mennyiség',
                    value: '$quantity $unit',
                  ),
                  const SizedBox(height: 16),

                  // Ár információk
                  if (price != null || unitPrice != null) ...[
                    if (priceMode == 'unitPrice' && unitPrice != null) ...[
                      _buildInfoRow(
                        context,
                        icon: LucideIcons.dollarSign,
                        label: 'Egységár',
                        value:
                            '${_formatPrice(unitPrice!.toDouble())} HUF/$unit',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (price != null)
                      _buildInfoRow(
                        context,
                        icon: LucideIcons.receipt,
                        label: 'Összesen',
                        value: '${_formatPrice(price!.toDouble())} HUF',
                        isHighlighted: true,
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Projekt információ
                  if (projectId != null &&
                      projectsMap.containsKey(projectId)) ...[
                    _buildInfoRow(
                      context,
                      icon: LucideIcons.folder,
                      label: 'Projekt',
                      value: projectsMap[projectId]!,
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Divider(),
                  const SizedBox(height: 16),

                  // Edit gomb
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddMaterialScreen(
                                  materialId: material.id,
                                  initialData: material.data(),
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Szerkesztés'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delete gomb
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteConfirmation(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Törlés'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
