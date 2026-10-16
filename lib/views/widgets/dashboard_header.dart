import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onChatTap;
  final String? roleTag;

  const DashboardHeader({
    Key? key,
    required this.title,
    required this.subtitle,
    this.unreadNotifications = 0,
    required this.onNotificationTap,
    this.onProfileTap,
    this.onChatTap,
    this.roleTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadNotifications > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 56, left: 24, right: 24, bottom: 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D256C), Color(0xFF1A3B99)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x330D256C),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roleTag != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    roleTag!.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade200,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onChatTap != null) ...[
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                      tooltip: 'Messages & Chats',
                      onPressed: onChatTap,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                        tooltip: 'Notifications',
                        onPressed: onNotificationTap,
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadNotifications',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (onProfileTap != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onProfileTap,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}
