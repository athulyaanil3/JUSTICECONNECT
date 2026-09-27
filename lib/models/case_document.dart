class CaseDocument {
  final String id;
  final String caseId;
  final String uploadedBy;
  final String documentType;
  final String documentName;
  final String documentUrl;
  final String verificationStatus; // 'Pending', 'Verified', 'Missing', 'Invalid'
  final String remarks;
  final DateTime createdAt;

  CaseDocument({
    required this.id,
    required this.caseId,
    required this.uploadedBy,
    required this.documentType,
    required this.documentName,
    required this.documentUrl,
    required this.verificationStatus,
    required this.remarks,
    required this.createdAt,
  });

  factory CaseDocument.fromJson(Map<String, dynamic> json) {
    return CaseDocument(
      id: json['id'],
      caseId: json['case_id'],
      uploadedBy: json['uploaded_by'] ?? '',
      documentType: json['document_type'] ?? 'General',
      documentName: json['document_name'],
      documentUrl: json['document_url'] ?? '',
      verificationStatus: json['verification_status'] ?? 'Pending',
      remarks: json['remarks'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'uploaded_by': uploadedBy,
      'document_type': documentType,
      'document_name': documentName,
      'document_url': documentUrl,
      'verification_status': verificationStatus,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
