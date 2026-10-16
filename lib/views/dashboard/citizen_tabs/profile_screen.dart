import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';
import '../../shared/submit_complaint_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _username = 'Citizen';
  String _email = '';
  String _district = 'Not Specified';
  String _role = 'Citizen';
  DateTime? _createdAt;

  int _casesCount = 0;
  int _consultationsCount = 0;

  // Settings
  bool _notificationsEnabled = true;
  bool _emailUpdatesEnabled = true;

  final List<String> _keralaDistricts = [
    'Thiruvananthapuram', 'Kollam', 'Pathanamthitta', 'Alappuzha',
    'Kottayam', 'Idukki', 'Ernakulam', 'Thrissur', 'Palakkad',
    'Malappuram', 'Kozhikode', 'Wayanad', 'Kannur', 'Kasaragod'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('citizen_notifs_enabled') ?? true;
      _emailUpdatesEnabled = prefs.getBool('citizen_email_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _email = user.email ?? 'No email';

    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        _username = profile['username'] ?? user.userMetadata?['username'] ?? 'Citizen';
        _district = profile['district'] ?? 'Not Specified';
        _role = profile['role'] ?? 'Citizen';
        if (profile['created_at'] != null) {
          _createdAt = DateTime.tryParse(profile['created_at'].toString());
        }
      } else {
        _username = user.userMetadata?['username'] ?? 'Citizen';
        _role = user.userMetadata?['role'] ?? 'Citizen';
      }

      // Fetch case count
      final casesRes = await _supabase
          .from('cases')
          .select('id')
          .eq('user_id', user.id);
      _casesCount = (casesRes as List).length;

      // Fetch consultation count
      if (_username.isNotEmpty) {
        final requestsRes = await _supabase
            .from('consultation_requests')
            .select('id')
            .eq('citizen_name', _username);
        _consultationsCount = (requestsRes as List).length;
      }
    } catch (e) {
      debugPrint('Error loading citizen profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _username);
    String selectedDistrict = _keralaDistricts.contains(_district) 
        ? _district 
        : _keralaDistricts.first;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name / Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDistrict,
                    decoration: const InputDecoration(
                      labelText: 'District',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: _keralaDistricts.map((d) {
                      return DropdownMenuItem(value: d, child: Text(d));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedDistrict = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving ? null : () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty')),
                    );
                    return;
                  }

                  setDialogState(() => isSaving = true);
                  final user = _supabase.auth.currentUser;
                  if (user != null) {
                    try {
                      await _supabase.from('profiles').update({
                        'username': newName,
                        'district': selectedDistrict,
                      }).eq('id', user.id);

                      // Also update user metadata
                      await _supabase.auth.updateUser(
                        UserAttributes(data: {'username': newName}),
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      if (mounted) {
                        setState(() {
                          _username = newName;
                          _district = selectedDistrict;
                        });
                      }
                    } catch (e) {
                      debugPrint('Error updating profile: $e');
                      if (ctx.mounted) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Change Password', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving ? null : () async {
                  final newPass = passwordController.text.trim();
                  final confirmPass = confirmController.text.trim();

                  if (newPass.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Password must be at least 6 characters')),
                    );
                    return;
                  }
                  if (newPass != confirmPass) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }

                  setDialogState(() => isSaving = true);
                  try {
                    await _supabase.auth.updateUser(UserAttributes(password: newPass));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setDialogState(() => isSaving = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed to update password: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Settings', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive alerts for case hearings and lawyer messages'),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setModalState(() => _notificationsEnabled = val);
                    setState(() => _notificationsEnabled = val);
                    _saveSetting('citizen_notifs_enabled', val);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Get appointment and filing summaries in email'),
                  value: _emailUpdatesEnabled,
                  onChanged: (val) {
                    setModalState(() => _emailUpdatesEnabled = val);
                    setState(() => _emailUpdatesEnabled = val);
                    _saveSetting('citizen_email_enabled', val);
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text('Account & Security', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset, color: Colors.blueAccent),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your login password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showChangePasswordDialog();
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('App Version', style: GoogleFonts.inter(color: Colors.grey.shade600)),
                      Text('JusticeConnect v1.0.4', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHelpAndSupportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Help & Support', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Contact Us', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.email_outlined, color: Colors.blue),
                      title: const Text('Email Support'),
                      subtitle: const Text('justiceconnect2026@gmail.com'),
                      trailing: const Icon(Icons.copy, size: 18),
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'justiceconnect2026@gmail.com'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support email copied to clipboard!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Frequently Asked Questions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildFaqItem(
                    'How do I book a consultation with a lawyer?',
                    'Navigate to the "Lawyers" tab in the bottom bar, browse verified advocates by practice area or district, select a lawyer, and tap "Book Consultation" with your preferred date and time.',
                  ),
                  _buildFaqItem(
                    'How can I track my case status?',
                    'Go to the "My Cases" tab. All active cases where you are listed as a client will appear with live hearing dates, court details, and advocate clerk updates.',
                  ),
                  _buildFaqItem(
                    'Is my evidence and communication secure?',
                    'Yes. All evidence and chat messages on JusticeConnect are encrypted and accessible strictly between you, your assigned advocate, and court staff.',
                  ),
                  _buildFaqItem(
                    'What should I do if a hearing date changes?',
                    'Your advocate or advocate clerk will update the timeline on your case card. You will receive an immediate notification under the notifications bell on your dashboard.',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SubmitComplaintScreen()),
                        );
                      },
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('File a Complaint / Report Issue'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(question, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(answer, style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Privacy Policy', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('Last Updated: September 2026', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  Text(
                    '1. Lawyer-Client Confidentiality',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'JusticeConnect strictly upholds privileged communication rules under Section 126 of the Indian Evidence Act. All consultations, legal opinions, and messages between you and verified advocates remain confidential.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '2. Evidence & Document Security',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All case files and evidence uploaded to JusticeConnect are stored in encrypted cloud storage with restricted access policies. Only authorized advocates and verified advocate clerks assigned to your case can review uploaded materials.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '3. Personal Information We Collect',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We collect your name, email, district, and consultation history to enable legal matching and court proceedings tracking. We do not sell or share your data with advertisers.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '4. Your Rights & Data Deletion',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You have the right to request deletion of your account and personal history at any time by contacting justiceconnect2026@gmail.com.',
                    style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('I Understand'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log Out', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_outlined, color: Colors.blue),
            tooltip: 'Support & Grievances',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubmitComplaintScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Profile Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: primaryColor.withOpacity(0.1),
                            child: Text(
                              _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                              style: GoogleFonts.outfit(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _username,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_user, size: 14, color: primaryColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      _role,
                                      style: GoogleFonts.inter(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      _district,
                                      style: GoogleFonts.inter(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_createdAt != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Member since ${DateFormat('MMMM yyyy').format(_createdAt!)}',
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            title: 'My Cases',
                            value: '$_casesCount',
                            icon: Icons.gavel_outlined,
                            color: Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            title: 'Consultations',
                            value: '$_consultationsCount',
                            icon: Icons.chat_bubble_outline,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Actions / Options Menu Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuOption(
                            icon: Icons.person_outline,
                            iconColor: Colors.blue,
                            title: 'Edit Profile Information',
                            subtitle: 'Update your name and primary district',
                            onTap: _showEditProfileDialog,
                          ),
                          const Divider(height: 1, indent: 64),
                          _buildMenuOption(
                            icon: Icons.settings_outlined,
                            iconColor: Colors.purple,
                            title: 'Settings',
                            subtitle: 'Notifications, password & security',
                            onTap: _showSettingsModal,
                          ),
                          const Divider(height: 1, indent: 64),
                          _buildMenuOption(
                            icon: Icons.help_outline,
                            iconColor: Colors.amber.shade800,
                            title: 'Help & Support',
                            subtitle: 'FAQs, contact support and feedback',
                            onTap: _showHelpAndSupportModal,
                          ),
                          const Divider(height: 1, indent: 64),
                          _buildMenuOption(
                            icon: Icons.report_problem_outlined,
                            iconColor: Colors.redAccent,
                            title: 'Complaints & Grievances',
                            subtitle: 'Report any issue or grievance directly to admin',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SubmitComplaintScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 64),
                          _buildMenuOption(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: Colors.green,
                            title: 'Privacy Policy',
                            subtitle: 'Confidentiality and data protection',
                            onTap: _showPrivacyPolicyModal,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: Text(
                          'Log Out',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B)),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
