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

class _OrganizationLoginState extends State<OrganizationLogin>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;
  bool _rememberMe      = false;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _animController.dispose();
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
      final User? user = await _auth.loginWithEmail(email, password);
      if (user == null) {
        _showError('Invalid email or password');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final String role = await _auth.getUserRole(user.uid) ?? '';
      if (role != 'org') {
        await FirebaseAuth.instance.signOut();
        _showError('This account is not authorized for the Organization Portal');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      AuthService.cacheRole(user.uid, role);
      await _saveEmail(email);
      final bool needsChange = await _auth.needsPasswordChange(user.uid);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => needsChange
              ? ChangePasswordScreen(userId: user.uid, isFirstLogin: true)
              : OrgDashboard(),
        ));
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':    msg = 'No account found with this email';  break;
        case 'wrong-password':
        case 'invalid-credential':msg = 'Incorrect email or password';       break;
        case 'invalid-email':     msg = 'Please enter a valid email address';break;
        case 'too-many-requests': msg = 'Too many attempts. Try again later';break;
        default:                  msg = e.message ?? 'Login failed';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Send a password reset link to\n$email',
            style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Send Link',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset link sent! Check your inbox.',
                style: GoogleFonts.plusJakartaSans()),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to send reset email: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A2E),
            ),
          ),
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_pattern.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.center,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.38),
                  Colors.black.withOpacity(0.22),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideUp,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _buildCard(),
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

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 48,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            // ── Top accent stripe ──────────────────────────────────
            Container(
              height: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFD97706)],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0,
                32,
                MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0,
                28,
              ),
              child: Column(
                children: [
                  // ── Logo ────────────────────────────────────────
                  _buildLogo(),
                  const SizedBox(height: 16),

                  // ── Brand name ──────────────────────────────────
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: 2.5,
                      ),
                      children: [
                        TextSpan(
                            text: 'UP',
                            style: TextStyle(color: Color(0xFFEF4444))),
                        TextSpan(
                            text: 'RISE',
                            style: TextStyle(color: Color(0xFFD97706))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Portal badge ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'ORGANIZATION PORTAL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Subtitle ─────────────────────────────────────
                  Text(
                    'Sign in to manage your organization\'s\nevents, reports, and members.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // ── Email ────────────────────────────────────────
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'org@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: 14),

                  // ── Password ─────────────────────────────────────
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: '••••••••',
                    obscure: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 12),

                  // ── Remember me + Forgot ──────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => _rememberMe = !_rememberMe);
                          if (!_rememberMe) _saveEmail('');
                        },
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _rememberMe
                                    ? const Color(0xFFD97706)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _rememberMe
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              child: _rememberMe
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Remember me',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Login button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFD97706).withOpacity(0.55),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Text(
                              'Login to Organization Portal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),

                  // ── Divider ──────────────────────────────────────
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: Colors.grey.shade200, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF94A3B8))),
                    ),
                    Expanded(
                        child: Divider(
                            color: Colors.grey.shade200, thickness: 1)),
                  ]),
                  const SizedBox(height: 20),

                  // ── Footer ───────────────────────────────────────
                  Text(
                    "Don't have an organization account?",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: const Color(0xFF94A3B8)),
                  ),
                  Text(
                    'Contact CICT Administrator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 13, color: Color(0xFFD97706)),
                    label: Text(
                      'Back to Portal Selection',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFAF5EE),
        border: Border.all(color: const Color(0xFFFED7AA), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.business_outlined,
              size: 44,
              color: Color(0xFFD97706),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      style: GoogleFonts.plusJakartaSans(
          fontSize: 14, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF94A3B8), fontSize: 13),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFCBD5E1), fontSize: 13),
        prefixIcon:
            Icon(prefixIcon, color: const Color(0xFFCBD5E1), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFD97706), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}