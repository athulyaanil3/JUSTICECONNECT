import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/pattern_verification_service.dart';

import '../dashboard/admin_dashboard.dart';
import '../dashboard/citizen_dashboard.dart';
import '../dashboard/lawyer_dashboard.dart';
import '../dashboard/advocate_clerk_dashboard.dart';
import 'lawyer_verification_screen.dart';
import 'advocate_clerk_verification_screen.dart';
import 'pending_approval_screen.dart';
import 'forgot_password_screen.dart';
import '../../services/password_security_service.dart';
import '../../main.dart'; // To access supabase client

class UnifiedAuthScreen extends StatefulWidget {
  final String? initialRole;
  final String? initialEmail;

  const UnifiedAuthScreen({super.key, this.initialRole, this.initialEmail});

  @override
  State<UnifiedAuthScreen> createState() => _UnifiedAuthScreenState();
}

class _UnifiedAuthScreenState extends State<UnifiedAuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  bool _autoValidate = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedRole;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _selectedRole = (widget.initialRole != null && widget.initialRole != 'Administrator')
        ? widget.initialRole
        : 'Citizen';

    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
      _isLogin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully! Please log in with your new credentials.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }

    // Automatically navigate to Reset Password screen if user opened via recovery deep link
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _openForgotPassword(isDirectReset: true);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _autoValidate = false;
      if (!_isLogin && (_selectedRole == null || _selectedRole == 'Administrator')) {
        _selectedRole = 'Citizen';
      }
    });
    _formKey.currentState?.reset();
  }

  Future<void> _openForgotPassword({bool isDirectReset = false}) async {
    final resultEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
          isDirectPasswordReset: isDirectReset,
        ),
      ),
    );

    if (resultEmail != null && resultEmail.isNotEmpty && mounted) {
      setState(() {
        _isLogin = true;
        _emailController.text = resultEmail;
        _passwordController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully! Please log in with your new credentials.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    setState(() => _autoValidate = true);
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check and fill in the required fields.'),
          backgroundColor: Colors.orangeAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    try {
      if (_isLogin) {
        // === LOGIN FLOW: Role is determined automatically by the system ===

        // 1. Administrator check
        if (email.toLowerCase() == 'admin@justiceconnect.com') {
          final prefs = await SharedPreferences.getInstance();
          final currentAdminPass = prefs.getString('admin_password') ?? 'Admin@123';
          if (password == currentAdminPass) {
            await prefs.setBool('isAdminLoggedIn', true);
            // Synchronize Administrator credentials in Supabase
            await PasswordSecurityService.syncAdminPassword(
              email: email,
              password: password,
            );
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
              (route) => false,
            );
            return;
          } else {
            throw Exception('Invalid Administrator credentials. Please verify your email and password.');
          }
        }

        // 2. Pattern Verification Before Login
        if (!mounted) return;
        final isAuthenticated = await PatternVerificationService.authenticate(
          context: context,
          reason: 'Please enter your 4-digit security code to verify your identity before logging in.',
          userKey: email,
        );

        if (!isAuthenticated) {
          throw Exception('Security code verification failed or was cancelled.');
        }

        // 3. Supabase Auth Sign In
        final authRes = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        final user = authRes.user;
        if (user == null) {
          throw Exception('Authentication failed. Please verify your credentials.');
        }

        // 4. Resolve User Profile & Role from database
        final profileQuery = await supabase
            .from('profiles')
            .select('role, is_verified, username')
            .eq('id', user.id)
            .maybeSingle();

        final String? profileRole = profileQuery?['role']?.toString();
        final String? metaRole = user.userMetadata?['role']?.toString();
        final String actualRole = profileRole ?? metaRole ?? 'Citizen';
        final resolvedUsername = profileQuery?['username']?.toString() ??
            user.userMetadata?['username']?.toString() ??
            email.split('@')[0];

        // Auto-heal missing profile for Citizen
        if (profileQuery == null && actualRole == 'Citizen') {
          try {
            await supabase.from('profiles').insert({
              'id': user.id,
              'username': resolvedUsername,
              'email': email,
              'role': 'Citizen',
              'is_verified': true,
            });
          } catch (_) {}
        }

        // Store encrypted and decrypted password in Supabase for all roles
        await PasswordSecurityService.syncPassword(
          userId: user.id,
          email: email,
          password: password,
          role: actualRole,
          username: resolvedUsername,
        );

        await _navigateForRole(
          role: actualRole,
          isVerified: profileQuery?['is_verified'] as bool?,
          hasProfile: profileQuery != null,
          isSignup: false,
        );
      } else {
        // === SIGN UP FLOW: User registers with their selected role ===
        final roleToRegister = _selectedRole ?? 'Citizen';

        if (email.toLowerCase() == 'admin@justiceconnect.com') {
          throw Exception(
            'This email address is reserved for system administration. Please log in instead.',
          );
        }

        // Pre-check if email already registered
        try {
          final existingProfile = await supabase
              .from('profiles')
              .select('role')
              .ilike('email', email)
              .maybeSingle();

          if (existingProfile != null && existingProfile['role'] != null) {
            throw Exception(
              'An account with this email already exists. Please log in instead.',
            );
          }
        } catch (e) {
          if (e.toString().contains('already exists')) {
            rethrow;
          }
        }

        // Security Code Registration Before Signup
        if (!mounted) return;
        final isRegistered = await PatternVerificationService.register(
          context: context,
          reason: 'Please enter a 4-digit security code to register it to your account.',
          userKey: email,
        );

        if (!isRegistered) {
          throw Exception('Security code registration was cancelled. Cannot create account.');
        }

        // Sign Up with Supabase
        final authRes = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'username': username, 'role': roleToRegister},
        );

        if (authRes.user != null) {
          if (roleToRegister == 'Citizen') {
            try {
              await supabase.from('profiles').insert({
                'id': authRes.user!.id,
                'username': username,
                'email': email,
                'role': 'Citizen',
                'is_verified': true,
              });
            } catch (_) {}
          }

          // Store encrypted and decrypted password in Supabase for the new account
          await PasswordSecurityService.syncPassword(
            userId: authRes.user!.id,
            email: email,
            password: password,
            role: roleToRegister,
            username: username,
          );
        }

        await _navigateForRole(
          role: roleToRegister,
          isVerified: roleToRegister == 'Citizen' ? true : false,
          hasProfile: roleToRegister == 'Citizen',
          isSignup: true,
        );
      }
    } on AuthException catch (e) {
      String message = e.message;
      if (_isLogin &&
          (message.toLowerCase().contains('invalid') ||
              message.toLowerCase().contains('credentials'))) {
        message = 'Invalid email or password. Please verify your credentials or Sign Up.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isNotEmpty ? msg : 'An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateForRole({
    required String role,
    bool? isVerified,
    bool hasProfile = true,
    bool isSignup = false,
  }) async {
    if (!mounted) return;

    if (role == 'Administrator') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdminLoggedIn', true);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
        (route) => false,
      );
      return;
    }

    if (role == 'Citizen') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CitizenDashboard()),
        (route) => false,
      );
      return;
    }

    if (role == 'Lawyer') {
      if (isSignup || !hasProfile) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LawyerVerificationScreen()),
          (route) => false,
        );
        return;
      }

      if (isVerified == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LawyerDashboard()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              isRejected: isVerified == false,
              role: 'Lawyer',
            ),
          ),
          (route) => false,
        );
      }
      return;
    }

    if (role == 'Advocate Clerk') {
      if (isSignup || !hasProfile) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdvocateClerkVerificationScreen()),
          (route) => false,
        );
        return;
      }

      if (isVerified == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdvocateClerkDashboard()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PendingApprovalScreen(
              isRejected: isVerified == false,
              role: 'Advocate Clerk',
            ),
          ),
          (route) => false,
        );
      }
      return;
    }

    // Default Fallback to Citizen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CitizenDashboard()),
      (route) => false,
    );
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
            color: Colors.black.withValues(alpha: 0.5),
            colorBlendMode: BlendMode.darken,
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autoValidate
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
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
                              _isLogin
                                  ? 'Login to continue'
                                  : 'Sign up to continue',
                              style: GoogleFonts.inter(color: Colors.white70),
                            ),
                            const SizedBox(height: 28),

                            // Role Selection Dropdown (ONLY shown on Sign Up, NOT on Login)
                            if (!_isLogin) ...[
                              _buildRoleDropdown(),
                              const SizedBox(height: 16),
                            ],

                            // Username Field (Only for Signup)
                            if (!_isLogin) ...[
                              _buildTextField(
                                controller: _usernameController,
                                label: 'Username',
                                icon: Icons.person,
                                textInputAction: TextInputAction.next,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your email address';
                                }
                                final trimmed = val.trim();
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                );
                                if (!emailRegex.hasMatch(trimmed)) {
                                  return 'Please enter a valid email (e.g. name@example.com)';
                                }
                                if (!_isLogin && trimmed.toLowerCase() == 'admin@justiceconnect.com') {
                                  return 'This email is reserved for system administration';
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
                              textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                              onFieldSubmitted: _isLogin ? (_) => _submitForm() : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
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
                                  return 'Please enter your password';
                                }
                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            // Confirm Password Field (Only for Signup)
                            if (!_isLogin) ...[
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submitForm(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (val != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            // Forgot Password Button (Only for Login)
                            if (_isLogin)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _openForgotPassword,
                                  child: Text(
                                    'Forgot Password?',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.black,
                                      )
                                    : Text(
                                        _isLogin ? 'Login' : 'Sign Up',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Toggle Mode
                            TextButton(
                              onPressed: _toggleAuthMode,
                              child: Text(
                                _isLogin
                                    ? "Don't have an account? Sign Up"
                                    : "Already have an account? Login",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
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

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white),
      validator: (val) {
        if (!_isLogin && (val == null || val.trim().isEmpty)) {
          return 'Please select your role';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Select Role',
        labelStyle: const TextStyle(
          color: Colors.white70,
        ),
        prefixIcon: const Icon(
          Icons.badge,
          color: Colors.white70,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        errorStyle: const TextStyle(
          color: Color(0xFFFF8A80),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.white,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'Citizen', child: Text('Citizen')),
        DropdownMenuItem(value: 'Lawyer', child: Text('Lawyer')),
        DropdownMenuItem(value: 'Advocate Clerk', child: Text('Advocate Clerk')),
      ],
      onChanged: (val) {
        setState(() {
          _selectedRole = val;
        });
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        errorStyle: const TextStyle(
          color: Color(0xFFFF8A80),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
        ),
      ),
    );
  }
}
