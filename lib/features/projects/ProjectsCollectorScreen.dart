import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/projects/create_project/CreateProjectScreen.dart';

class Projectscollectorscreen extends StatefulWidget {
  const Projectscollectorscreen({super.key});

  @override
  State<Projectscollectorscreen> createState() =>
      _ProjectscollectorscreenState();
}

class _ProjectscollectorscreenState extends State<Projectscollectorscreen>
    with SingleTickerProviderStateMixin {
  int selectedFilterIndex = 0;
  late TabController _tabController;

  final List<String> filterOptions = [
    "Betűrend",
    "Állapot",
    "Utoljára frissítve",
    "Munka típusa",
    "Prioritás",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: EdgeInsets.all(8),
        child: Column(
          spacing: 16,
          children: [
            SearchBar(
              backgroundColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.secondaryContainer,
              ),
              padding: WidgetStateProperty.all(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              leading: Icon(Icons.search),
              hintText: "Keresés",
              elevation: WidgetStateProperty.all(0),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children:
                    filterOptions.asMap().entries.map((entry) {
                      int index = entry.key;
                      String option = entry.value;
                      return ChoiceChip(
                        label: Text(option),
                        selected: selectedFilterIndex == index,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedFilterIndex = index;
                            });
                          }
                        },
                      );
                    }).toList(),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: "Folyamatban lévő projektek"),
                      Tab(text: "Kész projektek"),
                      Tab(text: "Karbantartás"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProjectList("Folyamatban lévő projektek"),
                        _buildProjectList("Kész projektek"),
                        _buildProjectList("Karbantartás"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateProjectScreen()),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectList(String sectionName) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          "$sectionName tartalma",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
