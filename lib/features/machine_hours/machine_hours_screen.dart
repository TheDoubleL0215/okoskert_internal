import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/get_user_team_id.dart';
import 'package:okoskert_internal/features/machine_hours/create_machine_screen.dart';
import 'package:okoskert_internal/features/machine_hours/machine_details_screen.dart';

class MachineHoursScreen extends StatefulWidget {
  const MachineHoursScreen({super.key});

  @override
  State<MachineHoursScreen> createState() => _MachineHoursScreenState();
}

class _MachineHoursScreenState extends State<MachineHoursScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Munkagépek kezelése',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<String?>(
        future: UserService.getTeamId(),
        builder: (context, teamIdSnapshot) {
          if (teamIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamId = teamIdSnapshot.data;
          if (teamId == null || teamId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Hiba: nem található teamId',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('machines')
                    .where('teamId', isEqualTo: teamId)
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
                      'Hiba történt az adatok betöltésekor: ${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final machineDocs = snapshot.data?.docs ?? [];

              if (machineDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Még nincsenek gépek',
                        style: TextStyle(fontSize: 16),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateMachineScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Új gép hozzáadása',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateMachineScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Új gép hozzáadása',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: machineDocs.length,
                        itemBuilder: (context, index) {
                          final doc = machineDocs[index];
                          final data = doc.data();
                          final name = data['name'] as String? ?? 'Ismeretlen';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                            ),
                            leading: Hero(
                              tag: doc.id,
                              child: CircleAvatar(
                                child: const Icon(Icons.agriculture),
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            trailing: Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => MachineDetailsScreen(
                                        machineId: doc.id,
                                      ),
                                ),
                              );
                            },
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
