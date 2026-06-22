// lib/screens/web/org/org_settings.dart
//
// NOTE: Embedded inside OrgDashboard's IndexedStack.
// No extra Scaffold or outer padding — dashboard provides background + topbar.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../services/totp_service.dart';
import '../../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors merchandise & student accounts)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      suffixIcon: suffix,
      labelStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide:
            BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main embedded screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgSettingsScreen extends StatefulWidget {
  final String orgId;
  final String orgName;
  final String orgShortName;
  final String orgEmail;

  const OrgSettingsScreen({
    super.key,
    required this.orgId,
    required this.orgName,
    required this.orgShortName,
    required this.orgEmail,
  });

  @override
  State<OrgSettingsScreen> createState() => _OrgSettingsScreenState();
}

class _OrgSettingsScreenState extends State<OrgSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 720 ? 16.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Tab bar (rounded pill, smooth sliding indicator) ──
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E6EA)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: BorderRadius.circular(9),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(9),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(height: 38, text: 'Notifications'),
                Tab(height: 38, text: 'Security'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Tab views ────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _NotificationsTab(orgId: widget.orgId),
              _SecurityTab(orgId: widget.orgId),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Tab
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsTab extends StatefulWidget {
  final String orgId;
  const _NotificationsTab({required this.orgId});

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  Map<String, bool> _prefs = {};
  bool _isLoading = true;

  final List<Map<String, String>> _prefKeys = [
    {'label': 'Email Notifications', 'key': 'email_notifications', 'desc': 'Receive updates via email'},
    {'label': 'Push Notifications', 'key': 'push_notifications', 'desc': 'Receive push notifications on your device'},
    {'label': 'Event Reminders', 'key': 'event_reminders', 'desc': 'Get reminded about upcoming events'},
    {'label': 'Proposal Updates', 'key': 'proposal_updates', 'desc': 'Notify when proposal status changes'},
    {'label': 'Announcement Alerts', 'key': 'announcement_alerts', 'desc': 'Get alerted for new announcements'},
    {'label': 'Broadcast Messages', 'key': 'broadcast_messages', 'desc': 'Receive broadcast channel messages'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notifications')
        .get();
    final data = doc.exists ? doc.data() as Map<String, dynamic> : {};
    setState(() {
      for (final item in _prefKeys) {
        _prefs[item['key']!] = data[item['key']] ?? true;
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('notifications')
        .set(Map<String, dynamic>.from(_prefs));
    await activity_log.ActivityLogger.log(
      action: 'save_notification_settings',
      module: 'settings',
      details: {'orgId': widget.orgId},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: UpriseColors.success),
      );
    }
  }

  void _restoreDefaults() {
    setState(() {
      for (final item in _prefKeys) _prefs[item['key']!] = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Defaults restored (not saved yet)'),
          backgroundColor: UpriseColors.info),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 720 ? 16.0 : 28.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification Preferences',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C))),
            const SizedBox(height: 4),
            Text('Choose which events trigger notifications for your account.',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(height: 20),
            ..._prefKeys.map((item) => _NotificationTile(
                  label: item['label']!,
                  description: item['desc']!,
                  value: _prefs[item['key']!] ?? true,
                  onChanged: (v) => setState(() => _prefs[item['key']!] = v),
                )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _restoreDefaults,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: UpriseColors.primaryLight),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Restore Defaults', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Save Changes',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String label, description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A202C))),
                const SizedBox(height: 2),
                Text(description,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: UpriseColors.primaryDark,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Security Tab
// ─────────────────────────────────────────────────────────────────────────────
class _SecurityTab extends StatefulWidget {
  final String orgId;
  const _SecurityTab({required this.orgId});

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isUpdating = false;
  bool _twoFactorEnabled = false;
  bool _loading2FA = true;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _load2FA();
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load2FA() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('security')
        .get();
    setState(() {
      _twoFactorEnabled = doc.data()?['twoFactorEnabled'] ?? false;
      _loading2FA = false;
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUpdating = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordCtrl.text.trim());
      await activity_log.ActivityLogger.log(
        action: 'change_password',
        module: 'settings',
        severity: 'security',
        details: {'orgId': widget.orgId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password updated successfully'),
              backgroundColor: UpriseColors.success),
        );
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggle2FA(bool value) async {
    if (value) {
      await _startTwoFactorSetup();
    } else {
      await _confirmAndDisableTwoFactor();
    }
  }

  /// Real TOTP setup: generates a secret, shows the QR code for an
  /// authenticator app, and requires the user to prove they actually set
  /// it up by entering a live code before it's persisted as enabled.
  Future<void> _startTwoFactorSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final secret = TotpService.generateSecret();
    final uri = TotpService.buildOtpAuthUri(
      secret: secret,
      accountName: user.email ?? widget.orgId,
    );
    final codeCtrl = TextEditingController();
    String? error;
    bool verifying = false;

    final enabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> verify() async {
            final code = codeCtrl.text.trim();
            if (code.length != 6) {
              setDialogState(() => error = 'Enter the 6-digit code from your app');
              return;
            }
            setDialogState(() { verifying = true; error = null; });
            final ok = TotpService.verifyCode(secret, code);
            if (!ok) {
              setDialogState(() { verifying = false; error = 'Incorrect code. Check the time on your device and try again.'; });
              return;
            }
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('settings')
                .doc('security')
                .set({'twoFactorEnabled': true, 'twoFactorSecret': secret}, SetOptions(merge: true));
            if (ctx.mounted) Navigator.pop(ctx, true);
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set Up Two-Factor Authentication',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Scan this QR code with Google Authenticator, Authy, or any TOTP app.',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(data: uri, size: 180),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text("Can't scan? Enter this code manually:",
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  SelectableText(
                    TotpService.formatSecretForDisplay(secret),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.2, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.beVietnamPro(fontSize: 18, letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      errorText: error,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => verify(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: verifying ? null : () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: GoogleFonts.beVietnamPro()),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: verifying ? null : verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                        ),
                        child: verifying
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Verify & Enable', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (enabled == true && mounted) {
      setState(() => _twoFactorEnabled = true);
      await activity_log.ActivityLogger.log(
        action: 'enable_2fa',
        module: 'settings',
        severity: 'security',
        details: {'orgId': widget.orgId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled'), backgroundColor: UpriseColors.success),
        );
      }
    }
  }

  /// Disabling 2FA requires a live code too — otherwise anyone at an
  /// unlocked, already-authenticated session could just flip it off.
  Future<void> _confirmAndDisableTwoFactor() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('settings')
        .doc('security')
        .get();
    final secret = doc.data()?['twoFactorSecret'] as String?;
    if (secret == null || secret.isEmpty) {
      // No secret on record (shouldn't normally happen) — just clear the flag.
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('settings').doc('security')
          .set({'twoFactorEnabled': false}, SetOptions(merge: true));
      if (mounted) setState(() => _twoFactorEnabled = false);
      return;
    }

    final codeCtrl = TextEditingController();
    String? error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Disable Two-Factor Authentication',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your current 6-digit code to confirm.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 18, letterSpacing: 4),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  errorText: error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.beVietnamPro())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error, foregroundColor: Colors.white),
              onPressed: () {
                if (TotpService.verifyCode(secret, codeCtrl.text.trim())) {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() => error = 'Incorrect code');
                }
              },
              child: Text('Disable', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('security')
          .set({'twoFactorEnabled': false, 'twoFactorSecret': FieldValue.delete()}, SetOptions(merge: true));
      if (mounted) setState(() => _twoFactorEnabled = false);
      await activity_log.ActivityLogger.log(
        action: 'disable_2fa',
        module: 'settings',
        severity: 'security',
        details: {'orgId': widget.orgId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled'), backgroundColor: UpriseColors.warning),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 720 ? 16.0 : 28.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Password change card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Password & Security',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C))),
                const SizedBox(height: 4),
                Text(
                    'Update your password regularly to keep your account secure.',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: const Color(0xFF64748B))),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _currentPasswordCtrl,
                        obscureText: _obscureCurrent,
                        decoration: _DS.inputDecoration(
                          'Current Password',
                          suffix: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () => setState(
                                () => _obscureCurrent = !_obscureCurrent),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPasswordCtrl,
                        obscureText: _obscureNew,
                        decoration: _DS.inputDecoration(
                          'New Password',
                          suffix: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) {
                            return 'Must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscureConfirm,
                        decoration: _DS.inputDecoration(
                          'Confirm New Password',
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        validator: (v) => v != _newPasswordCtrl.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _isUpdating ? null : _updatePassword,
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.lock_outline, size: 16),
                          label: Text('Update Password',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UpriseColors.primaryDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2FA card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Two-Factor Authentication',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A202C))),
                        const SizedBox(height: 2),
                        Text(
                          _twoFactorEnabled
                              ? 'Currently enabled — your account has extra protection'
                              : 'Currently disabled — consider enabling for better security',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              color: _twoFactorEnabled
                                  ? UpriseColors.success
                                  : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (!_loading2FA)
                    Switch(
                      value: _twoFactorEnabled,
                      onChanged: _toggle2FA,
                      activeColor: UpriseColors.primaryDark,
                    )
                  else
                    const SizedBox(
                        width: 36,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: UpriseColors.info.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: UpriseColors.info.withAlpha(51)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: UpriseColors.info, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Highly recommended: enabling 2FA ensures that even if someone learns your password, they cannot access your account without your trusted device.',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12, color: UpriseColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Recent security activity card
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recent Security Activity',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C))),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  // Filtered by orgId (matches the existing orgId+timestamp
                  // composite index) instead of user+severity, which has no
                  // index and previously made this query fail silently and
                  // spin forever.
                  stream: FirebaseFirestore.instance
                      .collection('activity_logs')
                      .where('orgId', isEqualTo: widget.orgId)
                      .orderBy('timestamp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Could not load security activity',
                              style: GoogleFonts.beVietnamPro(
                                  color: UpriseColors.error, fontSize: 13)),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    final currentEmail =
                        FirebaseAuth.instance.currentUser?.email ?? '';
                    final docs = snap.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      return data['user'] == currentEmail &&
                          data['severity'] == 'security';
                    }).take(10).toList();
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No security activity recorded',
                              style: GoogleFonts.beVietnamPro(
                                  color: const Color(0xFF64748B),
                                  fontSize: 13)),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final action = data['action'] ?? 'Unknown action';
                        final timestamp = (data['timestamp'] as Timestamp?)
                                ?.toDate() ??
                            DateTime.now();
                        final details = data['details'] as Map<String, dynamic>?;
                        final location =
                            details?['location'] ?? 'Unknown location';
                        return ListTile(
                          leading: const Icon(Icons.security,
                              color: UpriseColors.info, size: 20),
                          title: Text(action,
                              style: GoogleFonts.beVietnamPro(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                          subtitle: Text(
                            '$location • ${DateFormat('MMM dd, yyyy h:mm a').format(timestamp)}',
                            style: GoogleFonts.beVietnamPro(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.devices,
                              size: 16, color: Color(0xFF64748B)),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}