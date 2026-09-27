class LegalCase {
  final String id;
  final String caseNumber; // Official Case Number (e.g. MC 23/2026)
  final String title;
  final String category;
  final String userId;
  final String lawyerId;
  final String advocateClerkId;
  final String description;
  final DateTime registeredAt; // Equivalent to created_at
  final DateTime? updatedAt;
  final String status;

  // New Official Case Tracking Fields
  final String? petitioner;
  final String? respondent;
  final String? courtName;
  final DateTime? nextHearingDate;
  final String? purpose;

  LegalCase({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.category,
    required this.userId,
    required this.lawyerId,
    required this.advocateClerkId,
    required this.description,
    required this.registeredAt,
    this.updatedAt,
    required this.status,
    this.petitioner,
    this.respondent,
    this.courtName,
    this.nextHearingDate,
    this.purpose,
  });

  factory LegalCase.fromJson(Map<String, dynamic> json) {
    return LegalCase(
      id: json['id'],
      caseNumber: json['case_number'] ?? '',
      title: json['title'] ?? json['case_title'] ?? '',
      category: json['category'] ?? json['case_category'] ?? '',
      userId: json['user_id'] ?? '',
      lawyerId: json['lawyer_id'] ?? '',
      advocateClerkId: json['advocate_clerk_id'] ?? json['bench_clerk_id'] ?? '', // fallback for migration
      description: json['description'] ?? json['case_description'] ?? '',
      registeredAt: DateTime.parse(json['registered_at'] ?? json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      status: json['status'] ?? 'Submitted',
      petitioner: json['petitioner'],
      respondent: json['respondent'],
      courtName: json['court_name'],
      nextHearingDate: json['next_hearing_date'] != null ? DateTime.parse(json['next_hearing_date']) : null,
      purpose: json['purpose'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_number': caseNumber,
      'case_title': title,
      'case_category': category,
      'user_id': userId,
      'lawyer_id': lawyerId,
      'advocate_clerk_id': advocateClerkId,
      'case_description': description,
      'created_at': registeredAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status,
      'petitioner': petitioner,
      'respondent': respondent,
      'court_name': courtName,
      'next_hearing_date': nextHearingDate?.toIso8601String(),
      'purpose': purpose,
    };
  }
}
