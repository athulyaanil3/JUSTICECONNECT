class CaseUpdate {
  final String id;
  final String caseId;
  final String updateType;
  final String description;
  final String createdBy;
  final DateTime createdAt;

  CaseUpdate({
    required this.id,
    required this.caseId,
    required this.updateType,
    required this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory CaseUpdate.fromJson(Map<String, dynamic> json) {
    return CaseUpdate(
      id: json['id'],
      caseId: json['case_id'],
      updateType: json['update_type'],
      description: json['description'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'update_type': updateType,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
