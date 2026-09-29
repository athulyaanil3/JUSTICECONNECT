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
  final String? storagePath;
  final int? fileSize;
  final String? mimeType;
  final String? encryptionAlgorithm;
  final String? encryptionVersion;
  final String? encryptedKey;
  final String? nonce;

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
    this.storagePath,
    this.fileSize,
    this.mimeType,
    this.encryptionAlgorithm,
    this.encryptionVersion,
    this.encryptedKey,
    this.nonce,
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
      storagePath: json['storage_path'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      encryptionAlgorithm: json['encryption_algorithm'],
      encryptionVersion: json['encryption_version'],
      encryptedKey: json['encrypted_key'],
      nonce: json['nonce'],
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
      if (storagePath != null) 'storage_path': storagePath,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      if (encryptionAlgorithm != null) 'encryption_algorithm': encryptionAlgorithm,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (encryptedKey != null) 'encrypted_key': encryptedKey,
      if (nonce != null) 'nonce': nonce,
    };
  }
}
