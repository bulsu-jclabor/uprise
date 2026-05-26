// lib/screens/guest/guest_qr_attendance_screen.dart
//
// GUEST MODE – Event Attendance QR Pass
//
// The guest SHOWS this screen to event staff who scan it.
// Concept: a digital attendance pass / ticket card (like Frame 22
// "Personal Identity") that contains a QR code encoding the guest's
// ticket data. Staff scan it; attendance is recorded.
//
// Dependency required → add to pubspec.yaml:
//   qr_flutter: ^4.1.0
//

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFFFF6B00);
const _kPrimaryBg = Color(0xFFFFF3EB);
const _kBg        = Color(0xFFF5F5F5);
const _kDark      = Color(0xFF1A1A2E);

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────

/// Holds the data for a single event registration pass.
class GuestEventPass {
  final String ticketCode;
  final String firstName;
  final String lastName;
  final String email;
  final String eventId;
  final String eventTitle;
  final String eventDate;
  final String eventTime;
  final String eventLocation;
  final String organizer;
  final bool   isVerified;

  const GuestEventPass({
    required this.ticketCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.eventId,
    required this.eventTitle,
    required this.eventDate,
    required this.eventTime,
    required this.eventLocation,
    required this.organizer,
    this.isVerified = false,
  });

  String get fullName => '$lastName, $firstName'.toUpperCase();

  /// The data encoded into the QR code (pipe-delimited for easy parsing).
  String get qrPayload =>
      'UPRISE|$ticketCode|$eventId|${firstName.toUpperCase()}|${lastName.toUpperCase()}|$email';
}

// ── Sample passes (replace with real Firestore data) ──────────
final _samplePasses = [
  const GuestEventPass(
    ticketCode:    'EVT-2025-001-G-0042',
    firstName:     'Juan',
    lastName:      'Dela Cruz',
    email:         'juan@email.com',
    eventId:       'EVT-2025-001',
    eventTitle:    'TechTalk 2025',
    eventDate:     'November 10, 2025',
    eventTime:     '9:00 AM – 5:00 PM',
    eventLocation: 'CICT Auditorium, PUP Manila',
    organizer:     'SPECS – Society of Programming Enthusiasts',
  ),
];

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class GuestQrAttendanceScreen extends StatefulWidget {
  const GuestQrAttendanceScreen({super.key});

  @override
  State<GuestQrAttendanceScreen> createState() =>
      _GuestQrAttendanceScreenState();
}

class _GuestQrAttendanceScreenState
    extends State<GuestQrAttendanceScreen>
    with SingleTickerProviderStateMixin {

  // Replace with real passes fetched from Firestore by the guest's email.
  final List<GuestEventPass> _passes = _samplePasses;
  int _selectedIndex = 0;

  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  GuestEventPass? get _currentPass =>
      _passes.isNotEmpty ? _passes[_selectedIndex] : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Attendance Pass',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
      ),
      body: _passes.isEmpty
          ? const _NoPassView()
          : _PassView(
              passes:         _passes,
              selectedIndex:  _selectedIndex,
              shimmerAnim:    _shimmerAnim,
              onSelectPass:   (i) => setState(() => _selectedIndex = i),
              onDownload:     () => _onDownload(context),
              onFullscreen:   () => _openFullscreen(context),
            ),
    );
  }

  void _onDownload(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Pass saved to your gallery'),
          ],
        ),
        backgroundColor: _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    if (_currentPass == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenQrScreen(pass: _currentPass!),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PASS VIEW  (main content when passes exist)
// ─────────────────────────────────────────────────────────────
class _PassView extends StatelessWidget {
  final List<GuestEventPass> passes;
  final int                  selectedIndex;
  final Animation<double>    shimmerAnim;
  final ValueChanged<int>    onSelectPass;
  final VoidCallback         onDownload;
  final VoidCallback         onFullscreen;

  const _PassView({
    required this.passes,
    required this.selectedIndex,
    required this.shimmerAnim,
    required this.onSelectPass,
    required this.onDownload,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final pass = passes[selectedIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Instruction banner ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPrimaryBg,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _kPrimary.withOpacity(0.25)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: _kPrimary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show this pass to event staff to record your attendance.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF7A3300)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Event selector (if multiple passes) ────────────
          if (passes.length > 1) ...[
            const _SectionLabel(text: 'YOUR REGISTRATIONS'),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: passes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isActive = i == selectedIndex;
                  return GestureDetector(
                    onTap: () => onSelectPass(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? _kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isActive ? _kPrimary : const Color(0xFFDDDDDD),
                        ),
                      ),
                      child: Text(
                        passes[i].eventTitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── PASS CARD ──────────────────────────────────────
          const _SectionLabel(text: 'ATTENDANCE PASS'),
          const SizedBox(height: 10),

          _PassCard(
            pass:         pass,
            shimmerAnim:  shimmerAnim,
            onFullscreen: onFullscreen,
          ),

          const SizedBox(height: 18),

          // ── QR enlargement hint ────────────────────────────
          GestureDetector(
            onTap: onFullscreen,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.open_in_full_rounded,
                      size: 16, color: _kPrimary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tap to show full-screen QR for easy scanning',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Download button ────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'Download Pass',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── How it works ───────────────────────────────────
          _HowItWorksCard(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PASS CARD  (the ID-card-style ticket)
// ─────────────────────────────────────────────────────────────
class _PassCard extends StatelessWidget {
  final GuestEventPass    pass;
  final Animation<double> shimmerAnim;
  final VoidCallback      onFullscreen;

  const _PassCard({
    required this.pass,
    required this.shimmerAnim,
    required this.onFullscreen,
  });

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
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _kPrimary.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Card top section ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: branding + identity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UPRISE logo row
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: _kPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'UPRISE',
                            style: TextStyle(
                              color: _kPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),
                      Text(
                        'ID: ${pass.ticketCode}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF999999),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 10),
                      Text(
                        pass.fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'GUEST',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pass.email,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFAAAAAA),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Right: avatar initial
                Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _kPrimaryBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kPrimary.withOpacity(0.2),
                            width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          pass.firstName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _kPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Dashed divider ────────────────────────────────
          _DashedDivider(),

          // ── Card bottom section: event info + QR ─────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CardDetailRow(
                        label: 'EVENT',
                        value: pass.eventTitle,
                        valueStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CardDetailRow(
                        label: 'DATE',
                        value: pass.eventDate,
                      ),
                      const SizedBox(height: 6),
                      _CardDetailRow(
                        label: 'TIME',
                        value: pass.eventTime,
                      ),
                      const SizedBox(height: 6),
                      _CardDetailRow(
                        label: 'VENUE',
                        value: pass.eventLocation,
                      ),
                      const SizedBox(height: 6),
                      _CardDetailRow(
                        label: 'ORG',
                        value: pass.organizer,
                      ),
                      const SizedBox(height: 10),

                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF81C784)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle,
                                size: 10,
                                color: Color(0xFF2E7D32)),
                            SizedBox(width: 4),
                            Text(
                              'REGISTERED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                                letterSpacing: 0.6,
                              ),
                            ),
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data:            pass.qrPayload,
                          version:         QrVersions.auto,
                          size:            100,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape:  QrEyeShape.square,
                            color:     _kDark,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color:           _kDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Expand hint
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.open_in_full_rounded,
                              size: 10, color: _kPrimary),
                          SizedBox(width: 3),
                          Text(
                            'Tap to enlarge',
                            style: TextStyle(
                                fontSize: 9,
                                color: _kPrimary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Orange bottom strip ───────────────────────────
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kPrimary, Color(0xFFFF9A4D)],
              ),
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
  final GuestEventPass pass;
  const _FullscreenQrScreen({required this.pass});

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
        title: const Text(
          'Scan to Record Attendance',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Name + event
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  pass.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  pass.eventTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // QR Code
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: QrImageView(
              data:            pass.qrPayload,
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

          // Ticket code
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withOpacity(0.15)),
            ),
            child: Text(
              pass.ticketCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Show to event staff for scanning',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  NO PASS VIEW  (no registrations yet)
// ─────────────────────────────────────────────────────────────
class _NoPassView extends StatelessWidget {
  const _NoPassView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _kPrimaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_2_rounded,
                  size: 50, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Event Pass Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register for a public event to get your\nattendance QR pass.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _NoPassStep(
                    step: '1',
                    icon: Icons.calendar_today_outlined,
                    text: 'Go to the Events tab',
                  ),
                  const SizedBox(height: 10),
                  _NoPassStep(
                    step: '2',
                    icon: Icons.app_registration_rounded,
                    text: 'Register for a public event',
                  ),
                  const SizedBox(height: 10),
                  _NoPassStep(
                    step: '3',
                    icon: Icons.email_outlined,
                    text: 'Verify with your email OTP',
                  ),
                  const SizedBox(height: 10),
                  _NoPassStep(
                    step: '4',
                    icon: Icons.qr_code_2_rounded,
                    text: 'Your pass appears here',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoPassStep extends StatelessWidget {
  final String   step;
  final IconData icon;
  final String   text;
  const _NoPassStep(
      {required this.step, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
              color: _kPrimary, shape: BoxShape.circle),
          child: Center(
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _kPrimaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _kPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HOW IT WORKS
// ─────────────────────────────────────────────────────────────
class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'HOW TO USE THIS PASS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF888888),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HowStep(
            icon:  Icons.open_in_full_rounded,
            title: 'Enlarge the QR code',
            sub:   'Tap the QR or the fullscreen button.',
          ),
          const SizedBox(height: 10),
          _HowStep(
            icon:  Icons.person_search_outlined,
            title: 'Show it to event staff',
            sub:   'Staff will scan it with the UPRISE admin app.',
          ),
          const SizedBox(height: 10),
          _HowStep(
            icon:  Icons.check_circle_outline_rounded,
            title: 'Attendance recorded',
            sub:   'Your attendance is saved instantly.',
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   sub;
  const _HowStep(
      {required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _kPrimaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  )),
              const SizedBox(height: 1),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF888888),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _CardDetailRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFFAAAAAA),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Left notch
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: _kBg,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              child: const SizedBox(height: 1),
            ),
          ),
          // Right notch
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: _kBg,
              shape: BoxShape.circle,
            ),
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

    const dashW   = 6.0;
    const gapW    = 4.0;
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