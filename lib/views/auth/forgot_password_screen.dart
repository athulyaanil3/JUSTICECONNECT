import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/pattern_verification_service.dart';
import '../../services/password_security_service.dart';
import '../../main.dart'; // To access supabase client
import 'unified_auth_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final bool isDirectPasswordReset;

  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.isDirectPasswordReset = false,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 0: Enter Email & Request OTP
  // Step 1: Enter & Verify OTP
  // Step 2: Enter & Confirm New Password
  int _currentStep = 0;

  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _stepError;
  String? _stepSuccess;

  // OTP Resend Countdown
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  // Listen for Supabase recovery link clicks
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }

    if (widget.isDirectPasswordReset) {
      _currentStep = 2;
      _stepSuccess = 'Verified via email link! Please enter your new password.';
    }

    // Intercept recovery auth events if user clicked link in email
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.signedIn) {
        if (mounted && _currentStep < 2) {
          setState(() {
            _currentStep = 2; // Move straight to New Password
            _stepError = null;
            _stepSuccess = 'Verified via email link! You can now set your new password.';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer([int seconds = 60]) {
    _resendCountdown = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  // --- Step 1: Send OTP to Email ---
  Future<void> _sendOtp({bool isResend = false}) async {
    if (!isResend && !_emailFormKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      if (isResend) {
        _isResending = true;
      } else {
        _isLoading = true;
      }
      _stepError = null;
      _stepSuccess = null;
    });

    try {
      // 1. Special handling for hardcoded Administrator account
      if (email == 'admin@justiceconnect.com') {
        final isAuth = await PatternVerificationService.authenticate(
          context: context,
          reason: 'Enter your 4-digit security code to reset administrator password.',
          userKey: email,
        );
        if (isAuth) {
          if (mounted) {
            setState(() {
              _currentStep = 2;
              _stepSuccess = 'Security code verified! Enter new administrator password.';
            });
          }
          return;
        } else {
          if (mounted) {
            setState(() {
              _stepError = 'Security code verification was cancelled.';
            });
          }
          return;
        }
      }

      // 2. Validate user account exists in profiles database before dispatching OTP
      final profile = await supabase
          .from('profiles')
          .select('id, email, username')
          .ilike('email', email)
          .maybeSingle();

      if (profile == null) {
        if (mounted) {
          setState(() {
            _stepError = 'No registered account found with email "$email".\nPlease verify your email address or sign up.';
          });
        }
        return;
      }

      // 3. Request OTP code using Supabase Password Reset template
      try {
        await supabase.auth.resetPasswordForEmail(
          email,
        );
      } on AuthException catch (e) {
        if (e.message.toLowerCase().contains('rate limit') ||
            e.message.toLowerCase().contains('seconds')) {
          rethrow;
        }
        debugPrint('resetPasswordForEmail error: ${e.message}. Trying signInWithOtp fallback...');
        await supabase.auth.signInWithOtp(
          email: email,
          shouldCreateUser: false,
        );
      }

      _startResendTimer(60);
      if (mounted) {
        setState(() {
          _currentStep = 1; // Move to OTP verification step
          _stepSuccess = isResend
              ? 'A fresh OTP code has been sent to $email.'
              : 'An OTP code has been sent to $email.';
          if (isResend) {
            _otpController.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isResend
                  ? 'A fresh OTP was sent to $email. Please check your inbox or spam!'
                  : 'OTP sent! Please check your inbox or spam folder.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on AuthException catch (e) {
      // Handle Supabase email rate limit (e.g. "For security purposes, you can only request this after 51 seconds.")
      int waitSeconds = 60;
      final match = RegExp(r'(\d+)\s*seconds?').firstMatch(e.message);
      if (match != null) {
        waitSeconds = int.tryParse(match.group(1) ?? '60') ?? 60;
      }
      _startResendTimer(waitSeconds);

      if (mounted) {
        setState(() {
          _stepError = 'Request limit reached. Please wait ${waitSeconds}s before requesting a new code.\n(${e.message})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stepError = 'Failed to send OTP: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isResending = false;
        });
      }
    }
  }

  // --- Step 2: Verify OTP ---
  Future<void> _verifyOtp() async {
    final rawOtp = _otpController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final email = _emailController.text.trim().toLowerCase();

    if (rawOtp.isEmpty) {
      setState(() => _stepError = 'Please enter your OTP verification code.');
      return;
    }

    if (rawOtp.length < 6 || rawOtp.length > 8) {
      setState(() => _stepError = 'OTP must be 6 to 8 digits (entered ${rawOtp.length} digits).');
      return;
    }

    setState(() {
      _isLoading = true;
      _stepError = null;
      _stepSuccess = null;
    });

    try {
      AuthResponse? res;
      // 1. Try OTP verification with OtpType.recovery (from resetPasswordForEmail)
      try {
        res = await supabase.auth.verifyOTP(
          type: OtpType.recovery,
          email: email,
          token: rawOtp,
        );
      } catch (e1) {
        debugPrint('OtpType.recovery failed: $e1. Trying OtpType.email fallback...');
        try {
          // 2. Fallback: Try OTP verification with OtpType.email (from signInWithOtp)
          res = await supabase.auth.verifyOTP(
            type: OtpType.email,
            email: email,
            token: rawOtp,
          );
        } catch (e2) {
          debugPrint('OtpType.email failed: $e2');
          rethrow;
        }
      }

      if (res.session != null || res.user != null) {
        // OTP matches! Transition to the next screen (New Password)
        if (mounted) {
          setState(() {
            _currentStep = 2; // Advance to Step 3: Enter New Password
            _stepError = null;
            _stepSuccess = 'OTP verified successfully! Please enter your new password.';
          });
        }
      } else {
        setState(() {
          _stepError = 'Verification failed. Please check the code and try again.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        if (e.code == 'otp_expired' ||
            e.message.toLowerCase().contains('expired') ||
            e.message.toLowerCase().contains('invalid')) {
          _stepError =
              'The OTP code is invalid or has expired.\n• Check your latest email for the newest OTP code.\n• Older codes or clicked links become invalid.';
        } else {
          _stepError = e.message;
        }
      });
    } catch (e) {
      setState(() {
        _stepError = 'Error verifying OTP: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Step 3: Update Password ---
  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    if (newPassword.length < 6) {
      setState(() => _stepError = 'Password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _stepError = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _stepError = null;
      _stepSuccess = null;
    });

    try {
      // 1. Administrator account password update
      if (email == 'admin@justiceconnect.com') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_password', newPassword);
        await PasswordSecurityService.syncAdminPassword(
          email: email,
          password: newPassword,
        );
        if (mounted) {
          _showSuccessDialog();
        }
        return;
      }

      // 2. Standard Supabase user password update for authenticated recovery/OTP session
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 2b. Sync encrypted & decrypted password in Supabase profiles
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await PasswordSecurityService.syncPassword(
          userId: currentUser.id,
          email: email,
          password: newPassword,
        );
      } else {
        // Fallback: look up user by email to sync credentials
        try {
          final p = await supabase.from('profiles').select('id, role, username').ilike('email', email).maybeSingle();
          if (p != null) {
            await PasswordSecurityService.syncPassword(
              userId: p['id'].toString(),
              email: email,
              password: newPassword,
              role: p['role']?.toString(),
              username: p['username']?.toString(),
            );
          }
        } catch (_) {}
      }

      // 3. Sign out recovery session cleanly so user logs in afresh
      await supabase.auth.signOut();

      if (mounted) {
        _showSuccessDialog();
      }
    } on AuthException catch (e) {
      setState(() {
        _stepError = e.message;
      });
    } catch (e) {
      setState(() {
        _stepError = 'Failed to reset password: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(
              'Password Reset!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          'Your password has been successfully updated. You can now log in with your new credentials.',
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade800),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => UnifiedAuthScreen(
                    initialEmail: _emailController.text.trim(),
                  ),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Back to Login',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentStep > 0 && _currentStep < 2) {
          setState(() {
            _currentStep--;
            _stepError = null;
            _stepSuccess = null;
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
          // Background Image
          Image.asset(
            'assets/images/bg_justice.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.55),
            colorBlendMode: BlendMode.darken,
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                        onPressed: () {
                          if (_currentStep > 0 && _currentStep < 2) {
                            setState(() {
                              _currentStep--;
                              _stepError = null;
                              _stepSuccess = null;
                            });
                          } else {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const UnifiedAuthScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Forgot Password',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Step Progress Indicator
                _buildStepIndicator(),

                // Scrollable Content Card (responsive to keyboard)
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _buildCurrentStepContent(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // --- Step Indicator Widget ---
  Widget _buildStepIndicator() {
    final steps = ['Email', 'Verify OTP', 'New Password'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isPassed = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 3,
                color: isPassed ? const Color(0xFFD4AF37) : Colors.white24,
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isActive
                          ? const Color(0xFFD4AF37)
                          : Colors.white24,
                  border: Border.all(
                    color: isActive ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: isActive ? Colors.black : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? Colors.white : Colors.white60,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // --- Main Switcher for Current Step ---
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Email();
      case 1:
        return _buildStep2Otp();
      case 2:
        return _buildStep3NewPassword();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Step 1: Email Form ---
  Widget _buildStep1Email() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('step1'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mail_lock, color: Color(0xFFD4AF37), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset Password',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Receive an OTP on your email',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Enter your registered email address. We will send an OTP verification code to verify your identity.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),

          _buildAlertBoxes(),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Registered Email Address',
              icon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your registered email';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _sendOtp(isResend: false),
              style: _elevatedButtonStyle(),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP Code',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedAuthScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
              label: Text(
                'Back to Login',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: OTP Verification Form ---
  Widget _buildStep2Otp() {
    final email = _emailController.text.trim();
    return Column(
      key: const ValueKey('step2'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.mark_email_read_outlined, color: Color(0xFFD4AF37), size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter OTP Code',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Verify the code sent to your email',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Email address chip with edit button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.email, color: Color(0xFFD4AF37), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  email,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _currentStep = 0;
                    _stepError = null;
                    _stepSuccess = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'Change',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Delivery Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check your inbox or spam folder for the OTP verification code sent to your email.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildAlertBoxes(),

        Text(
          'Please enter the OTP code received in your inbox or spam folder:',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 12),

        // OTP Input Field with Paste helper & robust input filtering
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 6,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '• • • • • • • •',
            hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 4),
            prefixIcon: const Icon(Icons.pin, color: Colors.white70),
            suffixIcon: IconButton(
              tooltip: 'Paste OTP',
              icon: const Icon(Icons.content_paste, color: Color(0xFFD4AF37)),
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) {
                  final digits = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.isNotEmpty) {
                    final code = digits.length > 8 ? digits.substring(0, 8) : digits;
                    _otpController.text = code;
                    setState(() => _stepError = null);
                  }
                }
              },
            ),
            filled: true,
            fillColor: Colors.black.withOpacity(0.25),
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
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
          ),
          onTap: () {
            if (_stepError != null) {
              setState(() => _stepError = null);
            }
          },
          onChanged: (val) {
            if (_stepError != null) {
              setState(() => _stepError = null);
            }
          },
        ),
        const SizedBox(height: 14),

        // Resend Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Didn't receive code?",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
            if (_isResending)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sending...',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFFD4AF37),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (_resendCountdown > 0)
              Text(
                'Resend in ${_resendCountdown}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              TextButton(
                onPressed: _isLoading || _isResending ? null : () => _sendOtp(isResend: true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(60, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Resend OTP',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD4AF37),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: _elevatedButtonStyle(),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify OTP',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_outline, size: 18),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const UnifiedAuthScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
            label: Text(
              'Back to Login',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 3: Set New Password Form ---
  Widget _buildStep3NewPassword() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('step3'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_reset, color: Color(0xFFD4AF37), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Password',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Enter your new credentials',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your identity has been verified. Choose a secure new password for your account.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),

          _buildAlertBoxes(),

          // New Password Field
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'New Password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter a new password';
              }
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password Field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(
              label: 'Confirm New Password',
              icon: Icons.lock,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your new password';
              }
              if (val != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Real-time Validation Checks
          _buildPasswordValidationChecks(),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              style: _elevatedButtonStyle(),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Update & Reset Password',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const UnifiedAuthScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
              label: Text(
                'Back to Login',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Real-time Password Rules Checklist ---
  Widget _buildPasswordValidationChecks() {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    final hasMinLength = password.length >= 6;
    final passwordsMatch = password.isNotEmpty && password == confirm;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _checkItem('At least 6 characters long', hasMinLength),
          const SizedBox(height: 6),
          _checkItem('Passwords match exactly', passwordsMatch),
        ],
      ),
    );
  }

  Widget _checkItem(String title, bool isSatisfied) {
    return Row(
      children: [
        Icon(
          isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isSatisfied ? Colors.greenAccent : Colors.white38,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isSatisfied ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }

  // --- Helpers for Styling ---
  Widget _buildAlertBoxes() {
    if (_stepError == null && _stepSuccess == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        if (_stepError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _stepError!,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12, height: 1.3),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _stepError = null),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_stepSuccess != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade900.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _stepSuccess!,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
    );
  }

  ButtonStyle _elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD4AF37), // Metallic gold accent
      foregroundColor: Colors.black,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
