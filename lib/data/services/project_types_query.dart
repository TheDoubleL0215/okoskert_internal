import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectTypeService {
  static Future<List<Map<String, dynamic>>> getWorkTypesOnce() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('workTypes').get();

    return snapshot.docs.map((doc) {
      return {'id': doc.id, ...doc.data()};
    }).toList();
  }
}
