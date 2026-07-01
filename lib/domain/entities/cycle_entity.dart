enum CycleStatus { open, completed }

class CycleEntity {
  final String id;
  final CycleStatus status;
  final DateTime openedAt;
  final DateTime? completedAt;

  const CycleEntity({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'openedAt': openedAt.toUtc().toIso8601String(),
        'completedAt': completedAt?.toUtc().toIso8601String(),
      };

  factory CycleEntity.fromMap(String id, Map<String, dynamic> map) => CycleEntity(
        id: id,
        status: (map['status'] as String?) == 'completed'
            ? CycleStatus.completed
            : CycleStatus.open,
        openedAt: DateTime.parse(map['openedAt'] as String).toUtc(),
        completedAt: map['completedAt'] == null
            ? null
            : DateTime.parse(map['completedAt'] as String).toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is CycleEntity &&
      other.id == id &&
      other.status == status &&
      other.openedAt == openedAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(id, status, openedAt, completedAt);
}
