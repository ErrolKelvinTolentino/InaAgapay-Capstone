enum VaccineStatus {
  done,
  pending,
  locked,
}

class VaccineDefinition {
  final String key; // 👈 unique ID (important for DB mapping)
  final String name;

  const VaccineDefinition({
    required this.key,
    required this.name,
  });
}

class VaccineAgeGroup {
  final String label; // e.g. "At Birth"
  final int week;
  final List<VaccineDefinition> vaccines;

  const VaccineAgeGroup({
    required this.label,
    required this.week,
    required this.vaccines,
  });
}

/// 🧠 THIS NEVER CHANGES
const List<VaccineAgeGroup> vaccineSchedule = [
  VaccineAgeGroup(
    label: 'At Birth',
    week: 0,
    vaccines: [
      VaccineDefinition(key: 'bcg', name: 'BCG'),
      VaccineDefinition(key: 'opv0', name: 'OPV 0'),
    ],
  ),
  VaccineAgeGroup(
    label: '6 Weeks',
    week: 6,
    vaccines: [
      VaccineDefinition(key: 'opv1', name: 'OPV 1'),
      VaccineDefinition(key: 'penta1', name: 'Pentavalent 1'),
      VaccineDefinition(key: 'pcv1', name: 'PCV 1'),
      VaccineDefinition(key: 'rota1', name: 'Rotavirus 1'),
    ],
  ),
  VaccineAgeGroup(
    label: '10 Weeks',
    week: 10,
    vaccines: [
      VaccineDefinition(key: 'opv2', name: 'OPV 2'),
      VaccineDefinition(key: 'penta2', name: 'Pentavalent 2'),
      VaccineDefinition(key: 'pcv2', name: 'PCV 2'),
      VaccineDefinition(key: 'rota2', name: 'Rotavirus 2'),
    ],
  ),
  VaccineAgeGroup(
    label: '14 Weeks',
    week: 14,
    vaccines: [
      VaccineDefinition(key: 'opv3', name: 'OPV 3'),
      VaccineDefinition(key: 'penta3', name: 'Pentavalent 3'),
      VaccineDefinition(key: 'pcv3', name: 'PCV 3'),
      VaccineDefinition(key: 'ipv', name: 'IPV'),
    ],
  ),
];
