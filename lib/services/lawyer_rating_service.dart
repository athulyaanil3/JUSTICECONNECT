import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LawyerRatingService {
  /// Check whether a lawyer has received user reviews/ratings through the app
  static bool hasAppReviews(Map<String, dynamic> lawyer) {
    final count = int.tryParse(lawyer['rating_count']?.toString() ?? '0') ?? 0;
    final rating = double.tryParse(lawyer['rating']?.toString() ?? '0') ?? 0.0;
    return count > 0 && rating > 0.0;
  }

  /// Get the experience display string from profile or enrollment year
  static String getExperienceString(Map<String, dynamic> lawyer) {
    // 1. Check explicit experience field
    final rawExp = lawyer['experience'];
    if (rawExp != null) {
      final parsed = int.tryParse(rawExp.toString());
      if (parsed != null && parsed > 0) {
        return '$parsed+ Yrs Experience';
      }
    }

    // 2. Check enrollment year from bar council registration
    final enrollmentYear = lawyer['enrollment_year'];
    if (enrollmentYear != null) {
      final year = int.tryParse(enrollmentYear.toString());
      if (year != null && year > 1950 && year <= DateTime.now().year) {
        final years = DateTime.now().year - year;
        if (years > 0) {
          return '$years+ Yrs Experience';
        } else {
          return '1st Yr Advocate';
        }
      }
    }

    return 'Practicing Advocate';
  }

  /// Submits a user review, calculates the rating formula, and updates the lawyer's profile
  static Future<Map<String, dynamic>> submitRating({
    required String lawyerId,
    required String citizenId,
    required int rating,
    String? reviewText,
    String? caseId,
    String? officeId,
  }) async {
    final supabase = Supabase.instance.client;

    // Check if lawyer has an office if not provided
    String? resolvedOfficeId = officeId;
    if (resolvedOfficeId == null) {
      try {
        final profileRes = await supabase
            .from('profiles')
            .select('office_id')
            .eq('id', lawyerId)
            .maybeSingle();
        resolvedOfficeId = profileRes?['office_id'];
      } catch (e) {
        debugPrint('Could not fetch lawyer office_id: $e');
      }
    }

    final reviewPayload = <String, dynamic>{
      'citizen_id': citizenId,
      'lawyer_id': lawyerId,
      'rating': rating,
    };
    if (caseId != null) reviewPayload['case_id'] = caseId;
    if (resolvedOfficeId != null) reviewPayload['office_id'] = resolvedOfficeId;
    if (reviewText != null && reviewText.trim().isNotEmpty) {
      reviewPayload['review_text'] = reviewText.trim();
    }

    // 1. Insert review into Supabase
    await supabase.from('reviews').insert(reviewPayload);

    // 2. Fetch all reviews for this lawyer to compute formula
    final reviewsRes = await supabase
        .from('reviews')
        .select('rating')
        .eq('lawyer_id', lawyerId);

    double total = 0.0;
    for (var row in reviewsRes) {
      total += (row['rating'] as num).toDouble();
    }

    final newCount = reviewsRes.length;
    // Formula: Sum of ratings / Count of reviews, rounded to 1 decimal place
    final newRating = newCount > 0
        ? double.parse((total / newCount).toStringAsFixed(1))
        : 0.0;

    // 3. Reflect the calculated rating to the lawyer's profile
    await supabase.from('profiles').update({
      'rating': newRating,
      'rating_count': newCount,
    }).eq('id', lawyerId);

    // 4. If associated with an office, update the office rating as well
    if (resolvedOfficeId != null) {
      try {
        final officeReviews = await supabase
            .from('reviews')
            .select('rating')
            .eq('office_id', resolvedOfficeId);

        double officeTotal = 0.0;
        for (var row in officeReviews) {
          officeTotal += (row['rating'] as num).toDouble();
        }
        final officeCount = officeReviews.length;
        final newOfficeRating = officeCount > 0
            ? double.parse((officeTotal / officeCount).toStringAsFixed(1))
            : 0.0;

        await supabase.from('lawyer_offices').update({
          'rating': newOfficeRating,
          'rating_count': officeCount,
        }).eq('id', resolvedOfficeId);
      } catch (e) {
        debugPrint('Error updating office rating: $e');
      }
    }

    return {
      'rating': newRating,
      'rating_count': newCount,
    };
  }

  /// Show the interactive rating dialog
  static Future<bool> showRatingDialog({
    required BuildContext context,
    required String lawyerId,
    required String lawyerName,
    String? caseId,
    String? officeId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to rate this lawyer.')),
      );
      return false;
    }

    int selectedRating = 5;
    final textController = TextEditingController();
    bool isSubmitting = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star, color: Colors.amber, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rate $lawyerName',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How was your experience working with this advocate through the app?',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber[600],
                            size: 32,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedRating = index + 1;
                                  });
                                },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      maxLines: 3,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'Share details of your experience (optional)...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          try {
                            await submitRating(
                              lawyerId: lawyerId,
                              citizenId: user.id,
                              rating: selectedRating,
                              reviewText: textController.text.trim(),
                              caseId: caseId,
                              officeId: officeId,
                            );

                            if (ctx.mounted) Navigator.pop(dialogCtx, true);
                          } catch (e) {
                            debugPrint('Error rating lawyer: $e');
                            setDialogState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to submit rating: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Submit Rating', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }
}
