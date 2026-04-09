import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SessionProvider extends ChangeNotifier {
  String? teamId;
  int? role;
  User? user;

  StreamSubscription? _sub;

  void start() {
    debugPrint('SESSION PROVIDER HAS STARTED!');
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      this.user = user;

      if (user == null) {
        _clear();
      } else {
        _listenToUserDoc(user.uid);
      }
    });
  }

  void _listenToUserDoc(String uid) {
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((
      doc,
    ) {
      final data = doc.data();

      if (data?['active'] == false) {
        FirebaseAuth.instance.signOut();
        return;
      }

      final newTeamId = data?['teamId'];
      final newRole = data?['role'];

      final roleChanged = role != newRole;
      final teamChanged = teamId != newTeamId;

      teamId = newTeamId;
      role = newRole;

      if (roleChanged || teamChanged) {
        _handleSessionChange();
      }

      notifyListeners();
    });
  }

  void _handleSessionChange() {
    // 🔥 critical logic here
    // e.g. clear workspace, reload permissions
  }

  void _clear() {
    teamId = null;
    role = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
