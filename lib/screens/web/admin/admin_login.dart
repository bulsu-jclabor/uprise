import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth_service.dart';
import '../../../main_web.dart';
import '../../auth/change_password_screen.dart';
import 'admin_dashboard.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});
  @override
  _AdminLoginState createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin>
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
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
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
    final saved = prefs.getString('admin_email');
    if (saved != null && saved.isNotEmpty) {
      setState(() { _emailController.text = saved; _rememberMe = true; });
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await _getPrefs();
    if (prefs == null) return;
    if (_rememberMe && email.isNotEmpty) {
      await prefs.setString('admin_email', email);
    } else {
      await prefs.remove('admin_email');
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { _showError('Please enter your email address'); return; }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Please enter a valid email address'); return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _showError('Please enter your password'); return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await _auth.loginWithEmail(
          _emailController.text.trim(), _passwordController.text.trim());
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()?['role'] == 'admin') {
          await _saveEmail(_emailController.text.trim());
          final needsChange = await _auth.needsPasswordChange(user.uid);
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => needsChange
                  ? ChangePasswordScreen(userId: user.uid, isFirstLogin: true)
                  : AdminDashboard()));
          }
        } else {
          await FirebaseAuth.instance.signOut();
          _showError('This account is not authorized as Admin');
        }
      } else {
        _showError('Invalid email or password');
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':    msg = 'No account found with this email'; break;
        case 'wrong-password':    msg = 'Incorrect password'; break;
        case 'invalid-email':     msg = 'Please enter a valid email address'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try again later'; break;
        default:                  msg = e.message ?? 'Login failed';
      }
      _showError(msg);
    } catch (e) {
      _showError('An error occurred: ${e.toString()}');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) { _showError('Please enter your email address first'); return; }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Password',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Text('Send a password reset link to\n$email',
            style: GoogleFonts.beVietnamPro()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(color: const Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFB923C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Send Link',
                style: GoogleFonts.beVietnamPro(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Reset link sent! Check your inbox.',
              style: GoogleFonts.beVietnamPro()),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      content: Text(message, style: GoogleFonts.beVietnamPro()),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: LayoutBuilder(builder: (_, c) {
        return c.maxWidth > 820 ? _buildSplitLayout() : _buildCompactLayout();
      }),
    );
  }

  // ── Wide: split layout ─────────────────────────────────────────────────────

  Widget _buildSplitLayout() {
    return SizedBox.expand(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildBrandPanel()),
          SizedBox(width: 480, child: _buildFormPanel()),
        ],
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF0D1526)],
        ),
      ),
      child: Stack(children: [
        // Subtle background texture
        Positioned.fill(
          child: Opacity(
            opacity: 0.04,
            child: Image.asset('assets/images/bg_pattern.png',
                fit: BoxFit.cover),
          ),
        ),
        // Faint amber glow — top-left corner
        Positioned(
          top: -180, left: -120,
          child: Container(
            width: 560, height: 560,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x30F97316), Colors.transparent]),
            ),
          ),
        ),
        // Faint red glow — bottom-right corner
        Positioned(
          bottom: -160, right: -100,
          child: Container(
            width: 440, height: 440,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x18EF4444), Colors.transparent]),
            ),
          ),
        ),
        // Content
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo — no container, displayed cleanly on the dark background
                SizedBox(
                  height: 110,
                  child: Image.asset('assets/images/logo.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_outlined,
                          size: 64, color: Color(0xFFFB923C))),
                ),
                const SizedBox(height: 28),

                // UPRISE wordmark — Row of Text so GoogleFonts loads correctly
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('UP',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 52, fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                        letterSpacing: 2, height: 1)),
                  Text('RISE',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 52, fontWeight: FontWeight.w800,
                        color: const Color(0xFFFB923C),
                        letterSpacing: 2, height: 1)),
                ]),
                const SizedBox(height: 8),

                Text('ADMIN PORTAL',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(130),
                      letterSpacing: 4.5)),
                const SizedBox(height: 44),

                // Gradient accent bar
                Container(
                  width: 40, height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFFB923C)]),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Manage students,\norganizations, and\ncampus events from\none unified dashboard.',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 18, fontWeight: FontWeight.w300,
                    color: Colors.white.withAlpha(185), height: 1.85),
                ),
                const SizedBox(height: 64),

                // Institution tag
                Row(children: [
                  Container(
                    width: 4, height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFFFB923C)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'College of Information and\nCommunications Technology',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11.5, color: Colors.white.withAlpha(100),
                      height: 1.6),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormPanel() {

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 52),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Narrow: compact centered card ─────────────────────────────────────────

  Widget _buildCompactLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1A2235)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildCompactCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(70),
              blurRadius: 48, offset: const Offset(0, 20)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Accent stripe
        Container(
          height: 4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFFB923C)]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 36),
          child: Column(children: [
            // Logo
            SizedBox(
              height: 80,
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.shield_outlined, size: 48, color: Color(0xFFFB923C))),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('UP',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444), letterSpacing: 2, height: 1)),
              Text('RISE',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 28, fontWeight: FontWeight.w800,
                    color: const Color(0xFFFB923C), letterSpacing: 2, height: 1)),
            ]),
            const SizedBox(height: 8),
            _buildAdminBadge(),
            const SizedBox(height: 24),
            _buildForm(),
          ]),
        ),
      ]),
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sign in',
            style: GoogleFonts.beVietnamPro(
              fontSize: 24, fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A), letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text('Enter your credentials to access the admin dashboard.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: const Color(0xFF64748B), height: 1.55)),
        const SizedBox(height: 28),

        _buildField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'admin@uprise.org',
          icon: Icons.mail_outline_rounded,
          type: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),

        _buildField(
          controller: _passwordController,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePassword,
          suffix: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFFCBD5E1), size: 18),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          onSubmit: (_) => _login(),
        ),
        const SizedBox(height: 12),

        // Remember me + Forgot password
        Row(children: [
          GestureDetector(
            onTap: () {
              setState(() => _rememberMe = !_rememberMe);
              if (!_rememberMe) _saveEmail('');
            },
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 17, height: 17,
                decoration: BoxDecoration(
                  color: _rememberMe ? const Color(0xFFFB923C) : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _rememberMe
                        ? const Color(0xFFFB923C) : const Color(0xFFCBD5E1),
                    width: 1.5),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 7),
              Text('Remember me',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12.5, color: const Color(0xFF475569))),
            ]),
          ),
          const Spacer(),
          TextButton(
            onPressed: _resetPassword,
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Forgot password?',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12.5, color: const Color(0xFFFB923C),
                  fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 22),

        // Login button — gradient with glow
        AnimatedOpacity(
          opacity: _isLoading ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFEA580C), Color(0xFFFB923C)]),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFB923C).withAlpha(65),
                    blurRadius: 18, offset: const Offset(0, 7)),
              ],
            ),
            child: TextButton(
              onPressed: _isLoading ? null : _login,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Sign In to Dashboard',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        letterSpacing: 0.1)),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Divider
        Row(children: [
          const Expanded(child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: const Color(0xFFCBD5E1)))),
          const Expanded(child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
        ]),
        const SizedBox(height: 22),

        // Footer
        Center(
          child: Column(children: [
            Text("Don't have an admin account?",
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12.5, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 2),
            Text('Contact System Administrator',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12.5, color: const Color(0xFF334155),
                  fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LandingPage())),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 11, color: Color(0xFFFB923C)),
              label: Text('Back to Portal Selection',
                  style: GoogleFonts.beVietnamPro(
                    color: const Color(0xFFFB923C),
                    fontWeight: FontWeight.w600, fontSize: 12.5)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Shared components ──────────────────────────────────────────────────────

  Widget _buildAdminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFFB923C))),
        const SizedBox(width: 6),
        Text('ADMIN PORTAL',
            style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: const Color(0xFFC2410C), letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: GoogleFonts.beVietnamPro(fontSize: 13.5, color: const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.beVietnamPro(
            color: const Color(0xFF94A3B8), fontSize: 13),
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(
            color: const Color(0xFFCBD5E1), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFCBD5E1), size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: Color(0xFFFB923C), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }
}
