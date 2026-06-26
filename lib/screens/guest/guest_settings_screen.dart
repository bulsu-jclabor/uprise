// lib/screens/guest/guest_settings_screen.dart
//
// GUEST SETTINGS — promoted out of guest_profile_screen.dart so it can be
// reached from the new Profile Menu Hub. Adds a voluntary Change Password
// entry on top of the original Notifications/Privacy/Help/About tiles.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'guest_access_gateway_screen.dart' show GuestChangePasswordScreen;
import '../../widgets/shared/app_support.dart';

const _kOrange = Color(0xFFBE4700);
const _kOrangeLight = Color(0xFFF5E3D9);
const _kBg = Color(0xFFF5F5F5);
const _kSuccess = Color(0xFF059669);
const _kSuccessBg = Color(0xFFECFDF5);

class GuestSettingsScreen extends StatelessWidget {
  final String fullName;
  final String email;
  final String school;
  final String docId;
  final VoidCallback onLogout;

  const GuestSettingsScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.school,
    required this.docId,
    required this.onLogout,
  });

  String get _initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'G';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: GoogleFonts.beVietnamPro(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Profile card ────────────────────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kOrangeLight,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(_initials,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 26, fontWeight: FontWeight.w900, color: _kOrange)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(fullName,
                      style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(email, style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(school, style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _kSuccessBg, borderRadius: BorderRadius.circular(20)),
                    child: Text('VERIFIED GUEST',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 10, fontWeight: FontWeight.w800, color: _kSuccess, letterSpacing: 0.6)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Account ──────────────────────────────────────
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuestChangePasswordScreen(
                          uid: uid,
                          docId: docId,
                          forced: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── General settings tiles ──────────────────────
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage event alerts',
                    onTap: () => openNotificationSettings(context),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    subtitle: 'Data and privacy settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySecurityScreen(isGuest: true),
                        ),
                      );
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact info',
                    onTap: () => launchSupportEmail(context, subject: 'UPRISE Support Request'),
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About UPRISE',
                    subtitle: 'App version and information',
                    onTap: () {},
                    trailing: FutureBuilder<String>(
                      future: getAppVersionLabel(),
                      builder: (context, snap) => Text(
                        snap.data ?? '...',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Logout ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close settings first
                  onLogout();
                },
                icon: const Icon(Icons.logout, color: _kOrange),
                label: Text('Log Out',
                    style: GoogleFonts.beVietnamPro(
                        color: _kOrange, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: _kOrange),
      title: Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}
