class Group {
  final String id;
  final String name;
  final List<String> members;
  final Map<String, double> balances;
  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.balances,
  });
  factory Group.fromMap(String id, Map<String, dynamic> data) => Group(
    id: id,
    name: data['name'] ?? '',
    members: List<String>.from(data['members'] ?? []),
    balances: Map<String, double>.from(data['balances'] ?? {}),
  );
}
