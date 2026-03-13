import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:okoskert_internal/data/services/users_services.dart';
import 'package:okoskert_internal/features/admin/collegues_management/models/colleague_item.dart';

/// ViewModel a munkatársak listája képernyőhöz.
///
/// Feladata:
/// - a csapat felhasználóinak streame figyelése
/// - Firestore dokumentumok átalakítása [ColleagueItem] listává
/// - órabér érték konvertálása (toIntSalary)
class ColleaguesViewModel {
  ColleaguesViewModel();

  /// A csapat munkatársainak streame, már [ColleagueItem] listaként.
  Stream<List<ColleagueItem>> get colleaguesStream =>
      UsersServices.getUsers().map(_docsToColleagueItems);

  /// Nyers salary mező (int, num, string) konvertálása int-re.
  static int toIntSalary(dynamic rawSalary) {
    if (rawSalary is int) return rawSalary;
    if (rawSalary is num) return rawSalary.toInt();
    return int.tryParse(rawSalary?.toString() ?? '') ?? 0;
  }

  List<ColleagueItem> _docsToColleagueItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      return ColleagueItem(
        id: doc.id,
        name: data['name']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        salary: toIntSalary(data['salary']),
      );
    }).toList();
  }
}
