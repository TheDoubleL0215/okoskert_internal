import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:okoskert_internal/data/services/users_services.dart';

class ColleaguesManagementPage extends StatelessWidget {
  const ColleaguesManagementPage({super.key});

  int _toIntSalary(dynamic rawSalary) {
    if (rawSalary is int) {
      return rawSalary;
    }
    if (rawSalary is num) {
      return rawSalary.toInt();
    }
    return int.tryParse(rawSalary?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Munkatársak')),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: UsersServices.getUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hiba történt: ${snapshot.error}'));
          }

          return ListView.builder(
            itemCount: snapshot.data?.length ?? 0,
            itemBuilder: (context, index) {
              return ListTile(
                onTap:
                    () async => await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder:
                          (context) => _SalaryBottomSheet(
                            userId: snapshot.data?[index].id ?? '',
                            salary: _toIntSalary(
                              snapshot.data?[index].data()['salary'],
                            ),
                            name: snapshot.data?[index].data()['name'] ?? '',
                            email: snapshot.data?[index].data()['email'] ?? '',
                          ),
                    ),
                leading: CircleAvatar(
                  child: Text(snapshot.data?[index].data()['name']?[0] ?? ''),
                ),
                title: Text(snapshot.data?[index].data()['name'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(snapshot.data?[index].data()['email'] ?? ''),
                    Text(
                      'Órabér: ${_toIntSalary(snapshot.data?[index].data()['salary'])}',
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Icon(Icons.chevron_right),
              );
            },
          );
        },
      ),
    );
  }
}

class _SalaryBottomSheet extends StatefulWidget {
  final String userId;
  final int salary;
  final String name;
  final String email;

  const _SalaryBottomSheet({
    required this.userId,
    required this.salary,
    required this.name,
    required this.email,
  });

  @override
  State<_SalaryBottomSheet> createState() => _SalaryBottomSheetState();
}

class _SalaryBottomSheetState extends State<_SalaryBottomSheet> {
  final _salaryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _salaryController.text = widget.salary.toString();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveSalary() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final salary = int.parse(_salaryController.text.trim());
    setState(() {
      _isSaving = true;
    });

    try {
      await UsersServices.updateUserSalary(
        userId: widget.userId,
        salary: salary,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fizetés sikeresen mentve')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mentési hiba: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Órabér módosítása',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.name}\n(${widget.email})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Új órabér (Ft)',
                  hintText: 'Pl. 4500',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final input = (value ?? '').trim();
                  if (input.isEmpty) {
                    return 'Add meg a fizetést';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed:
                          _isSaving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Mégse'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isSaving ? null : _saveSalary,
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Mentés'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
