/// Egy workspace `wageTypes` dokumentum kiválasztáshoz.
class WageTypeOption {
  const WageTypeOption({
    required this.id,
    required this.name,
    required this.defaultValue,
  });

  final String id;
  final String name;
  final int defaultValue;
}
