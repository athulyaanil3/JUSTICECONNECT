class ConsultationRequest {
  final String id;
  final String citizenName;
  final String lawyerName;
  final String issueDescription;
  final DateTime requestedAt;
  String status; // 'Pending', 'Accepted', 'Rejected'
  List<Map<String, dynamic>> messages;

  ConsultationRequest({
    required this.id,
    required this.citizenName,
    required this.lawyerName,
    required this.issueDescription,
    required this.requestedAt,
    this.status = 'Pending',
    List<Map<String, dynamic>>? messages,
  }) : messages = messages ?? [];
}
