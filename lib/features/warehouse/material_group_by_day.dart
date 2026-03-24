import 'package:cloud_firestore/cloud_firestore.dart';

/// Csoportosítás: ha nincs `date` / `createdAt`, ide kerülnek (fejléc: „Dátum nélkül”).
final DateTime materialUnknownDay = DateTime(1900, 1, 1);

DateTime materialDayKey(Map<String, dynamic> data) {
  final dateTs = data['date'] as Timestamp?;
  if (dateTs != null) {
    final d = dateTs.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  final createdTs = data['createdAt'] as Timestamp?;
  if (createdTs != null) {
    final d = createdTs.toDate();
    return DateTime(d.year, d.month, d.day);
  }
  return materialUnknownDay;
}

Map<DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupMaterialsByDay(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final map = <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
  for (final doc in docs) {
    final key = materialDayKey(doc.data());
    map.putIfAbsent(key, () => []).add(doc);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final na = (a.data()['name'] as String? ?? '').toLowerCase();
      final nb = (b.data()['name'] as String? ?? '').toLowerCase();
      return na.compareTo(nb);
    });
  }
  return map;
}

String materialDaySectionTitle(DateTime day) {
  if (day == materialUnknownDay) {
    return 'Dátum nélkül';
  }
  return '${day.year}. ${day.month.toString().padLeft(2, '0')}. ${day.day.toString().padLeft(2, '0')}.';
}
