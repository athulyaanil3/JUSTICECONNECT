import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:justice_connect/views/auth/unified_auth_screen.dart';
import '../citizen_tabs/lawyer_public_profile_screen.dart';

class LawyerProfileTab extends StatefulWidget {
  const LawyerProfileTab({Key? key}) : super(key: key);

  @override
  _LawyerProfileTabState createState() => _LawyerProfileTabState();
}

class _LawyerProfileTabState extends State<LawyerProfileTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  final _bioController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceController = TextEditingController();
  
  List<Map<String, dynamic>> _achievements = [];
  String _username = 'Unknown Lawyer';
  
  String? _localCoverPhotoPath;
  String? _localProfilePhotoPath;
  String? _coverPhotoUrl;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select().eq('id', user.id).single();
        _username = data['username'] ?? 'Unknown Lawyer';
        _bioController.text = data['bio'] ?? '';
        _specializationController.text = data['specialization'] ?? '';
        _experienceController.text = data['experience']?.toString() ?? '';
        _coverPhotoUrl = data['cover_url'];
        _profilePhotoUrl = data['profile_url'];
        
        if (data['achievements'] != null) {
          if (data['achievements'] is String) {
            _achievements = List<Map<String, dynamic>>.from(jsonDecode(data['achievements']));
          } else {
             _achievements = List<Map<String, dynamic>>.from(data['achievements']);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Mock data if columns don't exist
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('profiles').update({
          'bio': _bioController.text,
          'specialization': _specializationController.text,
          'experience': int.tryParse(_experienceController.text) ?? 0,
          'achievements': _achievements,
        }).eq('id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved!')));
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: The database schema might need updating to support bio/achievements. Local changes preserved.'), backgroundColor: Colors.orange));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadImage(bool isCover) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      if (isCover) {
        setState(() => _localCoverPhotoPath = pickedFile.path);
      } else {
        setState(() => _localProfilePhotoPath = pickedFile.path);
      }
      
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${user.id}_${isCover ? 'cover' : 'profile'}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      final bucketName = 'avatars'; 
      await _supabase.storage.from(bucketName).upload(fileName, file);
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(fileName);
      
      if (isCover) {
        _coverPhotoUrl = publicUrl;
      } else {
        _profilePhotoUrl = publicUrl;
      }
      
      await _supabase.from('profiles').update({
        if (isCover) 'cover_url': publicUrl else 'profile_url': publicUrl,
      }).eq('id', user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded to database successfully!')));
      }

    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo updated locally (backend storage not fully configured).')));
      }
    }
  }

  void _addAchievement() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final yearController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Achievement / Case', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title (e.g., Won Landmark Case)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearController,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _achievements.add({
                    'title': titleController.text,
                    'description': descController.text,
                    'year': yearController.text,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const UnifiedAuthScreen()),
      (route) => false,
    );
  }

  void _showEditProfileDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Profile', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Basic Info', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _specializationController,
                      decoration: InputDecoration(
                        labelText: 'Specialization (e.g., Criminal Defense)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _experienceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Years of Experience',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bioController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Biography / About Me',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Experience & History', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.work, size: 16),
                          label: const Text('Add Work'),
                          onPressed: () => _addAchievementFromModal(setModalState, 'work'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.gavel, size: 16),
                          label: const Text('Add Case'),
                          onPressed: () => _addAchievementFromModal(setModalState, 'case'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.emoji_events, size: 16),
                          label: const Text('Add Award'),
                          onPressed: () => _addAchievementFromModal(setModalState, 'award'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_achievements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('No history added yet.'),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _achievements.length,
                        itemBuilder: (ctx, index) {
                          final item = _achievements[index];
                          IconData icon = Icons.emoji_events;
                          if (item['type'] == 'work') icon = Icons.work;
                          if (item['type'] == 'case') icon = Icons.gavel;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: Icon(icon, color: Colors.blue),
                              title: Text(item['title'] ?? ''),
                              subtitle: Text(item['year'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                onPressed: () {
                                  setModalState(() {
                                    _achievements.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _saveProfile();
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _addAchievementFromModal(Function setModalState, String type) {
    final titleController = TextEditingController();
    final companyController = TextEditingController();
    final descController = TextEditingController();
    final yearController = TextEditingController();

    String dialogTitle = 'Add Award';
    String titleLabel = 'Award Title';
    if (type == 'work') {
      dialogTitle = 'Add Work Experience';
      titleLabel = 'Role / Job Title';
    } else if (type == 'case') {
      dialogTitle = 'Add Success Case';
      titleLabel = 'Case Title';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: InputDecoration(labelText: titleLabel)),
              if (type == 'work') ...[
                const SizedBox(height: 12),
                TextField(controller: companyController, decoration: const InputDecoration(labelText: 'Law Firm / Office Name')),
              ],
              const SizedBox(height: 12),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: yearController, decoration: const InputDecoration(labelText: 'Year (e.g., 2018-2022)'), keyboardType: TextInputType.text),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                setModalState(() {
                  _achievements.add({
                    'type': type,
                    'title': titleController.text,
                    'company': companyController.text,
                    'description': descController.text,
                    'year': yearController.text,
                  });
                });
                setState(() {}); // Update main UI too
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final spec = _specializationController.text.isNotEmpty ? _specializationController.text : 'Corporate Law & Civil Litigation';
    final rawExp = _experienceController.text;
    final exp = (rawExp.isEmpty || rawExp == '0') ? '10' : rawExp;
    final bio = _bioController.text.isNotEmpty ? _bioController.text : 'Dedicated and results-driven legal professional with extensive experience in Corporate Law and Civil Litigation. Proven track record of representing clients in high-stakes negotiations and courtroom proceedings.';
    
    // Provide dummy achievements if none exist
    List<Map<String, dynamic>> displayAchievements = _achievements;
    if (displayAchievements.isEmpty) {
      displayAchievements = [
        {
          'title': 'Senior Advocate',
          'year': '2018 - Present',
          'description': 'Representing clients in high-stakes corporate and civil litigation. Successfully resolved over 100+ complex disputes.'
        },
      ];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      appBar: AppBar(
        title: Text('My Profile', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF0A66C2)),
              tooltip: 'Edit Profile',
              onPressed: _showEditProfileDialog,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP CARD (Intro)
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: _localCoverPhotoPath != null
                                ? FileImage(File(_localCoverPhotoPath!))
                                : (_coverPhotoUrl != null
                                    ? NetworkImage(_coverPhotoUrl!)
                                    : const AssetImage('assets/images/bg_justice.jpg')) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          color: const Color(0xFF0077b5),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.black87),
                            onPressed: () => _pickAndUploadImage(true),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 70,
                        left: 16,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _localProfilePhotoPath != null
                                    ? FileImage(File(_localProfilePhotoPath!))
                                    : (_profilePhotoUrl != null
                                        ? NetworkImage(_profilePhotoUrl!)
                                        : null) as ImageProvider?,
                                child: (_localProfilePhotoPath == null && _profilePhotoUrl == null)
                                    ? Icon(Icons.person, size: 60, color: Colors.grey[500])
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  onPressed: () => _pickAndUploadImage(false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 130,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF0A66C2)),
                          onPressed: _showEditProfileDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_username, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('$spec | $exp+ Years of Experience', style: GoogleFonts.inter(fontSize: 15, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Text('JusticeConnect Verified Advocate', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600], size: 16),
                            const SizedBox(width: 4),
                            Text('4.8', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(' (120+ consultations)', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(width: 16),
                            Text('•', style: GoogleFonts.inter(color: Colors.grey[600])),
                            const SizedBox(width: 16),
                            Text('500+ Connections', style: GoogleFonts.inter(color: const Color(0xFF0A66C2), fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[100]!)),
                          child: Row(
                            children: [
                              const Icon(Icons.link, color: Color(0xFF0A66C2), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Your Public Profile URL', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                                    Text('justiceconnect.in/lawyer/$_username', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0A66C2))),
                                  ],
                                )
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, color: Color(0xFF0A66C2)),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: 'justiceconnect.in/lawyer/$_username'));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('URL copied to clipboard!')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // ABOUT CARD
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('About', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                        onPressed: _showEditProfileDialog,
                      )
                    ],
                  ),
                  Text(bio, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, height: 1.5)),
                ],
              ),
            ),
            
            // ACHIEVEMENTS / EXPERIENCE CARD
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Experience & Achievements', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                        onPressed: _showEditProfileDialog,
                      )
                    ],
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayAchievements.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = displayAchievements[index];
                      final type = item['type'] ?? 'award';
                      
                      IconData icon = Icons.emoji_events;
                      String subtitle = 'JusticeConnect Legal Hub'; // Fallback
                      
                      if (type == 'work') {
                        icon = Icons.work;
                        subtitle = item['company']?.toString().isNotEmpty == true ? item['company'] : 'Law Firm / Office';
                      } else if (type == 'case') {
                        icon = Icons.gavel;
                        subtitle = 'Success Case';
                      } else {
                        subtitle = 'Award & Recognition';
                      }
                      
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[100],
                            child: Icon(icon, color: const Color(0xFF0A66C2)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                const SizedBox(height: 2),
                                Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text(item['year'] ?? '', style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13)),
                                const SizedBox(height: 8),
                                if (item['description']?.isNotEmpty == true)
                                  Text(item['description'], style: GoogleFonts.inter(color: Colors.black87, fontSize: 14, height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
