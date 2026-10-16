import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/password_security_service.dart';

class AdminCredentialsTab extends StatefulWidget {
  const AdminCredentialsTab({Key? key}) : super(key: key);

  @override
  State<AdminCredentialsTab> createState() => _AdminCredentialsTabState();
}

class _AdminCredentialsTabState extends State<AdminCredentialsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCredentials = [];
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';

  // Set of user IDs for which decrypted password is revealed in the card
  final Set<String> _revealedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchCredentials();
  }

  Future<void> _fetchCredentials() async {
    setState(() => _isLoading = true);
    try {
      final list = await PasswordSecurityService.fetchAllCredentials();
      setState(() {
        _allCredentials = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load credentials: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleReveal(String userId) {
    setState(() {
      if (_revealedUserIds.contains(userId)) {
        _revealedUserIds.remove(userId);
      } else {
        _revealedUserIds.add(userId);
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No credential available to copy')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label copied to clipboard!'),
          ],
        ),
        backgroundColor: const Color(0xFF0D256C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'administrator':
        return const Color(0xFF8B5CF6); // Purple
      case 'lawyer':
        return const Color(0xFFD97706); // Amber / Gold
      case 'advocate clerk':
        return const Color(0xFF0D9488); // Teal
      case 'citizen':
      default:
        return const Color(0xFF2563EB); // Royal Blue
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'administrator':
        return Icons.admin_panel_settings_rounded;
      case 'lawyer':
        return Icons.gavel_rounded;
      case 'advocate clerk':
        return Icons.badge_outlined;
      case 'citizen':
      default:
        return Icons.person_rounded;
    }
  }

  void _showPasswordDetailsDialog(Map<String, dynamic> item) {
    final enc = (item['encrypted_password'] ?? '').toString();
    final dec = (item['decrypted_password'] ?? '').toString();
    final role = (item['role'] ?? 'Citizen').toString();
    final username = (item['username'] ?? 'User').toString();
    final email = (item['email'] ?? 'N/A').toString();
    final lastUpdated = item['password_last_updated']?.toString();

    String formattedDate = 'N/A';
    if (lastUpdated != null) {
      try {
        final dt = DateTime.parse(lastUpdated).toLocal();
        formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        formattedDate = lastUpdated;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isRevealed = _revealedUserIds.contains(item['id'].toString());
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D256C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.key_rounded, color: Color(0xFF0D256C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credential Inspector', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(username, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email & Role
                    _buildInfoRow('Email', email),
                    _buildInfoRow('Role', role),
                    _buildInfoRow('Last Updated', formattedDate),
                    const Divider(height: 24),

                    // Decrypted Password Section
                    Text('DECRYPTED PASSWORD (PLAINTEXT)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_open_rounded, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isRevealed ? (dec.isNotEmpty ? dec : '(Not recorded yet)') : (dec.isNotEmpty ? '••••••••••••' : '(Not recorded yet)'),
                              style: GoogleFonts.firaCode(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(isRevealed ? Icons.visibility_off : Icons.visibility, color: Colors.green.shade700, size: 20),
                            onPressed: () {
                              _toggleReveal(item['id'].toString());
                              setDialogState(() {});
                            },
                            tooltip: isRevealed ? 'Hide' : 'Reveal',
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.green, size: 20),
                            onPressed: () => _copyToClipboard(dec, 'Decrypted password'),
                            tooltip: 'Copy Plaintext',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Encrypted Password Section
                    Text('ENCRYPTED PASSWORD (CIPHERTEXT)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D256C).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0D256C).withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.enhanced_encryption_rounded, color: Color(0xFF0D256C), size: 18),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D256C),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AES-256-CBC',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: Color(0xFF0D256C), size: 18),
                                onPressed: () => _copyToClipboard(enc, 'Encrypted cipher'),
                                tooltip: 'Copy Ciphertext',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            enc.isNotEmpty ? enc : '(Not encrypted yet)',
                            style: GoogleFonts.firaCode(
                              fontSize: 12,
                              color: const Color(0xFF0D256C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF0D256C))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allCredentials.where((item) {
      final role = (item['role'] ?? 'Citizen').toString();
      if (_selectedRoleFilter != 'All' && !role.toLowerCase().contains(_selectedRoleFilter.toLowerCase())) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (item['username'] ?? '').toString().toLowerCase();
      final email = (item['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q) || role.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchCredentials,
      color: const Color(0xFF0D256C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D256C), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0D256C).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supabase Security Vault',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View all user passwords stored in Supabase with both Encrypted and Decrypted representations.',
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by username, email or role...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0D256C)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Citizen',
                  'Lawyer',
                  'Advocate Clerk',
                  'Administrator',
                ].map((role) {
                  final isSelected = _selectedRoleFilter == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(role),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF0D256C),
                      checkmarkColor: Colors.white,
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF0D256C) : Colors.grey.shade300,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedRoleFilter = role);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // List of Accounts
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF0D256C)),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_person_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No credentials found',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try another search term or filter.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final userId = item['id'].toString();
                  final username = (item['username'] ?? 'User').toString();
                  final email = (item['email'] ?? 'N/A').toString();
                  final role = (item['role'] ?? 'Citizen').toString();
                  final encPass = (item['encrypted_password'] ?? '').toString();
                  final decPass = (item['decrypted_password'] ?? '').toString();
                  final isRevealed = _revealedUserIds.contains(userId);
                  final roleColor = _getRoleColor(role);
                  final roleIcon = _getRoleIcon(role);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Avatar, Name, Email, Role Tag
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: roleColor.withOpacity(0.12),
                                child: Icon(roleIcon, color: roleColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            username,
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item['is_verified'] == true) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      email,
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: roleColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  role,
                                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // 1. Decrypted Password Row
                          Row(
                            children: [
                              Icon(Icons.lock_open_rounded, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Decrypted Password:',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _toggleReveal(userId),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        size: 16,
                                        color: const Color(0xFF0D256C),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isRevealed ? 'Hide' : 'Show',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D256C)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                tooltip: 'Copy Decrypted Password',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _copyToClipboard(decPass, 'Decrypted password'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              isRevealed
                                  ? (decPass.isNotEmpty ? decPass : '(Not yet captured - user hasn\'t logged in since update)')
                                  : (decPass.isNotEmpty ? '••••••••••••' : '(Not yet captured)'),
                              style: GoogleFonts.firaCode(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: decPass.isNotEmpty ? Colors.green.shade900 : Colors.grey,
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 2. Encrypted Password Row
                          Row(
                            children: [
                              const Icon(Icons.enhanced_encryption_rounded, size: 16, color: Color(0xFF0D256C)),
                              const SizedBox(width: 6),
                              Text(
                                'Encrypted Password (AES-256):',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.grey),
                                tooltip: 'Copy Encrypted Ciphertext',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _copyToClipboard(encPass, 'Encrypted cipher'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D256C).withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF0D256C).withOpacity(0.12)),
                            ),
                            child: Text(
                              encPass.isNotEmpty ? encPass : '(Not yet encrypted)',
                              style: GoogleFonts.firaCode(
                                fontSize: 11,
                                color: const Color(0xFF0D256C),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Bottom details trigger
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _showPasswordDetailsDialog(item),
                              icon: const Icon(Icons.info_outline, size: 14, color: Color(0xFF0D256C)),
                              label: Text(
                                'View Security Details',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0D256C)),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
