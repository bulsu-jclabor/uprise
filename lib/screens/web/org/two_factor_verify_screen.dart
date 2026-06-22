// lib/screens/web/org/two_factor_verify_screen.dart
//
// Shown after a correct email/password login, only when the org account
// has TOTP 2FA enabled (see org_settings.dart's Security tab for setup).
// Password auth has already succeeded by this point — this screen is the
// actual second factor gate before `onVerified` is allowed to run.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/totp_service.dart';

class TwoFactorVerifyScreen extends StatefulWidget {
  final String secret;
  final VoidCallback onVerified;
  final VoidCallback onCancel;

  const TwoFactorVerifyScreen({
    super.key,
    required this.secret,
    required this.onVerified,
    required this.onCancel,
  });

  @override
  State<TwoFactorVerifyScreen> createState() => _TwoFactorVerifyScreenState();
}

class _TwoFactorVerifyScreenState extends State<TwoFactorVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    final ok = TotpService.verifyCode(widget.secret, code);
    if (!ok) {
      setState(() { _verifying = false; _error = 'Incorrect code. Please try again.'; });
      return;
    }
    widget.onVerified();
  }

  Future<void> _cancel() async {
    await FirebaseAuth.instance.signOut();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 48, offset: const Offset(0, 20)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFEA580C), size: 32),
                  ),
                  const SizedBox(height: 20),
                  Text('Two-Factor Verification',
                      style: GoogleFonts.beVietnamPro(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code from your authenticator app to continue.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      errorText: _error,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _verifying ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                      child: _verifying
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('Verify', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _verifying ? null : _cancel,
                    child: Text('Cancel and sign out',
                        style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
