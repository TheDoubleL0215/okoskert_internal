import 'package:flutter/material.dart';

class JoinRequestsPage extends StatelessWidget {
  const JoinRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Csatlakozási kérelmek'),
      ),
      body: const Center(
        child: Text('Csatlakozási kérelmek oldal'),
      ),
    );
  }
}

