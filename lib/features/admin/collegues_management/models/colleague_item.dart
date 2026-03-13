/// Egy munkatárs megjelenítési modellje a listában.
class ColleagueItem {
  const ColleagueItem({
    required this.id,
    required this.name,
    required this.email,
    required this.salary,
  });

  final String id;
  final String name;
  final String email;
  final int salary;
}
