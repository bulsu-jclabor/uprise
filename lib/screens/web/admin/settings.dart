import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'admin_login.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Activity Logger
// ─────────────────────────────────────────────────────────────────────────────
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user     = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user':      userName,
      'action':    action,
      'module':    module,
      'severity':  severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details':   details,
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: enabled ? const Color(0xFFF8F9FB) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE8ECF0), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Severity badge (reused from activity logs)
// ─────────────────────────────────────────────────────────────────────────────
class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge(this.severity);

  @override
  Widget build(BuildContext context) {
    final Map<String, _BadgeStyle> styles = {
      'info':     _BadgeStyle(const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'INFO'),
      'warning':  _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFFB923C), 'WARNING'),
      'error':    _BadgeStyle(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'ERROR'),
      'critical': _BadgeStyle(const Color(0xFFFDF2F8), const Color(0xFF9333EA), 'CRITICAL'),
    };
    final s = styles[severity.toLowerCase()] ??
        _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280), severity.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(_DS.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: s.fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label helper
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: UpriseColors.primaryDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class AdminSettings extends StatefulWidget {
  // Settings renders inside the dashboard's persistent shell (the top bar
  // with the admin's name/avatar stays mounted), so a profile save here
  // needs to tell that shell to re-fetch — otherwise the name/photo only
  // updates after navigating away and back.
  final VoidCallback? onProfileUpdated;
  const AdminSettings({super.key, this.onProfileUpdated});

  @override
  _AdminSettingsState createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile
  final _fullNameController    = TextEditingController();
  final _emailController       = TextEditingController();
  bool   _isLoading            = false;
  User?  _currentUser;
  String? _profileImageBase64;

  // Password
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword            = false;
  bool _showConfirmPassword        = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUser   = FirebaseAuth.instance.currentUser;
    _loadUserData();
    _loadProfileImage();
  }

  Future<List<Map<String, dynamic>>> _fetchUserAuditLogs(String email) async {
    final col = FirebaseFirestore.instance.collection('activity_logs');
    try {
      final qs = await col
          .where('user', isEqualTo: email)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      return qs.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        final tsField = m['timestamp'];
        DateTime? ts;
        if (tsField is Timestamp) ts = tsField.toDate();
        else if (tsField is DateTime) ts = tsField;
        m['_ts'] = ts;
        m['_id'] = d.id;
        return m;
      }).toList();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Firestore returns a failed-precondition indicating an index is required.
      if (msg.contains('requires an index') || msg.contains('failed-precondition')) {
        // Fallback: fetch matching docs without ordering and sort client-side.
        final qs = await col.where('user', isEqualTo: email).limit(50).get();
        final list = qs.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          final tsField = m['timestamp'];
          DateTime? ts;
          if (tsField is Timestamp) ts = tsField.toDate();
          else if (tsField is DateTime) ts = tsField;
          m['_ts'] = ts;
          m['_id'] = d.id;
          return m;
        }).toList();
        list.sort((a, b) {
          final at = a['_ts'] as DateTime?;
          final bt = b['_ts'] as DateTime?;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        return list.take(20).toList();
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Data loaders ──────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _fullNameController.text = _currentUser!.displayName ?? '';
      _emailController.text    = _currentUser!.email ?? '';
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        _fullNameController.text = data['fullName'] ?? _fullNameController.text;
        _emailController.text    = data['email']    ?? _emailController.text;
      }
    }
    setState(() {});
  }

  Future<void> _loadProfileImage() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['photoBase64'] != null) {
        setState(() => _profileImageBase64 = data['photoBase64']);
      }
    }
  }

  // ── Actions ───────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked == null) return;
    setState(() => _isLoading = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'photoBase64': base64String}, SetOptions(merge: true));
      setState(() => _profileImageBase64 = base64String);
      await ActivityLogger.log(
          action: 'Updated profile picture', module: 'Admin Settings');
      widget.onProfileUpdated?.call();
      _showSnack('Profile picture updated', success: true);
    } catch (e) {
      _showSnack('Error saving picture: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnack('Name cannot be empty', success: false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _currentUser!.updateDisplayName(_fullNameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
        'fullName':  _fullNameController.text.trim(),
        'email':     _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await ActivityLogger.log(
          action: 'Updated profile name to ${_fullNameController.text.trim()}',
          module: 'Admin Settings');
      widget.onProfileUpdated?.call();
      _showSnack('Profile updated successfully', success: true);
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack('Passwords do not match', success: false);
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showSnack('Password must be at least 6 characters', success: false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _currentUser!.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      await ActivityLogger.log(
          action: 'Changed account password', module: 'Admin Settings');
      _showSnack('Password changed successfully', success: true);
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.beVietnamPro(fontSize: 13)),
        backgroundColor: success ? const Color(0xFF059669) : UpriseColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFBFCFE),
      child: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildSecurityTab(),
                _buildAuditLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Security'),
          Tab(text: 'Audit Logs'),
        ],
        labelColor: UpriseColors.primaryDark,
        unselectedLabelColor: const Color(0xFF64748B),
        indicatorColor: UpriseColors.primaryDark,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PROFILE TAB
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildProfileTab() {
    ImageProvider? imageProvider;
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      imageProvider = MemoryImage(base64Decode(_profileImageBase64!));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_DS.radiusLg),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: UpriseColors.primaryDark.withOpacity(0.15),
                                width: 3),
                            boxShadow: _DS.cardShadow,
                          ),
                          child: ClipOval(
                            child: imageProvider != null
                                ? Image(image: imageProvider, fit: BoxFit.cover)
                                : Container(
                                    color: UpriseColors.primaryDark.withOpacity(0.08),
                                    child: Icon(Icons.person_rounded,
                                        size: 48, color: UpriseColors.primaryDark.withOpacity(0.4)),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isLoading ? null : _pickAndUploadImage,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: UpriseColors.primaryDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt_rounded,
                                      size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _fullNameController.text.isNotEmpty
                          ? _fullNameController.text
                          : 'Admin User',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: UpriseColors.primaryDark.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(_DS.radiusPill),
                      ),
                      child: Text(
                        'System Administrator',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: UpriseColors.primaryDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the camera icon to change your photo',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: const Color(0xFF9AA5B4)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Personal info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_DS.radiusLg),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Personal Information', icon: Icons.badge_outlined),
                    TextFormField(
                      controller: _fullNameController,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: _DS.inputDecoration('Full Name',
                          hint: 'e.g., Juan dela Cruz', icon: Icons.person_outline_rounded),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: false,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: const Color(0xFF9AA5B4)),
                      decoration: _DS.inputDecoration('Email Address',
                          icon: Icons.email_outlined, enabled: false),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        'Email address cannot be changed here.',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, color: const Color(0xFF9AA5B4)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updateProfile,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(
                        'Save Changes',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_DS.radiusSm)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(
          color: value
              ? UpriseColors.primaryDark.withOpacity(0.3)
              : const Color(0xFFE2E6EA),
        ),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: value
                ? UpriseColors.primaryDark.withOpacity(0.10)
                : const Color(0xFFE8ECF0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: value
                  ? UpriseColors.primaryDark
                  : const Color(0xFF9AA5B4)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: const Color(0xFF64748B))),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: UpriseColors.primaryDark,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SECURITY TAB
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Change password card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_DS.radiusLg),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Change Password', icon: Icons.lock_outline_rounded),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F6FF),
                        borderRadius: BorderRadius.circular(_DS.radiusSm),
                        border: Border.all(color: const Color(0xFFBFD7FF)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Regularly updating your password keeps your account secure.',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12, color: const Color(0xFF1D4ED8), height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: !_showNewPassword,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: _DS
                          .inputDecoration('New Password', icon: Icons.lock_outline_rounded)
                          .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showNewPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFF9AA5B4),
                              ),
                              onPressed: () =>
                                  setState(() => _showNewPassword = !_showNewPassword),
                            ),
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: _DS
                          .inputDecoration('Confirm New Password',
                              icon: Icons.lock_outline_rounded)
                          .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: const Color(0xFF9AA5B4),
                              ),
                              onPressed: () =>
                                  setState(() => _showConfirmPassword = !_showConfirmPassword),
                            ),
                          ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _changePassword,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.update_rounded, size: 16),
                      label: Text(
                        'Update Password',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_DS.radiusSm)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 2FA card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_DS.radiusLg),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Two-Factor Authentication', icon: Icons.shield_outlined),
                    _notificationTile(
                      title: 'Enable 2FA',
                      subtitle:
                          'Receive a verification code via email on each login',
                      icon: Icons.verified_user_outlined,
                      value: false,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Danger zone
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_DS.radiusLg),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Divider(
                              color: const Color(0xFFFCA5A5),
                              thickness: 1)),
                    ]),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const AdminLogin()),
                            (_) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 16),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_DS.radiusSm)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // AUDIT LOGS TAB
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildAuditLogsTab() {
    final email = _currentUser?.email ?? '';
    if (email.isEmpty) {
      return const Center(child: Text('Unable to load logs: user not found'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchUserAuditLogs(email),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 32, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 14),
                Text('Error loading logs',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151))),
                const SizedBox(height: 6),
                Text('${snapshot.error}',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
          );
        }

        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.history_rounded,
                      size: 40, color: Color(0xFF9AA5B4)),
                ),
                const SizedBox(height: 16),
                Text(
                  'No recent activity',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Actions you perform will appear here.',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Log count header
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
              child: Row(children: [
                Text(
                  'Your Recent Actions',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(_DS.radiusPill),
                  ),
                  child: Text(
                    '${logs.length} entries',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: UpriseColors.primaryDark,
                    ),
                  ),
                ),
              ]),
            ),
            // Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: _DS.cardShadow,
                ),
                child: Column(children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F9FB),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE8ECF0))),
                    ),
                    child: Row(children: [
                      Expanded(
                          flex: 5,
                          child: _headerCell('ACTION')),
                      Expanded(
                          flex: 3,
                          child: _headerCell('MODULE')),
                      Expanded(
                          flex: 2,
                          child: _headerCell('SEVERITY')),
                      Expanded(
                          flex: 3,
                          child: _headerCell('TIMESTAMP')),
                    ]),
                  ),
                  // Rows
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                      final data = logs[i] as Map<String, dynamic>;
                      final ts = data['_ts'] as DateTime?;
                      final severity = (data['severity'] ?? 'info').toString();
                      final module = (data['module'] ?? 'System').toString();
                      final action = (data['action'] ?? '—').toString();
                      final isLast = i == logs.length - 1;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : const Border(
                                    bottom: BorderSide(
                                        color: Color(0xFFF1F5F9))),
                          ),
                          child: Row(children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                action,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  color: const Color(0xFF374151),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: UpriseColors.primaryDark
                                      .withOpacity(0.07),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  module,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: UpriseColors.primaryDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _SeverityBadge(severity),
                            ),
                            Expanded(
                              flex: 3,
                              child: ts != null
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          DateFormat('MMM dd, yyyy')
                                              .format(ts),
                                          style: GoogleFonts.beVietnamPro(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF374151),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a').format(ts),
                                          style: GoogleFonts.beVietnamPro(
                                              fontSize: 11,
                                              color:
                                                  const Color(0xFF9AA5B4)),
                                        ),
                                      ],
                                    )
                                  : Text('—',
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 12,
                                          color:
                                              const Color(0xFF9AA5B4))),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                  // Footer note
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Color(0xFFE8ECF0))),
                      color: Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14)),
                    ),
                    child: Text(
                      'Showing your last ${logs.length} actions. Visit Activity Logs for the full audit trail.',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: const Color(0xFF9AA5B4)),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _headerCell(String text) => Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.7,
        ),
      );
}