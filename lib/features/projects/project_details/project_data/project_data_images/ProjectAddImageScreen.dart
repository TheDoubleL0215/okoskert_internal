import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProjectAddImageScreen extends StatefulWidget {
  final String projectId;
  const ProjectAddImageScreen({super.key, required this.projectId});

  @override
  State<ProjectAddImageScreen> createState() => _ProjectAddImageScreenState();
}

class _ProjectAddImageScreenState extends State<ProjectAddImageScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  String? imageUrl;

  Future<void> pickImage() async {
    try {
      XFile? res = await _imagePicker.pickImage(source: ImageSource.gallery);

      if (res != null) {
        await uploadImageToFirebase(File(res.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to pick an image: $e")));
    }
  }

  Future<void> uploadImageToFirebase(File image) async {
    try {
      Reference reference = FirebaseStorage.instance.ref().child(
        "projects/${widget.projectId}/images/${DateTime.now().millisecondsSinceEpoch}",
      );

      // Wait for the upload to complete
      await reference.putFile(image);

      // Get the download URL after upload completes
      imageUrl = await reference.getDownloadURL();

      // Show success message only after everything is done
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Image uploaded successfully!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload an image: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kép hozzáadása')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => pickImage(),
              child: Text('Kép kiválasztása'),
            ),
          ],
        ),
      ),
    );
  }
}
