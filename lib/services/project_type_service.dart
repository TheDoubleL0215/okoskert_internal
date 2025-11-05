import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectTypeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'workTypes';

  /// Inicializálja az összes projekt típust Firestore-ba batch write-tel
  static Future<void> initializeProjectTypes() async {
    final projectTypes = [
      {'name': 'Tó kialakítás', 'order': 1, 'category': 'Tó', 'active': true},
      {'name': 'Tó karbantartás', 'order': 2, 'category': 'Tó', 'active': true},
      {
        'name': 'Általános kert karbantartás',
        'order': 3,
        'category': 'Kert',
        'active': true,
      },
      {
        'name': 'Öntözőrendszer javítás',
        'order': 4,
        'category': 'Öntözés',
        'active': true,
      },
      {
        'name': 'Öntözőrendszer kiépítés',
        'order': 5,
        'category': 'Öntözés',
        'active': true,
      },
      {
        'name': 'Öntözőrendszer csere',
        'order': 6,
        'category': 'Öntözés',
        'active': true,
      },
      {
        'name': 'Növény ültetés',
        'order': 7,
        'category': 'Kert',
        'active': true,
      },
      {'name': 'Metszés', 'order': 8, 'category': 'Kert', 'active': true},
      {'name': 'Fakivágás', 'order': 9, 'category': 'Fa', 'active': true},
      {
        'name': 'Veszélyes fakivágás',
        'order': 10,
        'category': 'Fa',
        'active': true,
      },
    ];

    // Batch write - maximum 500 művelet egy batch-ben
    WriteBatch batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (var projectType in projectTypes) {
      final docRef = _firestore.collection(_collectionName).doc();
      batch.set(docRef, {...projectType, 'createdAt': now, 'updatedAt': now});
    }

    await batch.commit();
  }

  /// Törli az összes projekt típust (hasznos teszteléshez)
  static Future<void> deleteAllProjectTypes() async {
    final snapshot = await _firestore.collection(_collectionName).get();
    WriteBatch batch = _firestore.batch();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Lekéri az összes aktív projekt típust
  static Stream<List<Map<String, dynamic>>> getProjectTypes() {
    return _firestore
        .collection(_collectionName)
        .where('active', isEqualTo: true)
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList(),
        );
  }
}
