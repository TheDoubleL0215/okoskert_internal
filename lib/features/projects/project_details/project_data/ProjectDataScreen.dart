import 'package:flutter/material.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_collegues/project_data_worklog_screen.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_images/ProjectImages.dart';
import 'package:okoskert_internal/features/projects/project_details/project_data/project_data_materials/project_data_materials_screen.dart';

class ProjectDataScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  const ProjectDataScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDataScreen> createState() => _ProjectDataScreenState();
}

class _ProjectDataScreenState extends State<ProjectDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
      appBar: AppBar(
        title: Text(
          widget.projectName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Munkaórák'),
            Tab(text: 'Alapanyagok'),
            Tab(text: 'Képek'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ProjectDataWorklogScreen(projectId: widget.projectId),
          ProjectDataMaterialsScreen(projectId: widget.projectId),
          ProjectImagesScreen(projectId: widget.projectId),
        ],
      ),
    );
  }
}
