import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          const Text(
            'Jó reggelt! Íme a mai összefoglaló.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),

          // Top Row (Stats)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 800;
              final childAspectRatio = isSmallScreen ? 2.5 : 1.5;

              return GridView.count(
                crossAxisCount: isSmallScreen ? 1 : 3,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                shrinkWrap: true,
                childAspectRatio: childAspectRatio,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard('Folyamatban lévő projektek', '12', Icons.work_outline, Colors.blue),
                  _buildStatCard('Számlázásra váró', '3', Icons.receipt_long, Colors.orange),
                  _buildStatCard('Aktív dolgozók ma', '8', Icons.people_outline, Colors.green),
                ],
              );
            },
          ),
          const SizedBox(height: 32),

          // Middle Section (Split Layout)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1000) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTasksPanel(),
                    const SizedBox(height: 24),
                    _buildTimelinePanel(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTasksPanel(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildTimelinePanel(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTasksPanel() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sürgős teendők',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(height: 32),
              itemBuilder: (context, index) {
                final dummyTasks = [
                  {'title': 'Ügyfél panasz: Kiss Gábor', 'subtitle': 'A fűnyíró hangos volt a pihenőidőben.'},
                  {'title': 'Alvállalkozói szerződés jóváhagyás', 'subtitle': 'Vár a Zöld Kertek Kft. szerződése.'},
                  {'title': 'Késés a 12. kerületi projekten', 'subtitle': 'Anyagbeszerzési probléma miatt csúszás.'},
                  {'title': 'Új árajánlat kérés: Minta Cég', 'subtitle': 'Irodaház belső udvar karbantartása.'},
                ];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  ),
                  title: Text(
                    dummyTasks[index]['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(dummyTasks[index]['subtitle']!),
                  ),
                  trailing: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Ellenőrzés'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelinePanel() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Legutóbbi terepi aktivitás',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (context, index) {
                final dummyEvents = [
                  {'time': '10:30', 'text': 'Nagy Béla 8 órát rögzített (Fűnyírás)'},
                  {'time': '09:15', 'text': 'Új anyagköltség rögzítve (Műtrágya)'},
                  {'time': '08:45', 'text': 'Kiss Karcsi megkezdte a munkát'},
                  {'time': 'Tegnap', 'text': 'Sikeres átadás: Kossuth téri park'},
                  {'time': 'Tegnap', 'text': 'Gép meghibásodás: Fűnyíró traktor 02'},
                ];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (index < 4) // Don't draw line for last item
                            Container(
                              width: 2,
                              height: 40,
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dummyEvents[index]['time']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dummyEvents[index]['text']!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
