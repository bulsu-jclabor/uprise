import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth_service.dart';
import '../../auth/change_password_screen.dart';
import 'org_dashboard.dart';

class OrganizationLogin extends StatefulWidget {
  const OrganizationLogin({super.key});

  @override
  State<OrganizationLogin> createState() => _OrganizationLoginState();
}

class _OrganizationLoginState extends State<OrganizationLogin> {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _rememberMe      = false;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<SharedPreferences?> _getPrefs() async {
    try { return await SharedPreferences.getInstance(); }
    catch (_) { return null; }
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    final saved = prefs.getString('org_email');
    if (saved != null && saved.isNotEmpty) {
      setState(() { _emailController.text = saved; _rememberMe = true; });
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    if (_rememberMe && email.isNotEmpty) {
      await prefs.setString('org_email', email);
    } else {
      await prefs.remove('org_email');
    }
  }

Future<void> _login() async {
  final email    = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty)    { _showError('Please enter your email address'); return; }
  if (password.isEmpty) { _showError('Please enter your password');      return; }

  setState(() => _isLoading = true);

  try {
    // 1. Authenticate
    final User? user = await _auth.loginWithEmail(email, password);
    if (user == null) {
      _showError('Invalid email or password');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 2. Verify role once and stop extra network work
    final String role = await _auth.getUserRole(user.uid) ?? '';
    debugPrint('OrgLogin successful uid=${user.uid} role=$role');
    if (role != 'org') {
      await FirebaseAuth.instance.signOut();
      _showError('This account is not authorized for the Organization Portal');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 3. Cache role so the landing gate can resolve immediately.
    AuthService.cacheRole(user.uid, role);

    // 4. Save email preference
    await _saveEmail(email);
    // 5. If first login, redirect to Change Password flow
    final bool needsChange = await _auth.needsPasswordChange(user.uid);
    debugPrint('OrgLogin: needsPasswordChange=$needsChange for uid=${user.uid}');
    if (needsChange) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ChangePasswordScreen(userId: user.uid, isFirstLogin: true),
        ));
      }
      return;
    }

    // 6. Directly open OrgDashboard on successful login
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrgDashboard()),
      );
    }

  } on FirebaseAuthException catch (e) {
    String msg;
    switch (e.code) {
      case 'user-not-found':     msg = 'No account found with this email';  break;
      case 'wrong-password':
      case 'invalid-credential': msg = 'Incorrect email or password';        break;
      case 'invalid-email':      msg = 'Please enter a valid email address'; break;
      case 'too-many-requests':  msg = 'Too many attempts. Try again later'; break;
      default:                   msg = e.message ?? 'Login failed';
    }
    _showError(msg);
    if (mounted) setState(() => _isLoading = false);
  } on FirebaseException catch (e) {
    await FirebaseAuth.instance.signOut();
    _showError('Database error: ${e.message ?? e.code}');
    if (mounted) setState(() => _isLoading = false);
  } catch (e) {
    _showError('Login failed: ${e.toString()}');
    if (mounted) setState(() => _isLoading = false);
  }
}

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { _showError('Please enter your email address first'); return; }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      _showError('Failed to send reset email: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_pattern.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.62),
                Colors.black.withOpacity(0.18),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFAF5EE),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 64, height: 64,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.business, size: 48, color: Color(0xFFD97706)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'BeVietnamPro',
                              letterSpacing: 1.8,
                            ),
                            children: [
                              TextSpan(text: 'UP',   style: TextStyle(color: Colors.red)),
                              TextSpan(text: 'RISE', style: TextStyle(color: Color(0xFFD97706))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Organization Portal',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 14, color: const Color(0xFF475569)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Sign in to manage your organization\'s events, reports, and members.',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 14, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        // Email field
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle: GoogleFonts.beVietnamPro(
                                color: const Color(0xFF475569)),
                            hintText: 'org@example.com',
                            hintStyle: GoogleFonts.beVietnamPro(
                                color: Colors.grey.shade400),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 18),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: GoogleFonts.beVietnamPro(
                                color: const Color(0xFF475569)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Remember me
                        Row(children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) {
                              setState(() => _rememberMe = v ?? false);
                              if (!_rememberMe) _saveEmail('');
                            },
                            activeColor: const Color(0xFFD97706),
                          ),
                          Text('Remember Me',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  color: const Color(0xFF475569))),
                        ]),
                        // Forgot password
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text('Forgot Password?',
                                  style: GoogleFonts.beVietnamPro(
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('Login to Organization Portal',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Don't have an organization account? Contact CICT Admin",
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          child: Text('← Back to Portal Selection',
                              style: GoogleFonts.beVietnamPro(
                                color: const Color(0xFFD97706),
                                fontWeight: FontWeight.w600,
                              )),
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
    );
  }
}
