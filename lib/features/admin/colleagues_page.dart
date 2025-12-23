import 'package:flutter/material.dart';

class ColleaguesPage extends StatelessWidget {
  const ColleaguesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Munkatársak'),
      ),
      body: const Center(
        child: Text('Munkatársak oldal'),
      ),
    );
  }
}

