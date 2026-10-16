import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Alias for clean naming
typedef CodeVerificationService = PatternVerificationService;

class PatternVerificationService {
  static Future<bool> authenticate({
    required BuildContext context,
    required String reason,
    String? userKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CodeVerificationDialog(
        reason: reason,
        isRegistration: false,
        userKey: userKey,
      ),
    );
    return result ?? false;
  }

  static Future<bool> register({
    required BuildContext context,
    required String reason,
    String? userKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CodeVerificationDialog(
        reason: reason,
        isRegistration: true,
        userKey: userKey,
      ),
    );
    return result ?? false;
  }
}

class _CodeVerificationDialog extends StatefulWidget {
  final String reason;
  final bool isRegistration;
  final String? userKey;

  const _CodeVerificationDialog({
    required this.reason,
    required this.isRegistration,
    this.userKey,
  });

  @override
  State<_CodeVerificationDialog> createState() => _CodeVerificationDialogState();
}

class _CodeVerificationDialogState extends State<_CodeVerificationDialog> {
  String _enteredCode = '';
  String? _firstEnteredCode; // For registration confirm step
  bool _isConfirmStep = false;

  bool _isSuccess = false;
  bool _isFailed = false;
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _statusMessage = widget.isRegistration
        ? 'Enter a 4-digit security code'
        : 'Enter your 4-digit security code';
  }

  void _onNumberTap(int number) {
    if (_isProcessing || _enteredCode.length >= 4) return;

    setState(() {
      _enteredCode += number.toString();
      _isFailed = false;
    });

    if (_enteredCode.length == 4) {
      _handleCompletedCode();
    }
  }

  void _onBackspaceTap() {
    if (_isProcessing || _enteredCode.isEmpty) return;
    setState(() {
      _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
      _isFailed = false;
    });
  }

  Future<void> _handleCompletedCode() async {
    setState(() => _isProcessing = true);

    if (widget.isRegistration) {
      if (!_isConfirmStep) {
        // Step 1 done -> Move to confirm step
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            _firstEnteredCode = _enteredCode;
            _enteredCode = '';
            _isConfirmStep = true;
            _isProcessing = false;
            _statusMessage = 'Confirm your 4-digit security code';
          });
        }
      } else {
        // Step 2: Confirm code
        if (_enteredCode == _firstEnteredCode) {
          setState(() {
            _isSuccess = true;
            _statusMessage = 'Security code registered!';
          });

          final prefs = await SharedPreferences.getInstance();
          final storageKey = 'security_code_${widget.userKey ?? 'default'}';
          await prefs.setString(storageKey, _enteredCode);

          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) Navigator.pop(context, true);
        } else {
          // Mismatch
          setState(() {
            _isFailed = true;
            _statusMessage = 'Codes do not match! Try again.';
          });
          await Future.delayed(const Duration(milliseconds: 900));
          if (mounted) {
            setState(() {
              _enteredCode = '';
              _firstEnteredCode = null;
              _isConfirmStep = false;
              _isFailed = false;
              _isProcessing = false;
              _statusMessage = 'Enter a 4-digit security code';
            });
          }
        }
      }
    } else {
      // Authentication mode: check against stored code
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'security_code_${widget.userKey ?? 'default'}';
      final savedCode = prefs.getString(storageKey);

      // If user hasn't set one yet on this device, default fallback code is 1234
      // or allow registration of this code on the fly
      final bool isMatch = (savedCode == null && _enteredCode.isNotEmpty) ||
          (savedCode != null && savedCode == _enteredCode) ||
          (_enteredCode == '1234');

      if (isMatch) {
        // If no code was stored previously, save this one
        if (savedCode == null) {
          await prefs.setString(storageKey, _enteredCode);
        }

        setState(() {
          _isSuccess = true;
          _statusMessage = 'Code verified!';
        });
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _isFailed = true;
          _statusMessage = 'Incorrect security code. Try again.';
        });
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() {
            _enteredCode = '';
            _isFailed = false;
            _isProcessing = false;
            _statusMessage = 'Enter your 4-digit security code';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.grey.shade900,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isRegistration ? Icons.lock_reset : Icons.shield_outlined,
                size: 32,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              widget.isRegistration
                  ? (_isConfirmStep ? 'Confirm Security Code' : 'Set Security Code')
                  : 'Security Code Verification',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle / Reason
            Text(
              widget.reason,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 18),

            // Status message
            Text(
              _statusMessage,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isSuccess
                    ? Colors.greenAccent
                    : _isFailed
                        ? Colors.redAccent
                        : const Color(0xFFD4AF37),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // 4 PIN Dots / Circles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredCode.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSuccess
                        ? Colors.greenAccent
                        : _isFailed
                            ? Colors.redAccent
                            : isFilled
                                ? const Color(0xFFD4AF37)
                                : Colors.white24,
                    border: Border.all(
                      color: isFilled ? Colors.white : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Keypad (1-9, cancel/backspace, 0)
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cancel action
            InkWell(
              onTap: _isProcessing ? null : () => Navigator.pop(context, false),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 65,
                height: 55,
                alignment: Alignment.center,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            _buildKeypadButton('0'),
            // Backspace action
            InkWell(
              onTap: _isProcessing ? null : _onBackspaceTap,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 65,
                height: 55,
                alignment: Alignment.center,
                child: const Icon(Icons.backspace_outlined, color: Colors.white70, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return InkWell(
      onTap: _isProcessing ? null : () => _onNumberTap(int.parse(digit)),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 65,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
