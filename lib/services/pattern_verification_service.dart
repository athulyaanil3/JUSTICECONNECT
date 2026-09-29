import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class PatternVerificationService {
  static Future<bool> authenticate({
    required BuildContext context,
    required String reason,
    String? userKey,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PatternVerificationDialog(reason: reason, isRegistration: false, userKey: userKey),
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
      builder: (ctx) => _PatternVerificationDialog(reason: reason, isRegistration: true, userKey: userKey),
    );
    return result ?? false;
  }
}

class _PatternVerificationDialog extends StatefulWidget {
  final String reason;
  final bool isRegistration;
  final String? userKey;
  
  const _PatternVerificationDialog({required this.reason, required this.isRegistration, this.userKey});

  @override
  State<_PatternVerificationDialog> createState() => _PatternVerificationDialogState();
}

class _PatternVerificationDialogState extends State<_PatternVerificationDialog> {
  final List<int> _pattern = [];
  Offset? _currentPoint;
  bool _isSuccess = false;
  bool _isFailed = false;
  bool _isProcessing = false;
  String _message = 'Draw your pattern';
  
  // For testing: allow any pattern with at least 4 dots to pass.
  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isProcessing) return;
    setState(() {
      _pattern.clear();
      _isFailed = false;
      _isSuccess = false;
      _message = 'Release to verify';
    });
    _updatePattern(details.localPosition, constraints);
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isProcessing) return;
    _updatePattern(details.localPosition, constraints);
  }

  void _onPanEnd(DragEndDetails details) async {
    if (_isProcessing) return;
    setState(() {
      _currentPoint = null;
    });
    
    if (_pattern.isEmpty) {
      setState(() {
         _message = 'Draw your pattern';
      });
      return;
    }

    if (widget.isRegistration) {
      if (_pattern.length < 4) {
        setState(() {
          _isProcessing = true;
          _isFailed = true;
          _message = 'Connect at least 4 dots';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _pattern.clear();
            _isFailed = false;
            _isProcessing = false;
            _message = 'Draw your pattern';
          });
        }
        return;
      }

      setState(() {
        _isProcessing = true;
        _isSuccess = true;
        _message = 'Pattern registered!';
      });
      
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'device_pattern_${widget.userKey ?? 'default'}';
      await prefs.setString(storageKey, _pattern.join(','));
      
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } else {
      // Verification logic: compare against securely stored pattern.
      final prefs = await SharedPreferences.getInstance();
      final storageKey = 'device_pattern_${widget.userKey ?? 'default'}';
      final savedPatternStr = prefs.getString(storageKey);
      
      List<int> savedPattern = [0, 1, 2, 5, 8]; // default fallback
      if (savedPatternStr != null && savedPatternStr.isNotEmpty) {
        savedPattern = savedPatternStr.split(',').map((e) => int.parse(e)).toList();
      }
      
      bool isMatch = true;
      if (_pattern.length != savedPattern.length) {
        isMatch = false;
      } else {
        for (int i = 0; i < _pattern.length; i++) {
          if (_pattern[i] != savedPattern[i]) {
            isMatch = false;
            break;
          }
        }
      }
      
      setState(() {
        _isProcessing = true;
        _isSuccess = isMatch;
        _isFailed = !isMatch;
        _message = isMatch ? 'Pattern verified!' : 'Pattern Mismatch!';
      });
      
      if (isMatch) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context, true);
      } else {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          setState(() {
            _pattern.clear();
            _isFailed = false;
            _isProcessing = false;
            _message = 'Draw your pattern';
          });
        }
      }
    }
  }

  void _updatePattern(Offset localPosition, BoxConstraints constraints) {
    final size = min(constraints.maxWidth, constraints.maxHeight);
    final padding = size * 0.1;
    final dotSpacing = (size - 2 * padding) / 2;
    
    setState(() {
      _currentPoint = localPosition;
    });

    for (int i = 0; i < 9; i++) {
      int row = i ~/ 3;
      int col = i % 3;
      
      double dotX = padding + col * dotSpacing;
      double dotY = padding + row * dotSpacing;
      
      final dist = (Offset(dotX, dotY) - localPosition).distance;
      if (dist < dotSpacing * 0.4 && !_pattern.contains(i)) {
        setState(() {
          _pattern.add(i);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.isRegistration ? Icons.pattern : Icons.grid_3x3, size: 40, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              widget.isRegistration ? 'Register Pattern' : 'Pattern Verification',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.reason,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 250,
              height: 250,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanStart: (details) => _onPanStart(details, constraints),
                    onPanUpdate: (details) => _onPanUpdate(details, constraints),
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: _PatternPainter(
                        pattern: _pattern,
                        currentPoint: _currentPoint,
                        isSuccess: _isSuccess,
                        isFailed: _isFailed,
                      ),
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isSuccess ? Colors.green : (_isFailed ? Colors.red : Colors.blue),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Offset? currentPoint;
  final bool isSuccess;
  final bool isFailed;

  _PatternPainter({
    required this.pattern,
    required this.currentPoint,
    required this.isSuccess,
    required this.isFailed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = size.width * 0.1;
    final dotSpacing = (size.width - 2 * padding) / 2;
    
    Color lineColor = Colors.blue;
    if (isSuccess) lineColor = Colors.green;
    if (isFailed) lineColor = Colors.red;

    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.5)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    // Draw lines between dots
    for (int i = 0; i < pattern.length - 1; i++) {
      int startIdx = pattern[i];
      int endIdx = pattern[i + 1];
      
      Offset startPos = Offset(
        padding + (startIdx % 3) * dotSpacing,
        padding + (startIdx ~/ 3) * dotSpacing,
      );
      
      Offset endPos = Offset(
        padding + (endIdx % 3) * dotSpacing,
        padding + (endIdx ~/ 3) * dotSpacing,
      );
      
      canvas.drawLine(startPos, endPos, linePaint);
    }

    // Draw line to current point
    if (pattern.isNotEmpty && currentPoint != null && !isSuccess && !isFailed) {
      int lastIdx = pattern.last;
      Offset lastPos = Offset(
        padding + (lastIdx % 3) * dotSpacing,
        padding + (lastIdx ~/ 3) * dotSpacing,
      );
      canvas.drawLine(lastPos, currentPoint!, linePaint);
    }

    // Draw dots
    for (int i = 0; i < 9; i++) {
      int row = i ~/ 3;
      int col = i % 3;
      
      double dotX = padding + col * dotSpacing;
      double dotY = padding + row * dotSpacing;
      
      bool isSelected = pattern.contains(i);
      
      final dotPaint = Paint()
        ..color = isSelected ? lineColor : Colors.grey.withOpacity(0.5)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(Offset(dotX, dotY), isSelected ? 12.0 : 8.0, dotPaint);
      
      if (isSelected) {
        final innerDotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(dotX, dotY), 4.0, innerDotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return true; 
  }
}
