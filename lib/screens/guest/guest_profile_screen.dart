// lib/screens/guest/guest_profile_screen.dart
//
// GUEST PROFILE — Registration + Approval Status
//
// Writes to the `external_requests` collection that the admin
// ExternalAccount panel already reads from. Field mapping:
//
//   ExternalRequest model   ← what this screen writes
//   ─────────────────────────────────────────────────
//   userId                  ← '' (no auth for guests)
//   userName                ← '$firstName $lastName'
//   email                   ← email
//   university              ← school  (guest's institution)
//   purpose                 ← reason
//   status                  ← 'pending'
//   requestDate             ← FieldValue.serverTimestamp()
//
// Extra fields stored but not shown in admin table (harmless):
//   firstName, lastName, phone, course
//
// Dependencies: cloud_firestore, google_fonts, shared_preferences
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFFFF6B00);
const _kPrimaryBg = Color(0xFFFFF3EB);
const _kDark      = Color(0xFF1A1A2E);
const _kBg        = Color(0xFFF5F7FA);
const _kSuccess   = Color(0xFF059669);
const _kSuccessBg = Color(0xFFECFDF5);
const _kWarning   = Color(0xFFD97706);
const _kWarningBg = Color(0xFFFFFBEB);
const _kError     = Color(0xFFDC2626);
const _kErrorBg   = Color(0xFFFEF2F2);

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
        body: Center(child: CircularProgressIndicator(color: _kPrimary)),
      );
    }
    if (_savedDocId != null) {
      return _StatusScreen(docId: _savedDocId!, onWithdraw: _onWithdraw);
    }
    return _RegistrationScreen(onSubmitted: _onSubmitted);
  }
}

// ─────────────────────────────────────────────────────────────
//  REGISTRATION SCREEN
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
  final _schoolCtrl    = TextEditingController();  // → university
  final _courseCtrl    = TextEditingController();
  final _reasonCtrl    = TextEditingController();  // → purpose

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
      if (_schoolCtrl.text.trim().isEmpty || _reasonCtrl.text.trim().isEmpty) {
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
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      // Duplicate check — same email + pending or approved
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
        }
        return;
      }

      // Write document — field names match ExternalRequest.fromFirestore()
      final userName =
          '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      final docRef = await FirebaseFirestore.instance
          .collection('external_requests')
          .add({
        // ── Core fields read by admin ExternalAccount panel ──
        'userId'      : '',                       // no Firebase Auth for guests
        'userName'    : userName,
        'email'       : email,
        'university'  : _schoolCtrl.text.trim(),  // guest's school/institution
        'purpose'     : _reasonCtrl.text.trim(),  // reason for applying
        'status'      : 'pending',
        'requestDate' : FieldValue.serverTimestamp(),

        // ── Extra fields (not shown in admin table, but stored) ──
        'firstName'   : _firstNameCtrl.text.trim(),
        'lastName'    : _lastNameCtrl.text.trim(),
        'phone'       : _phoneCtrl.text.trim(),
        'course'      : _courseCtrl.text.trim(),
        'type'        : 'guest',
      });

      if (mounted) {
        setState(() => _isLoading = false);
        await widget.onSubmitted(docRef.id);
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
      body: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text('Guest Account',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFF0F0F0)),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(children: [
                _HeroBanner(),
                const SizedBox(height: 20),
                _StepIndicator(current: _currentStep),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStep(),
                ),
                const SizedBox(height: 32),
              ]),
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
//  STEP WIDGETS
// ─────────────────────────────────────────────────────────────

class _PersonalStep extends StatelessWidget {
  final TextEditingController firstNameCtrl, lastNameCtrl, emailCtrl, phoneCtrl;
  final VoidCallback onNext;
  const _PersonalStep({
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Card(title: 'Personal Information', icon: Icons.person_outline_rounded,
          children: [
            Row(children: [
              Expanded(child: _Field(
                label: 'First Name', controller: firstNameCtrl,
                hint: 'Juan', icon: Icons.badge_outlined,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                label: 'Last Name', controller: lastNameCtrl,
                hint: 'Dela Cruz', icon: Icons.badge_outlined,
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 14),
            _Field(
              label: 'Email Address', controller: emailCtrl,
              hint: 'your@email.com', icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'Phone Number', controller: phoneCtrl,
              hint: '+63 9XX XXX XXXX', icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone, isRequired: false,
            ),
          ]),
      const SizedBox(height: 14),
      _Notice(
        icon: Icons.info_outline_rounded,
        text: 'Your email is used to look up your request status.',
      ),
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
      _Card(title: 'School / Affiliation', icon: Icons.school_outlined,
          children: [
            _Field(
              label: 'School or Institution', controller: schoolCtrl,
              hint: 'e.g. BulSU, DLSU, PLM, FEU',
              icon: Icons.account_balance_outlined,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            _Field(
              label: 'Program / Course', controller: courseCtrl,
              hint: 'e.g. BSIT, BSCS, BSCPE',
              icon: Icons.menu_book_outlined, isRequired: false,
            ),
          ]),
      const SizedBox(height: 14),
      _Card(title: 'Purpose', icon: Icons.description_outlined,
          children: [
            _Field(
              label: 'Why do you want to join CICT events?',
              controller: reasonCtrl,
              hint: 'e.g. Networking, learning new skills, competition…',
              icon: Icons.comment_outlined, maxLines: 4,
              validator: (v) {
                if (v!.trim().isEmpty) return 'Required';
                if (v.trim().length < 20) return 'Min 20 characters';
                return null;
              },
            ),
          ]),
      const SizedBox(height: 14),
      _Notice(
        icon: Icons.shield_outlined,
        text: 'Your information is for event verification only and will '
              'not be shared with third parties.',
      ),
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
    required this.phone,      required this.school,   required this.course,
    required this.reason,     required this.isLoading,
    required this.onSubmit,   required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Avatar preview
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              color: _kPrimaryBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withOpacity(0.3), width: 1.5),
            ),
            child: Center(child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 24, fontWeight: FontWeight.w900, color: _kPrimary),
            )),
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
                color: _kPrimaryBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _kPrimary.withOpacity(0.3)),
              ),
              child: Text('EXTERNAL APPLICANT',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: _kPrimary, letterSpacing: 0.8)),
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
        _ReviewPair('School',   school),
        _ReviewPair('Course',   course.isEmpty ? 'Not provided' : course),
      ]),
      const SizedBox(height: 10),
      _ReviewGroup(title: 'Purpose', rows: [
        _ReviewPair('Reason', reason),
      ]),

      const SizedBox(height: 14),
      _Notice(
        icon: Icons.hourglass_top_rounded,
        color: _kWarning, bgColor: _kWarningBg,
        text: 'After submission your request will be reviewed by the CICT '
              'admin. You will be notified once a decision is made.',
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
//  STATUS SCREEN
// ─────────────────────────────────────────────────────────────
class _StatusScreen extends StatelessWidget {
  final String       docId;
  final VoidCallback onWithdraw;
  const _StatusScreen({required this.docId, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('My Request',
            style: GoogleFonts.beVietnamPro(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.black87)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('external_requests')
            .doc(docId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kPrimary));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return _DeletedView(onReset: onWithdraw);
          }

          final data   = snap.data!.data() as Map<String, dynamic>;
          final status = (data['status'] as String?) ?? 'pending';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(children: [
              _StatusCard(status: status, data: data),
              const SizedBox(height: 14),
              _DetailsCard(data: data),
              const SizedBox(height: 14),
              _TimelineCard(data: data, status: status),
              if (status == 'approved') ...[
                const SizedBox(height: 14),
                _ApprovedCard(),
              ],
              if (status == 'rejected') ...[
                const SizedBox(height: 14),
                _RejectedCard(note: (data['reviewNote'] as String?) ?? ''),
              ],
              if (status == 'pending') ...[
                const SizedBox(height: 22),
                _WithdrawBtn(onTap: () => _confirmWithdraw(context)),
              ],
              const SizedBox(height: 14),
              _Notice(
                icon: Icons.info_outline_rounded,
                text: 'Request ID: ${docId.substring(0, 8).toUpperCase()}…  '
                      'Keep this screen to track your request status.',
              ),
            ]),
          );
        },
      ),
    );
  }

  void _confirmWithdraw(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Withdraw Request?',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800)),
        content: Text(
          'This will delete your pending request. You can re-apply later.',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.beVietnamPro(color: Colors.grey)),
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
              backgroundColor: _kError, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Withdraw',
                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STATUS CARD
// ─────────────────────────────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final String              status;
  final Map<String, dynamic> data;
  const _StatusCard({required this.status, required this.data});

  @override
  Widget build(BuildContext context) {
    final cfg  = _cfgFor(status);
    final name = (data['userName'] as String?) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [cfg.gradStart, cfg.gradEnd],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: cfg.accent.withOpacity(0.25),
            blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: Colors.white, size: 22),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(cfg.badge,
                style: GoogleFonts.beVietnamPro(
                    color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          ),
        ]),
        const SizedBox(height: 16),
        Text(cfg.headline,
            style: GoogleFonts.beVietnamPro(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 6),
        Text(cfg.sub,
            style: GoogleFonts.beVietnamPro(
                color: Colors.white70, fontSize: 13, height: 1.4)),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.person_outline, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            Text(name,
                style: GoogleFonts.beVietnamPro(
                    color: Colors.white70, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

class _Cfg {
  final Color gradStart, gradEnd, accent;
  final IconData icon;
  final String badge, headline, sub;
  const _Cfg(this.gradStart, this.gradEnd, this.accent, this.icon,
      this.badge, this.headline, this.sub);
}

_Cfg _cfgFor(String status) {
  switch (status) {
    case 'approved':
      return const _Cfg(
        Color(0xFF15803D), Color(0xFF166534), Color(0xFF16A34A),
        Icons.verified_rounded, 'APPROVED',
        'You\'re Verified!',
        'Your request is approved. You may now register for '
            'public CICT events.',
      );
    case 'rejected':
      return const _Cfg(
        Color(0xFFB91C1C), Color(0xFF991B1B), Color(0xFFDC2626),
        Icons.cancel_outlined, 'REJECTED',
        'Request Declined',
        'Your request was not approved. See the note below for details.',
      );
    default:
      return const _Cfg(
        Color(0xFFD97706), Color(0xFFB45309), Color(0xFFF59E0B),
        Icons.hourglass_top_rounded, 'PENDING',
        'Under Review',
        'Your request is being reviewed by the CICT admin team.',
      );
  }
}

// ─────────────────────────────────────────────────────────────
//  DETAILS CARD  (mirrors ExternalRequest fields)
// ─────────────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Your Request',
      icon:  Icons.description_outlined,
      children: [
        _InfoRow('Full Name',    (data['userName']    as String?) ?? '—'),
        _InfoRow('Email',        (data['email']       as String?) ?? '—'),
        _InfoRow('Phone', () {
          final p = (data['phone'] as String?) ?? '';
          return p.isNotEmpty ? p : 'Not provided';
        }()),
        _InfoRow('School',       (data['university']  as String?) ?? '—'),
        _InfoRow('Course', () {
          final c = (data['course'] as String?) ?? '';
          return c.isNotEmpty ? c : 'Not provided';
        }()),
        _InfoRow('Purpose',      (data['purpose']     as String?) ?? '—',
            multiline: true),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TIMELINE CARD
// ─────────────────────────────────────────────────────────────
class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String               status;
  const _TimelineCard({required this.data, required this.status});

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final d = ts.toDate();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
                 'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h   = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '${m[d.month - 1]} ${d.day}, ${d.year}  $h:$min';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    // admin ExternalAccount uses requestDate (not submittedAt)
    final submitted = data['requestDate'] ?? data['submittedAt'];
    final reviewed  = data['reviewedAt'];

    return _Card(title: 'Request Timeline', icon: Icons.timeline_rounded,
        children: [
      _TRow(icon: Icons.send_outlined,         color: _kPrimary,
            label: 'Request Submitted',
            ts: _fmt(submitted),               done: true),
      _TRow(icon: Icons.manage_search_outlined, color: _kWarning,
            label: 'Under Admin Review',
            ts: status != 'pending' ? _fmt(reviewed) : 'In progress…',
            done: status != 'pending'),
      _TRow(
        icon:  status == 'approved'
                  ? Icons.check_circle_rounded
                  : status == 'rejected'
                      ? Icons.cancel_rounded
                      : Icons.hourglass_bottom_rounded,
        color: status == 'approved'
                  ? _kSuccess
                  : status == 'rejected'
                      ? _kError
                      : const Color(0xFFCBD5E1),
        label: status == 'approved'
                  ? 'Approved — Access Granted'
                  : status == 'rejected'
                      ? 'Request Rejected'
                      : 'Awaiting Decision',
        ts:    status == 'pending' ? '—' : _fmt(reviewed),
        done:  status != 'pending',
        isLast: true,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
//  APPROVED / REJECTED / DELETED VIEWS
// ─────────────────────────────────────────────────────────────
class _ApprovedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSuccessBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kSuccess.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kSuccess.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_rounded,
                size: 18, color: _kSuccess),
          ),
          const SizedBox(width: 10),
          Text('Access Granted',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: _kSuccess)),
        ]),
        const SizedBox(height: 12),
        Text('You can now browse and register for public CICT events. '
             'Head over to the Events tab to get started.',
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: const Color(0xFF166534), height: 1.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Pill(icon: Icons.calendar_today_outlined, label: 'Browse Events'),
          _Pill(icon: Icons.qr_code_rounded,          label: 'QR Pass'),
          _Pill(icon: Icons.campaign_outlined,         label: 'Announcements'),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kSuccess.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kSuccess.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kSuccess),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 10, color: _kSuccess,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _RejectedCard extends StatelessWidget {
  final String note;
  const _RejectedCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kErrorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kError.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kError.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cancel_outlined, size: 18, color: _kError),
          ),
          const SizedBox(width: 10),
          Text('Admin Review Note',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _kError)),
        ]),
        const SizedBox(height: 10),
        Text(note.isNotEmpty ? note : 'No specific reason was provided.',
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: const Color(0xFF991B1B), height: 1.5)),
        const SizedBox(height: 10),
        Text('You may re-apply with updated information.',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: _kError.withOpacity(0.7),
                fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _DeletedView extends StatelessWidget {
  final VoidCallback onReset;
  const _DeletedView({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: _kPrimaryBg, shape: BoxShape.circle),
            child: const Icon(Icons.find_in_page_outlined,
                size: 48, color: _kPrimary),
          ),
          const SizedBox(height: 20),
          Text('Request Not Found',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Your request may have been removed. You can submit a new one.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _PrimaryBtn(label: 'Apply Again', onTap: onReset),
        ]),
      ),
    );
  }
}

class _WithdrawBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _WithdrawBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kError.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.close, size: 16, color: _kError),
          const SizedBox(width: 8),
          Text('Withdraw Request',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _kError)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  HERO BANNER
// ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kDark, Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(children: [
        Positioned(right: -15, top: -15,
          child: Container(width: 100, height: 100,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _kPrimary.withOpacity(0.1)))),
        Positioned(right: 30, bottom: -20,
          child: Container(width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _kPrimary.withOpacity(0.07)))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kPrimary.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_add_outlined, size: 12, color: _kPrimary),
              const SizedBox(width: 5),
              Text('EXTERNAL REQUEST',
                  style: GoogleFonts.beVietnamPro(
                      color: _kPrimary, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ]),
          ),
          const SizedBox(height: 12),
          Text('Apply for Event\nAccess',
              style: GoogleFonts.beVietnamPro(
                  color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 8),
          Text('Submit your details and wait for admin\n'
               'verification to join CICT public events.',
              style: GoogleFonts.beVietnamPro(
                  color: Colors.white54, fontSize: 12, height: 1.5)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            _HeroPill(icon: Icons.edit_note_outlined,    label: 'Fill Form'),
            _HeroPill(icon: Icons.hourglass_top_rounded, label: 'Wait Review'),
            _HeroPill(icon: Icons.check_circle_outline,  label: 'Join Events'),
          ]),
        ]),
      ]),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: _kPrimary),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                color: Colors.white70, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP INDICATOR
// ─────────────────────────────────────────────────────────────
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
            return Expanded(child: Container(
              height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
              color: done ? _kPrimary : const Color(0xFFE2E8F0),
            ));
          }
          final idx      = i ~/ 2;
          final isActive = current == idx;
          final isDone   = current > idx;
          return Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isDone ? _kSuccess : isActive ? _kPrimary
                              : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
              ),
              child: Center(child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${idx + 1}',
                      style: GoogleFonts.beVietnamPro(
                          color: isActive ? Colors.white
                                         : const Color(0xFF94A3B8),
                          fontSize: 13, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(height: 4),
            Text(_labels[idx],
                style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    fontWeight: (isActive || isDone)
                        ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? _kPrimary
                        : isDone ? _kSuccess
                        : const Color(0xFF94A3B8))),
          ]);
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED BUILDING BLOCKS
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;
  const _Card({required this.title, required this.icon,
               required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(color: _kPrimary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Icon(icon, size: 15, color: _kPrimary),
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
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0F0F0))),
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

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool   multiline;
  const _InfoRow(this.label, this.value, {this.multiline = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: multiline
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: Colors.grey,
                      fontWeight: FontWeight.w600, letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(value,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: Colors.black87, height: 1.5)),
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 80,
                  child: Text(label,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11, color: Colors.grey,
                          fontWeight: FontWeight.w600, letterSpacing: 0.4))),
              const SizedBox(width: 8),
              Expanded(child: Text(value,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, color: Colors.black87,
                      fontWeight: FontWeight.w500))),
            ]),
    );
  }
}

class _TRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, ts;
  final bool     done, isLast;
  const _TRow({required this.icon, required this.color,
               required this.label, required this.ts,
               required this.done,  this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: done ? color.withOpacity(0.12)
                        : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? color : const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: Icon(icon, size: 16,
              color: done ? color : const Color(0xFFCBD5E1)),
        ),
        if (!isLast) Container(width: 2, height: 32,
            color: const Color(0xFFE2E8F0),
            margin: const EdgeInsets.symmetric(vertical: 2)),
      ]),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: done ? Colors.black87
                              : const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(ts, style: GoogleFonts.beVietnamPro(
              fontSize: 11, color: Colors.grey)),
        ]),
      )),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String                     label;
  final TextEditingController      controller;
  final String                     hint;
  final IconData                   icon;
  final TextInputType?             keyboardType;
  final int                        maxLines;
  final bool                       isRequired;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,   required this.controller,
    required this.hint,    required this.icon,
    this.keyboardType,     this.maxLines   = 1,
    this.isRequired = true, this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: GoogleFonts.beVietnamPro(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: Colors.black87)),
        if (isRequired)
          Text(' *', style: GoogleFonts.beVietnamPro(
              fontSize: 12, color: _kPrimary)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller:   controller,
        keyboardType: keyboardType,
        maxLines:     maxLines,
        validator:    validator,
        style: GoogleFonts.beVietnamPro(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.beVietnamPro(
              fontSize: 13, color: const Color(0xFFBBBBBB)),
          prefixIcon: maxLines == 1
              ? Icon(icon, size: 18, color: Colors.grey) : null,
          filled: true, fillColor: const Color(0xFFF8F9FB),
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: maxLines > 1 ? 14 : 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kError, width: 1)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kError, width: 1.5)),
          errorStyle: GoogleFonts.beVietnamPro(fontSize: 10),
        ),
      ),
    ]);
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String   text;
  final Color    color;
  final Color    bgColor;
  const _Notice({
    required this.icon, required this.text,
    this.color = _kPrimary, this.bgColor = _kPrimaryBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color == _kPrimary ? const Color(0xFF7A3300)
        : color == _kWarning ? const Color(0xFF78350F) : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: textColor, height: 1.5))),
      ]),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String       label;
  final VoidCallback? onTap;
  final bool         isLoading;
  const _PrimaryBtn({required this.label, required this.onTap,
                     this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap == null ? Colors.grey.shade300 : _kPrimary,
          foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  final String       label;
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
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}