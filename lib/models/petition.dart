class Petition {
  final String id;
  final String caseId;
  final String lawyerId;
  final String petitionUrl;
  final String status;
  final DateTime submittedAt;
  final DateTime? updatedAt;

  Petition({
    required this.id,
    required this.caseId,
    required this.lawyerId,
    required this.petitionUrl,
    required this.status,
    required this.submittedAt,
    this.updatedAt,
  });

  factory Petition.fromJson(Map<String, dynamic> json) {
    return Petition(
      id: json['id'],
      caseId: json['case_id'],
      lawyerId: json['lawyer_id'],
      petitionUrl: json['petition_url'],
      status: json['status'] ?? 'Submitted',
      submittedAt: DateTime.parse(json['submitted_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'lawyer_id': lawyerId,
      'petition_url': petitionUrl,
      'status': status,
      'submitted_at': submittedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
