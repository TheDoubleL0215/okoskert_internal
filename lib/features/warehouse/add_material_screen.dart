import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/warehouse/add_material_helpers.dart';

class AddMaterialScreen extends StatefulWidget {
  final String? materialId;
  final Map<String, dynamic>? initialData;
  final String? projectId;

  const AddMaterialScreen({
    super.key,
    this.materialId,
    this.initialData,
    this.projectId,
  });

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

enum _PriceMode { unitPrice, customPrice }

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedUnit;
  String? _selectedProjectId;
  bool _isUpdatingPrice = false;
  bool _isUpdatingUnitPrice = false;
  bool _isSaving = false;
  _PriceMode _priceMode = _PriceMode.unitPrice;
  List<Map<String, String>> _projects = [];
  bool _isLoadingProjects = false;
  DateTime _selectedDate = DateTime.now();
  late final TextEditingController _dateController;

  final List<String> _units = ['m³', 'm²', 'db', 'kg', 'tonna'];

  String _formatDate(DateTime date) {
    return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _dateController.text = _formatDate(_selectedDate);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.projectId;
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _quantityController.addListener(_onQuantityOrUnitPriceChanged);
    _unitPriceController.addListener(_onQuantityOrUnitPriceChanged);
    _priceController.addListener(_onPriceChanged);
    _loadProjects();
    _loadMaterialData();
  }

  Future<void> _loadMaterialData() async {
    // Ha van initialData, használjuk azt (gyorsabb)
    if (widget.initialData != null) {
      _populateFieldsFromData(widget.initialData!);
      return;
    }

    // Ha van materialId, de nincs initialData, betöltjük a Firestore-ból
    if (widget.materialId != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('materials')
                .doc(widget.materialId)
                .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          _populateFieldsFromData(data);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hiba az alapanyag betöltésekor: $error')),
          );
        }
      }
    }
  }

  void _populateFieldsFromData(Map<String, dynamic> data) {
    // Ideiglenesen eltávolítjuk a listener-eket, hogy ne triggereljék a számításokat
    _quantityController.removeListener(_onQuantityOrUnitPriceChanged);
    _unitPriceController.removeListener(_onQuantityOrUnitPriceChanged);
    _priceController.removeListener(_onPriceChanged);

    setState(() {
      _nameController.text = data['name'] as String? ?? '';
      _quantityController.text = (data['quantity'] as num? ?? 0.0).toString();
      _selectedUnit = data['unit'] as String?;

      final priceMode = data['priceMode'] as String?;
      if (priceMode == 'unitPrice') {
        _priceMode = _PriceMode.unitPrice;
        final unitPrice = data['unitPrice'] as num?;
        if (unitPrice != null) {
          _unitPriceController.text = unitPrice.toString();
        }
        final price = data['price'] as num?;
        if (price != null) {
          _priceController.text = price.toString();
        }
      } else if (priceMode == 'customPrice') {
        _priceMode = _PriceMode.customPrice;
        final price = data['price'] as num?;
        if (price != null) {
          _priceController.text = price.toString();
        }
      }

      _selectedProjectId = data['projectId'] as String?;

      // Dátum betöltése
      final date = data['date'] as Timestamp?;
      if (date != null) {
        _selectedDate = date.toDate();
        _dateController.text = _formatDate(_selectedDate);
      }
    });

    // Visszaadjuk a listener-eket
    _quantityController.addListener(_onQuantityOrUnitPriceChanged);
    _unitPriceController.addListener(_onQuantityOrUnitPriceChanged);
    _priceController.addListener(_onPriceChanged);
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final teamId = await UserService.getTeamId();
      if (teamId == null || teamId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingProjects = false;
          });
        }
        return;
      }

      final snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .where('teamId', isEqualTo: teamId)
              .get();

      if (mounted) {
        setState(() {
          _projects =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'name': data['projectName'] as String? ?? 'Névtelen projekt',
                };
              }).toList();
          // Rendezés név szerint
          _projects.sort((a, b) => a['name']!.compareTo(b['name']!));
          _isLoadingProjects = false;
        });
      }
    } catch (error) {
      if (mounted) {
        debugPrint('Hiba a projektek betöltésekor: $error');
        setState(() {
          _isLoadingProjects = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiba történt a projektek betöltésekor: $error'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _quantityController.removeListener(_onQuantityOrUnitPriceChanged);
    _unitPriceController.removeListener(_onQuantityOrUnitPriceChanged);
    _priceController.removeListener(_onPriceChanged);
    _nameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _priceController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _onQuantityOrUnitPriceChanged() {
    if (_isUpdatingPrice || _priceMode != _PriceMode.unitPrice) return;

    final quantityText = _quantityController.text.trim();
    final unitPriceText = _unitPriceController.text.trim();

    if (quantityText.isNotEmpty && unitPriceText.isNotEmpty) {
      final quantity = double.tryParse(quantityText.replaceAll(',', '.'));
      final unitPrice = double.tryParse(unitPriceText.replaceAll(',', '.'));

      if (quantity != null && unitPrice != null) {
        _isUpdatingPrice = true;
        final totalPrice = quantity * unitPrice;
        _priceController.text = totalPrice.toString();
        _isUpdatingPrice = false;
      }
    }
  }

  void _onPriceChanged() {
    if (_isUpdatingUnitPrice || _isUpdatingPrice) return;

    // Ha egyedi ár módban vagyunk, ne számoljuk újra az egységárat
    if (_priceMode == _PriceMode.customPrice) return;

    final priceText = _priceController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (priceText.isNotEmpty && quantityText.isNotEmpty) {
      final price = double.tryParse(priceText.replaceAll(',', '.'));
      final quantity = double.tryParse(quantityText.replaceAll(',', '.'));

      if (price != null && quantity != null && quantity > 0) {
        _isUpdatingUnitPrice = true;
        final unitPrice = price / quantity;
        _unitPriceController.text = unitPrice.toStringAsFixed(2);
        _isUpdatingUnitPrice = false;
      }
    }
  }

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final teamId = await UserService.getTeamId();
      if (teamId == null || teamId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hiba: nem található teamId')),
        );
        return;
      }

      final name = _nameController.text.trim();
      final quantity =
          double.tryParse(
            _quantityController.text.trim().replaceAll(',', '.'),
          ) ??
          0.0;
      final unit = _selectedUnit ?? '';

      final materialData = <String, dynamic>{
        'teamId': teamId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'createdAt': FieldValue.serverTimestamp(),
        'date': Timestamp.fromDate(_selectedDate),
        if (_selectedProjectId != null) 'projectId': _selectedProjectId,
      };

      // Ár adatok hozzáadása csak akkor, ha van érték
      if (_priceMode == _PriceMode.unitPrice) {
        final unitPriceText = _unitPriceController.text.trim();
        if (unitPriceText.isNotEmpty) {
          final unitPrice =
              double.tryParse(unitPriceText.replaceAll(',', '.')) ?? 0.0;
          if (unitPrice > 0) {
            materialData['unitPrice'] = unitPrice;
            materialData['priceMode'] = 'unitPrice';

            // Ha van mennyiség is, számoljuk az összesen árat
            if (quantity > 0) {
              final totalPrice = quantity * unitPrice;
              materialData['price'] = totalPrice;
            }
          }
        }
      } else {
        final priceText = _priceController.text.trim();
        if (priceText.isNotEmpty) {
          final price = double.tryParse(priceText.replaceAll(',', '.')) ?? 0.0;
          if (price > 0) {
            materialData['price'] = price;
            materialData['priceMode'] = 'customPrice';
          }
        }
      }

      if (widget.materialId != null) {
        // Szerkesztés módban: update
        await FirebaseFirestore.instance
            .collection('materials')
            .doc(widget.materialId)
            .update(materialData);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alapanyag sikeresen frissítve')),
        );
      } else {
        // Új alapanyag: add
        await FirebaseFirestore.instance
            .collection('materials')
            .add(materialData);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alapanyag sikeresen elmentve')),
        );
      }

      // Visszanavigálás
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Hiba az alapanyag mentésekor: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba történt a mentéskor: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.materialId != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEditMode ? 'Alapanyag szerkesztése' : 'Alapanyag hozzáadása',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              spacing: 16,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Alapanyag neve',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Az alapanyag neve kötelező';
                    }
                    return null;
                  },
                ),
                if (_isLoadingProjects)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedProjectId,
                    decoration: const InputDecoration(
                      labelText: 'Projekt',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nincs projekt kiválasztva'),
                      ),
                      ..._projects.map((project) {
                        return DropdownMenuItem<String?>(
                          value: project['id'],
                          child: Text(project['name']!),
                        );
                      }),
                    ],
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedProjectId = newValue;
                      });
                    },
                  ),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Dátum',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  onTap: _selectDate,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Quantity field takes more space, unit just enough
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Mennyiség',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'A mennyiség kötelező';
                            }
                            if (double.tryParse(
                                  value.trim().replaceAll(',', '.'),
                                ) ==
                                null) {
                              return 'Kérjük, érvényes számot adjon meg';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: const InputDecoration(
                          labelText: 'Mértékegység',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            _units.map((String unit) {
                              return DropdownMenuItem<String>(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedUnit = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kérjük, válasszon mértékegységet';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_PriceMode>(
                    segments: const [
                      ButtonSegment<_PriceMode>(
                        value: _PriceMode.unitPrice,
                        label: Text('Egység ár'),
                        icon: Icon(Icons.calculate),
                      ),
                      ButtonSegment<_PriceMode>(
                        value: _PriceMode.customPrice,
                        label: Text('Egyedi ár'),
                        icon: Icon(Icons.edit),
                      ),
                    ],
                    selected: {_priceMode},
                    onSelectionChanged: (Set<_PriceMode> newSelection) {
                      setState(() {
                        _priceMode = newSelection.first;
                        // Töröljük a másik mező értékét amikor váltunk
                        if (_priceMode == _PriceMode.unitPrice) {
                          _priceController.clear();
                        } else {
                          _unitPriceController.clear();
                        }
                      });
                    },
                  ),
                ),
                if (_priceMode == _PriceMode.unitPrice)
                  TextFormField(
                    controller: _unitPriceController,
                    decoration: InputDecoration(
                      labelText:
                          _selectedUnit != null
                              ? 'Egységár (HUF/${_selectedUnit}) (opcionális)'
                              : 'Egységár (HUF) (opcionális)',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (value) {
                      // Az egységár opcionális
                      if (value != null && value.trim().isNotEmpty) {
                        if (double.tryParse(
                              value.trim().replaceAll(',', '.'),
                            ) ==
                            null) {
                          return 'Kérjük, érvényes számot adjon meg';
                        }
                      }
                      return null;
                    },
                  ),
                if (_priceMode == _PriceMode.unitPrice)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Összesen',
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _quantityController,
                          builder: (context, quantityValue, child) {
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _unitPriceController,
                              builder: (context, unitPriceValue, child) {
                                final quantityText = quantityValue.text.trim();
                                final unitPriceText =
                                    unitPriceValue.text.trim();

                                if (quantityText.isEmpty ||
                                    unitPriceText.isEmpty) {
                                  return Text(
                                    '0 HUF',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                }

                                final quantity = double.tryParse(
                                  quantityText.replaceAll(',', '.'),
                                );
                                final unitPrice = double.tryParse(
                                  unitPriceText.replaceAll(',', '.'),
                                );

                                final totalPrice = quantity! * unitPrice!;
                                final formattedPrice =
                                    AddMaterialHelpers.formatPrice(totalPrice);

                                // Frissítjük a _priceController-t is a mentéshez
                                if (!_isUpdatingPrice) {
                                  _isUpdatingPrice = true;
                                  _priceController.text = totalPrice.toString();
                                  _isUpdatingPrice = false;
                                }

                                return Text(
                                  '$formattedPrice HUF',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (_priceMode == _PriceMode.customPrice)
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Összesen (HUF) (opcionális)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                    validator: (value) {
                      // Az ár opcionális
                      if (value != null && value.trim().isNotEmpty) {
                        if (double.tryParse(
                              value.trim().replaceAll(',', '.'),
                            ) ==
                            null) {
                          return 'Kérjük, érvényes számot adjon meg';
                        }
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveMaterial,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Mentés',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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
