import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ProjectDetailsContactDetails extends StatelessWidget {
  final customerPhone;
  final customerEmail;
  final projectLocation;
  const ProjectDetailsContactDetails({
    super.key,
    required this.customerPhone,
    required this.customerEmail,
    required this.projectLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elérhetőségek',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        customerPhone != null
            ? FilledButton.tonalIcon(
              label: Text("${customerPhone}"),
              onPressed: () {
                launchUrlString('tel:${customerPhone}');
              },
              icon: Icon(Icons.phone),
            )
            : const SizedBox.shrink(),
        projectLocation != null
            ? FilledButton.tonalIcon(
              label: Text(
                "${projectLocation}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onPressed: () {
                launchUrlString(
                  'google.navigation:q=${Uri.encodeComponent(projectLocation)}&mode=d',
                );
              },
              icon: Icon(Icons.directions),
            )
            : const SizedBox.shrink(),
        customerEmail != null
            ? FilledButton.tonalIcon(
              label: Text(
                "${customerEmail}",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              onPressed: () {
                launchUrlString('mailto:${customerEmail}');
              },
              icon: Icon(Icons.email),
            )
            : const SizedBox.shrink(),
      ],
    );
  }
}
