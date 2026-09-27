class Hearing {
  final String id;
  final String caseId;
  final DateTime hearingDate;
  final String courtroom;
  final String hearingType;
  final String status;
  final String remarks;

  Hearing({
    required this.id,
    required this.caseId,
    required this.hearingDate,
    required this.courtroom,
    required this.hearingType,
    required this.status,
    required this.remarks,
  });

  factory Hearing.fromJson(Map<String, dynamic> json) {
    return Hearing(
      id: json['id'],
      caseId: json['case_id'],
      hearingDate: DateTime.parse(json['hearing_date']),
      courtroom: json['courtroom'] ?? '',
      hearingType: json['hearing_type'] ?? '',
      status: json['status'],
      remarks: json['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'hearing_date': hearingDate.toIso8601String(),
      'courtroom': courtroom,
      'hearing_type': hearingType,
      'status': status,
      'remarks': remarks,
    };
  }
}
