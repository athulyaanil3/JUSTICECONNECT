import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard/admin_dashboard.dart';
import '../dashboard/citizen_dashboard.dart';
import '../dashboard/lawyer_dashboard.dart';
import '../dashboard/advocate_clerk_dashboard.dart';
import 'lawyer_verification_screen.dart';
import 'advocate_clerk_verification_screen.dart';
import 'pending_approval_screen.dart';
import '../../main.dart'; // To access supabase client

class UnifiedAuthScreen extends StatefulWidget {
  final String? initialRole;

  const UnifiedAuthScreen({Key? key, this.initialRole}) : super(key: key);

  @override
  _UnifiedAuthScreenState createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'Citizen';
    if (_selectedRole == 'Administrator') {
      _isLogin = true;
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();
    
    try {
      // 1. Hardcoded Admin Check
      if (_selectedRole == 'Administrator') {
        if (email == 'admin@justiceconnect.com' && password == 'Admin@123') {
          // Success Admin Login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isAdminLoggedIn', true);
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AdminDashboard()), (route) => false);
          return;
        } else {
          throw Exception('Invalid Administrator credentials.');
        }
      }

      // 2. Supabase Auth for other roles
      if (_isLogin) {
        // Sign In
        final authRes = await supabase.auth.signInWithPassword(email: email, password: password);
        
        // Auto-repair missing profiles for old Citizen accounts
        if (authRes.user != null) {
          final profileQuery = await supabase.from('profiles').select().eq('id', authRes.user!.id).maybeSingle();
          if (profileQuery == null) {
            final meta = authRes.user!.userMetadata;
            if (meta != null && meta['role'] == 'Citizen') {
              await supabase.from('profiles').insert({
                'id': authRes.user!.id,
                'username': meta['username'] ?? email.split('@')[0],
                'email': email,
                'role': 'Citizen',
                'is_verified': true,
              });
            }
          }
        }
        
        await _navigateBasedOnRole(isSignup: false);
      } else {
        // Sign Up
        final authRes = await supabase.auth.signUp(
          email: email, 
          password: password,
          data: {'username': username, 'role': _selectedRole},
        );
        
        if (authRes.user != null && _selectedRole == 'Citizen') {
          // Explicitly create profile for Citizen since they don't have a verification screen
          await supabase.from('profiles').insert({
            'id': authRes.user!.id,
            'username': username,
            'email': email,
            'role': 'Citizen',
            'is_verified': true,
          });
        }
        
        await _navigateBasedOnRole(isSignup: true);
      }
      
    } on AuthException catch (e) {
      String message = e.message;
      if (_isLogin && (message.toLowerCase().contains('invalid') || message.toLowerCase().contains('credentials'))) {
        message = 'Invalid credentials or you don\'t have an account. Please Sign Up.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An unexpected error occurred.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateBasedOnRole({required bool isSignup}) async {
    if (_selectedRole == 'Citizen') {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const CitizenDashboard()), (route) => false);
    } else if (_selectedRole == 'Lawyer' || _selectedRole == 'Advocate Clerk') {
      if (isSignup) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => _selectedRole == 'Lawyer' ? const LawyerVerificationScreen() : const AdvocateClerkVerificationScreen()),
          (route) => false
        );
      } else {
        // Check verification status and profile existence
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            final dataList = await supabase
                .from('profiles')
                .select('is_verified, role')
                .eq('id', user.id);
            
            if (dataList.isEmpty) {
              // User exists in auth but no profile/verification details yet
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => _selectedRole == 'Lawyer' ? const LawyerVerificationScreen() : const AdvocateClerkVerificationScreen()),
                (route) => false
              );
              return;
            }

            final data = dataList.first;
            
            if (data['role'] != _selectedRole) {
              // Signed in with wrong role
              await supabase.auth.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This account is registered as a ${data['role']}, not a $_selectedRole.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
              return;
            }

            if (data['is_verified'] == true) {
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => _selectedRole == 'Lawyer' ? const LawyerDashboard() : const AdvocateClerkDashboard()),
                (route) => false
              );
            } else {
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => PendingApprovalScreen(isRejected: data['is_verified'] == false)),
                (route) => false
              );
            }
          }
        } catch (e) {
          debugPrint('Error checking verification status: $e');
          // Default to pending on error just to be safe
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PendingApprovalScreen()), (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/bg_justice.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5),
            colorBlendMode: BlendMode.darken,
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'JusticeConnect',
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin ? 'Login to continue' : 'Sign up to continue',
                              style: GoogleFonts.inter(color: Colors.white70),
                            ),
                            const SizedBox(height: 32),
                            
                            // Role Selection Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              dropdownColor: Colors.grey[900],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Select Role',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.badge, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.2),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.white),
                                ),
                              ),
                              items: ['Citizen', 'Lawyer', 'Advocate Clerk', 'Administrator']
                                  .map((role) => DropdownMenuItem(
                                        value: role,
                                        child: Text(role),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedRole = val;
                                  if (val == 'Administrator') {
                                    _isLogin = true; // Admin doesn't have signup
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Username Field (Only for Signup, unless Admin which doesn't signup)
                            if (!_isLogin && _selectedRole != 'Administrator') ...[
                              _buildTextField(
                                controller: _usernameController,
                                label: 'Username',
                                icon: Icons.person,
                                validator: (val) => val!.isEmpty ? 'Enter a username' : null,
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Enter your email address';
                                }
                                // Basic email regex
                                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                if (!emailRegex.hasMatch(val)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Enter your password';
                                }
                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading 
                                  ? const CircularProgressIndicator(color: Colors.black)
                                  : Text(
                                      _isLogin ? 'Login' : 'Sign Up',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Toggle Mode (Hide for Admin as Admin is hardcoded Login only)
                            if (_selectedRole != 'Administrator')
                              TextButton(
                                onPressed: _toggleAuthMode,
                                child: Text(
                                  _isLogin 
                                    ? "Don't have an account? Sign Up" 
                                    : "Already have an account? Login",
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}

