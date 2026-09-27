import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/legal_case.dart';

class CauselistCard extends StatelessWidget {
  final LegalCase legalCase;
  final VoidCallback? onTap;
  final Widget? bottomAction;

  const CauselistCard({
    Key? key,
    required this.legalCase,
    this.onTap,
    this.bottomAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine the date to show on the left.
    // If nextHearingDate is null, fallback to registeredAt
    final displayDate = legalCase.nextHearingDate ?? legalCase.registeredAt;
    final month = DateFormat('MMM').format(displayDate).toUpperCase();
    final day = DateFormat('dd').format(displayDate);
    final year = DateFormat('yyyy').format(displayDate);

    // Determine status badge color
    Color statusColor = Colors.blue;
    Color statusBgColor = Colors.blue.withOpacity(0.1);
    if (legalCase.status.toLowerCase() == 'completed' || legalCase.status.toLowerCase() == 'resolved') {
      statusColor = Colors.green;
      statusBgColor = Colors.green.withOpacity(0.1);
    }

    final cardWidget = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: bottomAction == null ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Date Section
              Container(
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  border: Border(
                    right: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D256C),
                      ),
                    ),
                    Text(
                      day,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      year,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        legalCase.status == 'Ongoing' ? 'Pending' : legalCase.status,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Details Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top Row: Case Number and Heart Icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              legalCase.caseNumber.isEmpty ? 'Case No. Unassigned' : legalCase.caseNumber,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Court
                      Row(
                        children: [
                          Icon(Icons.gavel, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              legalCase.courtName ?? 'Court Not Assigned',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Petitioner
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Petitioner: ${legalCase.petitioner ?? 'Unknown'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Respondent
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Respondent: ${legalCase.respondent ?? 'Unknown'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bottom Info and Doc Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    text: 'Next Hearing: ',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                                    children: [
                                      TextSpan(
                                        text: legalCase.nextHearingDate != null ? DateFormat('dd/MM/yyyy').format(legalCase.nextHearingDate!) : 'TBD',
                                        style: GoogleFonts.inter(color: Colors.blue[300]),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    text: 'Purpose: ',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                                    children: [
                                      TextSpan(
                                        text: legalCase.purpose ?? 'Not Specified',
                                        style: GoogleFonts.inter(color: Colors.green[400]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.description_outlined, color: Colors.blue[400], size: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (bottomAction != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cardWidget,
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: bottomAction!,
          ),
        ],
      );
    }
    return cardWidget;
  }
}
