import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeService {
  /// Lekérdezi az összes dolgozót a Firestore "employees" kollekcióból
  ///
  /// Visszatér a dolgozók listájával Map formátumban
  static Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('employees').get();

      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();
    } catch (e) {
      rethrow;
    }
  }
}

