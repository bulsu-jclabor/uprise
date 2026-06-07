// lib/screens/guest/guest_profile_screen.dart
//
// GUEST PROFILE — Cleaned-up, matches StudentProfileScreen layout.
//
// States:
//   1. Not registered  → Hero banner + "Apply for Access" button
//   2. Registered / pending / rejected → Status card + details (read-only)
//   3. Approved        → Full profile card + QR attendance pass + settings/logout
//
// Firestore collection: `external_requests`
// SharedPreferences key: 'external_request_doc_id'
//
// Dependencies: cloud_firestore, google_fonts, shared_preferences, qr_flutter
//

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
const _kOrange      = Color(0xFFFF6B00);
const _kOrangeLight = Color(0xFFFFEDD5);
const _kBg          = Color(0xFFF5F5F5);
const _kDark        = Color(0xFF1A1A2E);
const _kSuccess     = Color(0xFF059669);
const _kSuccessBg   = Color(0xFFECFDF5);
const _kWarning     = Color(0xFFD97706);
const _kWarningBg   = Color(0xFFFFFBEB);
const _kError       = Color(0xFFDC2626);
const _kErrorBg     = Color(0xFFFEF2F2);

// SharedPreferences key
const _kPrefKey = 'external_request_doc_id';

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN  (router)
// ─────────────────────────────────────────────────────────────
class GuestProfileScreen extends StatefulWidget {
  const GuestProfileScreen({super.key});

  @override
  State<GuestProfileScreen> createState() => _GuestProfileScreenState();
}

class _GuestProfileScreenState extends State<GuestProfileScreen> {
  String? _savedDocId;
  bool    _checking = true;

  @override
  void initState() {
    super.initState();
    _checkSavedApplication();
  }

  Future<void> _checkSavedApplication() async {
    final prefs = await SharedPreferences.getInstance();
    final docId = prefs.getString(_kPrefKey);
    if (mounted) setState(() { _savedDocId = docId; _checking = false; });
  }

  Future<void> _onSubmitted(String docId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, docId);
    if (mounted) setState(() => _savedDocId = docId);
  }

  Future<void> _onWithdraw() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    if (mounted) setState(() => _savedDocId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kOrange)),
      );
    }

    // Not registered yet → show the "no account" landing
    if (_savedDocId == null) {
      return _NotRegisteredScreen(onApply: () => _openRegistration(context));
    }

    // Has a doc ID → stream from Firestore to determine status
    return _ProfileRouter(
      docId:      _savedDocId!,
      onWithdraw: _onWithdraw,
      onApply:    () => _openRegistration(context),
    );
  }

  void _openRegistration(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RegistrationScreen(onSubmitted: _onSubmitted),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PROFILE ROUTER  (streams status from Firestore)
// ─────────────────────────────────────────────────────────────
class _ProfileRouter extends StatelessWidget {
  final String       docId;
  final VoidCallback onWithdraw;
  final VoidCallback onApply;

  const _ProfileRouter({
    required this.docId,
    required this.onWithdraw,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('external_requests')
          .doc(docId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _kBg,
            body: Center(child: CircularProgressIndicator(color: _kOrange)),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          // Document was deleted (e.g. admin removed it)
          return _NotRegisteredScreen(
            onApply: onApply,
            showDeletedNotice: true,
          );
        }

        final data   = snap.data!.data() as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'pending';

        if (status == 'approved') {
          return _ApprovedProfileScreen(
            docId:      docId,
            data:       data,
            onWithdraw: onWithdraw,
          );
        }

        // pending / rejected
        return _PendingRejectedScreen(
          docId:      docId,
          data:       data,
          status:     status,
          onWithdraw: onWithdraw,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATE 1 — NOT REGISTERED
// ─────────────────────────────────────────────────────────────
class _NotRegisteredScreen extends StatelessWidget {
  final VoidCallback onApply;
  final bool         showDeletedNotice;

  const _NotRegisteredScreen({
    required this.onApply,
    this.showDeletedNotice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Profile',
            style: GoogleFonts.beVietnamPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: const _AppBarLine(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: Column(
          children: [
            // ── Avatar placeholder ──────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kOrangeLight,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.person_outline_rounded,
                        size: 44, color: _kOrange),
                  ),
                  const SizedBox(height: 14),
                  Text('Guest',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('No account yet',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),

                  if (showDeletedNotice) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _kWarningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _kWarning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 16, color: _kWarning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your previous request was removed. You can apply again.',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 12,
                                  color: const Color(0xFF78350F)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: Text('Apply for Event Access',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── What you get card ───────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What you get after approval',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 14),
                  _BenefitRow(
                    icon: Icons.qr_code_2_rounded,
                    title: 'QR Attendance Pass',
                    sub: 'Generated from your registration details',
                  ),
                  const _Divider(),
                  _BenefitRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Public Event Access',
                    sub: 'Browse and register for CICT public events',
                  ),
                  const _Divider(),
                  _BenefitRow(
                    icon: Icons.campaign_outlined,
                    title: 'Announcements',
                    sub: 'Stay updated on CICT news and activities',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── How it works ────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 14),
                  _StepRow(step: '1', icon: Icons.edit_note_outlined,
                      text: 'Fill out the registration form'),
                  const SizedBox(height: 10),
                  _StepRow(step: '2', icon: Icons.manage_search_outlined,
                      text: 'Admin reviews your request'),
                  const SizedBox(height: 10),
                  _StepRow(step: '3', icon: Icons.check_circle_outline_rounded,
                      text: 'Get approved and access events'),
                  const SizedBox(height: 10),
                  _StepRow(step: '4', icon: Icons.qr_code_2_rounded,
                      text: 'Use your QR pass for attendance'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATE 2 — PENDING / REJECTED (clean profile-style layout)
// ─────────────────────────────────────────────────────────────
class _PendingRejectedScreen extends StatelessWidget {
  final String               docId;
  final Map<String, dynamic> data;
  final String               status;
  final VoidCallback         onWithdraw;

  const _PendingRejectedScreen({
    required this.docId,
    required this.data,
    required this.status,
    required this.onWithdraw,
  });

  String get _displayName => (data['userName'] as String?) ?? 'Guest';
  String get _email       => (data['email']    as String?) ?? '';
  String get _school      => (data['university'] as String?) ?? '';
  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'G';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    final statusColor = isPending ? _kWarning : _kError;
    final statusBg    = isPending ? _kWarningBg : _kErrorBg;
    final statusLabel = isPending ? 'PENDING REVIEW' : 'REJECTED';
    final statusIcon  = isPending
        ? Icons.hourglass_top_rounded
        : Icons.cancel_outlined;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Profile',
            style: GoogleFonts.beVietnamPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: const _AppBarLine(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header card (mirrors student profile header) ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  // Avatar with initials
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kOrangeLight,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _kOrange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_displayName,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(_school.isNotEmpty ? _school : 'External Applicant',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(_email,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: _kOrange)),
                  const SizedBox(height: 16),

                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusLabel,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Status message ──────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request Status',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: statusColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(statusIcon, size: 18, color: statusColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isPending
                                ? 'Your request is currently under review by the CICT admin team. This usually takes 1–2 business days.'
                                : 'Your request was not approved. ${(data['reviewNote'] as String?)?.isNotEmpty == true ? (data['reviewNote'] as String) : 'No specific reason was provided.'} You may withdraw and re-apply with updated information.',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: isPending
                                    ? const Color(0xFF78350F)
                                    : const Color(0xFF991B1B),
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Request details ─────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Information',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 14),
                  _ContactRow(
                      icon: Icons.email_outlined,
                      label: 'EMAIL',
                      value: _email.isNotEmpty ? _email : '—'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.school_outlined,
                      label: 'SCHOOL / INSTITUTION',
                      value: _school.isNotEmpty ? _school : '—'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.phone_outlined,
                      label: 'PHONE',
                      value: (data['phone'] as String?)?.isNotEmpty == true
                          ? data['phone'] as String
                          : 'Not provided'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.description_outlined,
                      label: 'PURPOSE',
                      value: (data['purpose'] as String?) ?? '—'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Withdraw / re-apply button ──────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () => _confirmWithdraw(context),
                icon: const Icon(Icons.close, color: _kError),
                label: Text('Withdraw Request',
                    style: GoogleFonts.beVietnamPro(
                        color: _kError,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Withdraw Request?',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800)),
        content: Text(
          'This will delete your pending request. You can re-apply later.',
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    GoogleFonts.beVietnamPro(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('external_requests')
                  .doc(docId)
                  .delete();
              onWithdraw();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Withdraw',
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATE 3 — APPROVED PROFILE (mirrors StudentProfileScreen)
// ─────────────────────────────────────────────────────────────
class _ApprovedProfileScreen extends StatelessWidget {
  final String               docId;
  final Map<String, dynamic> data;
  final VoidCallback         onWithdraw;

  const _ApprovedProfileScreen({
    required this.docId,
    required this.data,
    required this.onWithdraw,
  });

  String get _fullName  => (data['userName']   as String?) ?? 'Guest';
  String get _email     => (data['email']       as String?) ?? '';
  String get _school    => (data['university']  as String?) ?? '';
  String get _phone     => (data['phone']       as String?) ?? '';
  String get _course    => (data['course']      as String?) ?? '';
  String get _firstName => (data['firstName']   as String?) ?? _fullName.split(' ').first;
  String get _lastName  => (data['lastName']    as String?) ?? (_fullName.split(' ').length > 1 ? _fullName.split(' ').last : '');
  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return _fullName.isNotEmpty ? _fullName[0].toUpperCase() : 'G';
  }

  /// QR payload mirrors GuestEventPass.qrPayload format for the profile pass
  String get _qrPayload =>
      'UPRISE|GUEST|$docId|${_firstName.toUpperCase()}|${_lastName.toUpperCase()}|$_email';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Profile',
            style: GoogleFonts.beVietnamPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: _kOrange),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _GuestSettingsScreen(
                  fullName:   _fullName,
                  email:      _email,
                  school:     _school,
                  onWithdraw: onWithdraw,
                ),
              ),
            ),
          ),
        ],
        bottom: const _AppBarLine(),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header — mirrors StudentProfileScreen header ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  vertical: 24, horizontal: 16),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kOrangeLight,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: _kOrange),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_fullName,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(_school.isNotEmpty ? _school : 'External Guest',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(_email,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: _kOrange)),
                  const SizedBox(height: 4),
                  // Approved badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSuccessBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _kSuccess.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 12, color: _kSuccess),
                        const SizedBox(width: 5),
                        Text('VERIFIED GUEST',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _kSuccess,
                                letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons row — mirrors student profile
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _openQrPass(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('My QR Pass',
                              style: GoogleFonts.beVietnamPro(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: _kOrangeLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          onPressed: () => _openQrFullscreen(context),
                          icon: const Icon(Icons.qr_code_2_rounded,
                              color: _kOrange, size: 22),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── QR Attendance Pass card ─────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Attendance QR Pass',
                          style: GoogleFonts.beVietnamPro(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      GestureDetector(
                        onTap: () => _openQrPass(context),
                        child: Text('View Full',
                            style: GoogleFonts.beVietnamPro(
                                color: _kOrange, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InlineQrCard(
                    fullName:   _fullName,
                    email:      _email,
                    school:     _school,
                    qrPayload:  _qrPayload,
                    docId:      docId,
                    onTap:      () => _openQrPass(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Contact Information ─────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact Information',
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 14),
                  _ContactRow(
                      icon: Icons.email_outlined,
                      label: 'EMAIL',
                      value: _email.isNotEmpty ? _email : '—'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.phone_outlined,
                      label: 'PHONE',
                      value: _phone.isNotEmpty ? _phone : 'Not provided'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.school_outlined,
                      label: 'INSTITUTION',
                      value: _school.isNotEmpty ? _school : '—'),
                  const SizedBox(height: 12),
                  _ContactRow(
                      icon: Icons.menu_book_outlined,
                      label: 'COURSE / PROGRAM',
                      value: _course.isNotEmpty ? _course : 'Not provided'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Logout ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, color: _kOrange),
                label: Text('Log Out',
                    style: GoogleFonts.beVietnamPro(
                        color: _kOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openQrPass(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrPassScreen(
          fullName:  _fullName,
          email:     _email,
          school:    _school,
          phone:     _phone,
          course:    _course,
          docId:     docId,
          qrPayload: _qrPayload,
        ),
      ),
    );
  }

  void _openQrFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenQrScreen(
          fullName:  _fullName,
          qrPayload: _qrPayload,
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out?',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800)),
        content: Text(
          'You will be returned to the guest landing screen.',
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    GoogleFonts.beVietnamPro(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              onWithdraw(); // clears pref → back to not-registered state
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Log Out',
                style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  INLINE QR CARD (compact preview on profile)
// ─────────────────────────────────────────────────────────────
class _InlineQrCard extends StatelessWidget {
  final String   fullName;
  final String   email;
  final String   school;
  final String   qrPayload;
  final String   docId;
  final VoidCallback onTap;

  const _InlineQrCard({
    required this.fullName,
    required this.email,
    required this.school,
    required this.qrPayload,
    required this.docId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  color: _kOrange, shape: BoxShape.circle),
                              child: const Icon(
                                  Icons.local_fire_department,
                                  color: Colors.white, size: 12),
                            ),
                            const SizedBox(width: 5),
                            Text('UPRISE',
                                style: GoogleFonts.beVietnamPro(
                                    color: _kOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 1.2)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(fullName,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87)),
                        const SizedBox(height: 2),
                        Text('VERIFIED GUEST',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _kSuccess,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 10, color: Colors.grey)),
                        if (school.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(school,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 10, color: Colors.grey)),
                        ],
                        const SizedBox(height: 8),
                        Text('ID: ${docId.substring(0, 8).toUpperCase()}…',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 9,
                                color: const Color(0xFFAAAAAA),
                                letterSpacing: 0.3)),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // QR code
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFEEEEEE)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: QrImageView(
                          data:            qrPayload,
                          version:         QrVersions.auto,
                          size:            90,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color:    _kDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color:           _kDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_full_rounded,
                              size: 9, color: _kOrange),
                          const SizedBox(width: 2),
                          Text('Tap to enlarge',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 8,
                                  color: _kOrange,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Bottom strip
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient:
                    LinearGradient(colors: [_kOrange, Color(0xFFFF9A4D)]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  QR PASS SCREEN (full-page pass, like guest_qr_attendance_screen)
// ─────────────────────────────────────────────────────────────
class _QrPassScreen extends StatelessWidget {
  final String fullName;
  final String email;
  final String school;
  final String phone;
  final String course;
  final String docId;
  final String qrPayload;

  const _QrPassScreen({
    required this.fullName,
    required this.email,
    required this.school,
    required this.phone,
    required this.course,
    required this.docId,
    required this.qrPayload,
  });

  @override
  Widget build(BuildContext context) {
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
        title: Text('My QR Pass',
            style: GoogleFonts.beVietnamPro(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: const _AppBarLine(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kOrange.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: _kOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Show this QR pass to event staff to record your attendance.',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: const Color(0xFF7A3300)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Pass card
            _FullPassCard(
              fullName:  fullName,
              email:     email,
              school:    school,
              phone:     phone,
              course:    course,
              docId:     docId,
              qrPayload: qrPayload,
              onFullscreen: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullscreenQrScreen(
                    fullName:  fullName,
                    qrPayload: qrPayload,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Fullscreen hint
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullscreenQrScreen(
                    fullName:  fullName,
                    qrPayload: qrPayload,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFEEEEEE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_full_rounded,
                        size: 16, color: _kOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap to show full-screen QR for easy scanning',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Download button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('Pass saved to your gallery',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13)),
                        ],
                      ),
                      backgroundColor: _kOrange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text('Download Pass',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FULL PASS CARD  (ticket-style with QR)
// ─────────────────────────────────────────────────────────────
class _FullPassCard extends StatelessWidget {
  final String   fullName;
  final String   email;
  final String   school;
  final String   phone;
  final String   course;
  final String   docId;
  final String   qrPayload;
  final VoidCallback onFullscreen;

  const _FullPassCard({
    required this.fullName,
    required this.email,
    required this.school,
    required this.phone,
    required this.course,
    required this.docId,
    required this.qrPayload,
    required this.onFullscreen,
  });

  String get _initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'G';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: _kOrange.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Top: branding + identity
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: _kOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.local_fire_department,
                                color: Colors.white, size: 13),
                          ),
                          const SizedBox(width: 6),
                          Text('UPRISE',
                              style: GoogleFonts.beVietnamPro(
                                  color: _kOrange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 1.4)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${docId.substring(0, 8).toUpperCase()}…',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 10,
                            color: const Color(0xFF999999),
                            letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fullName.toUpperCase(),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                            letterSpacing: 0.3,
                            height: 1.15),
                      ),
                      const SizedBox(height: 2),
                      Text('VERIFIED GUEST',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _kSuccess,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(email,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              color: const Color(0xFFAAAAAA),
                              letterSpacing: 0.2)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar initial
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _kOrangeLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _kOrange.withOpacity(0.2), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _kOrange),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dashed divider
          _DashedDivider(),

          // Bottom: details + QR
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (school.isNotEmpty) ...[
                        _CardDetailRow(label: 'SCHOOL', value: school),
                        const SizedBox(height: 6),
                      ],
                      if (phone.isNotEmpty) ...[
                        _CardDetailRow(label: 'PHONE', value: phone),
                        const SizedBox(height: 6),
                      ],
                      if (course.isNotEmpty) ...[
                        _CardDetailRow(label: 'COURSE', value: course),
                        const SizedBox(height: 6),
                      ],
                      _CardDetailRow(label: 'TYPE', value: 'External Guest'),
                      const SizedBox(height: 10),
                      // Verified chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kSuccessBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _kSuccess.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 10, color: _kSuccess),
                            const SizedBox(width: 4),
                            Text('APPROVED',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _kSuccess,
                                    letterSpacing: 0.6)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // QR code
                GestureDetector(
                  onTap: onFullscreen,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFEEEEEE)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: QrImageView(
                          data:            qrPayload,
                          version:         QrVersions.auto,
                          size:            100,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color:    _kDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color:           _kDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_full_rounded,
                              size: 10, color: _kOrange),
                          const SizedBox(width: 3),
                          Text('Tap to enlarge',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 9,
                                  color: _kOrange,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom orange strip
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [_kOrange, Color(0xFFFF9A4D)]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FULLSCREEN QR SCREEN
// ─────────────────────────────────────────────────────────────
class _FullscreenQrScreen extends StatelessWidget {
  final String fullName;
  final String qrPayload;

  const _FullscreenQrScreen({
    required this.fullName,
    required this.qrPayload,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back,
                size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Scan to Record Attendance',
            style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            fullName.toUpperCase(),
            style: GoogleFonts.beVietnamPro(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('VERIFIED GUEST',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  color: _kOrange,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: _kOrange.withOpacity(0.25),
                    blurRadius: 40,
                    spreadRadius: 5),
              ],
            ),
            child: QrImageView(
              data:            qrPayload,
              version:         QrVersions.auto,
              size:            240,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color:    _kDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color:           _kDark,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: _kOrange, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Show to event staff for scanning',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12, color: Colors.white54)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GUEST SETTINGS SCREEN (mirrors SettingsScreen from student)
// ─────────────────────────────────────────────────────────────
class _GuestSettingsScreen extends StatelessWidget {
  final String       fullName;
  final String       email;
  final String       school;
  final VoidCallback onWithdraw;

  const _GuestSettingsScreen({
    required this.fullName,
    required this.email,
    required this.school,
    required this.onWithdraw,
  });

  String get _initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'G';
  }

  @override
  Widget build(BuildContext context) {
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: const _AppBarLine(),
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
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: _kOrange)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(fullName,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(school,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kSuccessBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('VERIFIED GUEST',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kSuccess,
                            letterSpacing: 0.6)),
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
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy',
                    subtitle: 'Data and privacy settings',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact info',
                    onTap: () {},
                  ),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About UPRISE',
                    subtitle: 'App version and information',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Logout ──────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close settings first
                  onWithdraw();           // then trigger logout
                },
                icon: const Icon(Icons.logout, color: _kOrange),
                label: Text('Log Out',
                    style: GoogleFonts.beVietnamPro(
                        color: _kOrange,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  REGISTRATION SCREEN (3-step form — unchanged logic)
// ─────────────────────────────────────────────────────────────
class _RegistrationScreen extends StatefulWidget {
  final Future<void> Function(String docId) onSubmitted;
  const _RegistrationScreen({required this.onSubmitted});

  @override
  State<_RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<_RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _schoolCtrl    = TextEditingController();
  final _courseCtrl    = TextEditingController();
  final _reasonCtrl    = TextEditingController();

  bool _isLoading   = false;
  int  _currentStep = 0;

  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl,
                     _phoneCtrl, _schoolCtrl, _courseCtrl, _reasonCtrl]) {
      c.dispose();
    }
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_firstNameCtrl.text.trim().isEmpty ||
          _lastNameCtrl.text.trim().isEmpty  ||
          _emailCtrl.text.trim().isEmpty     ||
          !_emailCtrl.text.contains('@')) {
        _snack('Please complete all personal information fields.');
        return;
      }
    }
    if (_currentStep == 1) {
      if (_schoolCtrl.text.trim().isEmpty ||
          _reasonCtrl.text.trim().isEmpty) {
        _snack('Please complete all fields before proceeding.');
        return;
      }
      if (_reasonCtrl.text.trim().length < 20) {
        _snack('Please describe your purpose in at least 20 characters.');
        return;
      }
    }
    _fadeCtrl.reset();
    setState(() => _currentStep++);
    _fadeCtrl.forward();
    _scrollCtrl.animateTo(0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut);
  }

  void _prevStep() {
    _fadeCtrl.reset();
    setState(() => _currentStep--);
    _fadeCtrl.forward();
  }

  void _snack(String msg, {Color bg = _kError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro(fontSize: 13)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Duplicate check
      final dup = await FirebaseFirestore.instance
          .collection('external_requests')
          .where('email', isEqualTo: email)
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _snack('A request with this email already exists.',
              bg: _kWarning);
          await widget.onSubmitted(dup.docs.first.id);
          if (mounted) Navigator.pop(context);
        }
        return;
      }

      final userName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      final docRef = await FirebaseFirestore.instance
          .collection('external_requests')
          .add({
        'userId'      : '',
        'userName'    : userName,
        'email'       : email,
        'university'  : _schoolCtrl.text.trim(),
        'purpose'     : _reasonCtrl.text.trim(),
        'status'      : 'pending',
        'requestDate' : FieldValue.serverTimestamp(),
        'firstName'   : _firstNameCtrl.text.trim(),
        'lastName'    : _lastNameCtrl.text.trim(),
        'phone'       : _phoneCtrl.text.trim(),
        'course'      : _courseCtrl.text.trim(),
        'type'        : 'guest',
      });

      if (mounted) {
        setState(() => _isLoading = false);
        await widget.onSubmitted(docRef.id);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Submission failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Guest Registration',
            style: GoogleFonts.beVietnamPro(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        bottom: const _AppBarLine(),
      ),
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _StepIndicator(current: _currentStep),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStep(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0:
        return _PersonalStep(
          firstNameCtrl: _firstNameCtrl,
          lastNameCtrl:  _lastNameCtrl,
          emailCtrl:     _emailCtrl,
          phoneCtrl:     _phoneCtrl,
          onNext:        _nextStep,
        );
      case 1:
        return _DetailsStep(
          schoolCtrl: _schoolCtrl,
          courseCtrl: _courseCtrl,
          reasonCtrl: _reasonCtrl,
          onNext:     _nextStep,
          onBack:     _prevStep,
        );
      case 2:
        return _ReviewStep(
          firstName: _firstNameCtrl.text.trim(),
          lastName:  _lastNameCtrl.text.trim(),
          email:     _emailCtrl.text.trim(),
          phone:     _phoneCtrl.text.trim(),
          school:    _schoolCtrl.text.trim(),
          course:    _courseCtrl.text.trim(),
          reason:    _reasonCtrl.text.trim(),
          isLoading: _isLoading,
          onSubmit:  _submit,
          onBack:    _prevStep,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  REGISTRATION STEP WIDGETS (unchanged logic, cleaner style)
// ─────────────────────────────────────────────────────────────
class _PersonalStep extends StatelessWidget {
  final TextEditingController firstNameCtrl, lastNameCtrl, emailCtrl, phoneCtrl;
  final VoidCallback onNext;
  const _PersonalStep({
    required this.firstNameCtrl, required this.lastNameCtrl,
    required this.emailCtrl,     required this.phoneCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FormCard(title: 'Personal Information', icon: Icons.person_outline_rounded,
          children: [
            Row(children: [
              Expanded(child: _Field(label: 'First Name', controller: firstNameCtrl,
                  hint: 'Juan', icon: Icons.badge_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _Field(label: 'Last Name', controller: lastNameCtrl,
                  hint: 'Dela Cruz', icon: Icons.badge_outlined)),
            ]),
            const SizedBox(height: 14),
            _Field(label: 'Email Address', controller: emailCtrl,
                hint: 'your@email.com', icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _Field(label: 'Phone Number', controller: phoneCtrl,
                hint: '+63 9XX XXX XXXX', icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone, isRequired: false),
          ]),
      const SizedBox(height: 20),
      _PrimaryBtn(label: 'Next: Details →', onTap: onNext),
    ]);
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController schoolCtrl, courseCtrl, reasonCtrl;
  final VoidCallback onNext, onBack;
  const _DetailsStep({
    required this.schoolCtrl, required this.courseCtrl,
    required this.reasonCtrl, required this.onNext, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FormCard(title: 'School / Affiliation', icon: Icons.school_outlined,
          children: [
            _Field(label: 'School or Institution', controller: schoolCtrl,
                hint: 'e.g. BulSU, DLSU, PLM, FEU',
                icon: Icons.account_balance_outlined),
            const SizedBox(height: 14),
            _Field(label: 'Program / Course', controller: courseCtrl,
                hint: 'e.g. BSIT, BSCS, BSCPE',
                icon: Icons.menu_book_outlined, isRequired: false),
          ]),
      const SizedBox(height: 14),
      _FormCard(title: 'Purpose', icon: Icons.description_outlined,
          children: [
            _Field(
              label: 'Why do you want to join CICT events?',
              controller: reasonCtrl,
              hint: 'e.g. Networking, learning new skills…',
              icon: Icons.comment_outlined, maxLines: 4,
            ),
          ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _SecondaryBtn(label: '← Back', onTap: onBack)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _PrimaryBtn(label: 'Review →', onTap: onNext)),
      ]),
    ]);
  }
}

class _ReviewStep extends StatelessWidget {
  final String firstName, lastName, email, phone, school, course, reason;
  final bool isLoading;
  final VoidCallback onSubmit, onBack;
  const _ReviewStep({
    required this.firstName, required this.lastName, required this.email,
    required this.phone,     required this.school,   required this.course,
    required this.reason,    required this.isLoading,
    required this.onSubmit,  required this.onBack,
  });

  String get _initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    return firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Preview header
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _kOrangeLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kOrange.withOpacity(0.3), width: 1.5),
            ),
            child: Center(child: Text(_initials,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: _kOrange))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('$firstName $lastName',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            const SizedBox(height: 2),
            Text(email, style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kOrangeLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kOrange.withOpacity(0.3)),
              ),
              child: Text('EXTERNAL APPLICANT',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _kOrange, letterSpacing: 0.8)),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      _ReviewGroup(title: 'Contact', rows: [
        _ReviewPair('Phone', phone.isEmpty ? 'Not provided' : phone),
      ]),
      const SizedBox(height: 10),
      _ReviewGroup(title: 'Affiliation', rows: [
        _ReviewPair('School', school),
        _ReviewPair('Course', course.isEmpty ? 'Not provided' : course),
      ]),
      const SizedBox(height: 10),
      _ReviewGroup(title: 'Purpose', rows: [
        _ReviewPair('Reason', reason),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kWarningBg, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kWarning.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.hourglass_top_rounded, size: 16, color: _kWarning),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'After submission your request will be reviewed by the CICT admin.',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: const Color(0xFF78350F), height: 1.5),
          )),
        ]),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _SecondaryBtn(
            label: '← Edit', onTap: isLoading ? null : onBack)),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: _PrimaryBtn(
          label: isLoading ? 'Submitting…' : 'Submit Request',
          onTap: isLoading ? null : onSubmit,
          isLoading: isLoading,
        )),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _AppBarLine extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarLine();

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F0F0));
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   sub;
  const _BenefitRow(
      {required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kOrangeLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: _kOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            Text(sub,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11, color: Colors.grey)),
          ]),
        ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Colors.grey.shade100);
}

class _StepRow extends StatelessWidget {
  final String   step;
  final IconData icon;
  final String   text;
  const _StepRow(
      {required this.step, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration:
            const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
        child: Center(
          child: Text(step,
              style: GoogleFonts.beVietnamPro(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kOrangeLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: _kOrange),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: Colors.black87)),
      ),
    ]);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,     required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: _kOrange),
      title: Text(title,
          style: GoogleFonts.beVietnamPro(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _FormCard extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;
  const _FormCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(
                  color: _kOrange, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: _kOrange),
          const SizedBox(width: 6),
          Text(title,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: Colors.black87)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}

class _ReviewGroup extends StatelessWidget {
  final String          title;
  final List<_ReviewPair> rows;
  const _ReviewGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: GoogleFonts.beVietnamPro(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: Colors.grey, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...rows,
      ]),
    );
  }
}

class _ReviewPair extends StatelessWidget {
  final String label, value;
  const _ReviewPair(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 70,
            child: Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: Colors.grey))),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: Colors.black87,
                fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  final String  label;
  final String  value;
  final TextStyle? valueStyle;
  const _CardDetailRow(
      {required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 46,
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFAAAAAA),
                letterSpacing: 0.5)),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(value,
            style: valueStyle ??
                GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
      ),
    ]);
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration:
                const BoxDecoration(color: _kBg, shape: BoxShape.circle),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              child: const SizedBox(height: 1),
            ),
          ),
          Container(
            width: 12, height: 12,
            decoration:
                const BoxDecoration(color: _kBg, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = const Color(0xFFEEEEEE)
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    const dashW = 6.0;
    const gapW  = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(math.min(startX + dashW, size.width), 0),
        paint,
      );
      startX += dashW + gapW;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  static const _labels = ['Personal Info', 'Details', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = current > i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: done ? _kOrange : const Color(0xFFE2E8F0),
              ),
            );
          }
          final idx      = i ~/ 2;
          final isActive = current == idx;
          final isDone   = current > idx;
          return Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isDone ? _kSuccess
                    : isActive ? _kOrange
                    : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text('${idx + 1}',
                        style: GoogleFonts.beVietnamPro(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 4),
            Text(_labels[idx],
                style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    fontWeight: (isActive || isDone)
                        ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? _kOrange
                        : isDone ? _kSuccess
                        : const Color(0xFF94A3B8))),
          ]);
        }),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String                label;
  final TextEditingController controller;
  final String                hint;
  final IconData              icon;
  final TextInputType?        keyboardType;
  final int                   maxLines;
  final bool                  isRequired;

  const _Field({
    required this.label,   required this.controller,
    required this.hint,    required this.icon,
    this.keyboardType,     this.maxLines   = 1,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: Colors.black87)),
        if (isRequired)
          Text(' *', style: GoogleFonts.beVietnamPro(
              fontSize: 12, color: _kOrange)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller:   controller,
        keyboardType: keyboardType,
        maxLines:     maxLines,
        style: GoogleFonts.beVietnamPro(
            fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(
              fontSize: 13, color: const Color(0xFFBBBBBB)),
          prefixIcon: maxLines == 1
              ? Icon(icon, size: 18, color: Colors.grey) : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: maxLines > 1 ? 14 : 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: _kOrange, width: 1.5)),
        ),
      ),
    ]);
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  final bool          isLoading;
  const _PrimaryBtn(
      {required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onTap == null ? Colors.grey.shade300 : _kOrange,
          foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Text(label, style: GoogleFonts.beVietnamPro(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final String        label;
  final VoidCallback? onTap;
  const _SecondaryBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black54,
          side: const BorderSide(
              color: Color(0xFFE2E8F0), width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}