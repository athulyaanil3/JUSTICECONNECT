class OfficeLawyer {
  final String id;
  final String name;
  final String imageUrl;
  final double rating;
  final int reviewsCount;
  final List<String> focusingCases;

  OfficeLawyer({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.focusingCases,
  });

  factory OfficeLawyer.fromJson(Map<String, dynamic> json) {
    return OfficeLawyer(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewsCount: json['reviews_count'] as int,
      focusingCases: List<String>.from(json['focusing_cases'] ?? []),
    );
  }
}

class LawyerOffice {
  final String id;
  final String name;
  final String location;
  final String address;
  final String imageUrl;
  final String contactNumber;
  final double rating;
  final List<OfficeLawyer> lawyers;

  LawyerOffice({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    required this.imageUrl,
    required this.contactNumber,
    required this.rating,
    required this.lawyers,
  });

  factory LawyerOffice.fromJson(Map<String, dynamic> json) {
    var lawyersJson = json['office_lawyers'] as List<dynamic>? ?? [];
    List<OfficeLawyer> parsedLawyers = lawyersJson
        .map((lawyerJson) => OfficeLawyer.fromJson(lawyerJson as Map<String, dynamic>))
        .toList();

    return LawyerOffice(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      address: json['address'] as String,
      imageUrl: json['image_url'] as String,
      contactNumber: json['contact_number'] as String,
      rating: (json['rating'] as num).toDouble(),
      lawyers: parsedLawyers,
    );
  }
}
