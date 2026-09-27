class Filing {
  final String id;
  final String title;
  final String category;
  final String description;
  final String userId;
  final String lawyerId;
  final String status;
  final DateTime submittedAt;
  final List<String> documents; // URLs or paths

  Filing({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.userId,
    required this.lawyerId,
    required this.status,
    required this.submittedAt,
    required this.documents,
  });

  factory Filing.fromJson(Map<String, dynamic> json) {
    return Filing(
      id: json['id'],
      title: json['title'],
      category: json['category'],
      description: json['description'] ?? '',
      userId: json['user_id'],
      lawyerId: json['lawyer_id'],
      status: json['status'],
      submittedAt: DateTime.parse(json['submitted_at']),
      documents: List<String>.from(json['documents'] ?? []),
    );
  }
}
