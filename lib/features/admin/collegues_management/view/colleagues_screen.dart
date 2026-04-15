import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/admin/collegues_management/view/add_colleague_screen.dart';
import 'package:okoskert_internal/features/admin/collegues_management/view/collegue_edit_salary_bottom_sheet.dart';
import 'package:okoskert_internal/features/admin/collegues_management/models/colleague_item.dart';
import 'package:okoskert_internal/features/admin/collegues_management/viewmodel/colleagues_view_model.dart';

class ColleaguesManagementPage extends StatefulWidget {
  const ColleaguesManagementPage({super.key});

  @override
  State<ColleaguesManagementPage> createState() =>
      _ColleaguesManagementPageState();
}

class _ColleaguesManagementPageState extends State<ColleaguesManagementPage> {
  late final ColleaguesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ColleaguesViewModel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Munkatársak')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => const AddColleagueScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Új munkatárs hozzáadása'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ColleagueItem>>(
              stream: _viewModel.colleaguesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Hiba történt: ${snapshot.error}'));
                }

                final colleagues = snapshot.data ?? [];

                return ListView.builder(
                  itemCount: colleagues.length,
                  itemBuilder: (context, index) {
                    final colleague = colleagues[index];
                    return ListTile(
                      onTap: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder:
                              (context) => ColleagueEditSalaryBottomSheet(
                                colleague: colleague,
                              ),
                        );
                      },
                      leading: CircleAvatar(
                        child: Text(
                          colleague.name.isNotEmpty ? colleague.name[0] : '',
                        ),
                      ),
                      title: Text(colleague.name),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
