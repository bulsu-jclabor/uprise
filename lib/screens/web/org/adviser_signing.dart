// lib/screens/web/org/adviser_signing.dart
//
// Redesigned to match adviser_approvals.dart aesthetic.
// Collections synced:
//   event_proposals  → status == 'approved', signedAt == null
//   reports          → status == 'approved', signedAt == null
//   letter_requests  → status == 'approved', signedAt == null
//
// On sign → writes: signedBy, signedAt, status: 'signed'
// Logs to activity_logs (same pattern as rest of portal)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────
// COLOR SCHEME
// ─────────────────────────────────────────────────────────────────────
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color successBg    = Color(0xFFD1FAE5);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoBg       = Color(0xFFEFF6FF);
  static const Color purple       = Color(0xFF7C3AED);
  static const Color purpleBg     = Color(0xFFF3E8FF);
}

// ─────────────────────────────────────────────────────────────────────
// ACTIVITY LOGGER
// ─────────────────────────────────────────────────────────────────────
class _Logger {
  static Future<void> log({
    required String action,
    required String module,
    required String orgId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('activity_logs').add({
        'user':      user?.email ?? 'Unknown',
        'action':    action,
        'module':    module,
        'orgId':     orgId,
        'severity':  'info',
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': '',
        'details':   details ?? {},
      });
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────
// TAB DEFINITION
// ─────────────────────────────────────────────────────────────────────
enum _Tab { proposals, reports, letters }

extension _TabX on _Tab {
  String get label {
    switch (this) {
      case _Tab.proposals: return 'Event Proposals';
      case _Tab.reports:   return 'Reports';
      case _Tab.letters:   return 'Letter Requests';
    }
  }

  IconData get icon {
    switch (this) {
      case _Tab.proposals: return Icons.description_outlined;
      case _Tab.reports:   return Icons.summarize_outlined;
      case _Tab.letters:   return Icons.mail_outline;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────
class AdviserSigningScreen extends StatefulWidget {
  final String orgId;
  const AdviserSigningScreen({super.key, required this.orgId});

  @override
  State<AdviserSigningScreen> createState() => _AdviserSigningScreenState();
}

class _AdviserSigningScreenState extends State<AdviserSigningScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _Tab _activeTab = _Tab.proposals;

  String _adviserName = '';
  String _adviserEmail = '';
  bool _loadingAdviser = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _Tab.values.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) return;
        setState(() => _activeTab = _Tab.values[_tab.index]);
      });
    _loadAdviser();
  }

  Future<void> _loadAdviser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      setState(() {
        _adviserName  = doc.data()?['name'] ?? user.displayName ?? user.email ?? 'Adviser';
        _adviserEmail = user.email ?? '';
        _loadingAdviser = false;
      });
    } catch (_) {
      setState(() => _loadingAdviser = false);
    }
  }

  Stream<int> _pendingCount(_Tab t) {
    late Query q;
    switch (t) {
      case _Tab.proposals:
        q = FirebaseFirestore.instance
            .collection('event_proposals')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', isEqualTo: 'approved');
        break;
      case _Tab.reports:
        q = FirebaseFirestore.instance
            .collection('reports')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', isEqualTo: 'approved');
        break;
      case _Tab.letters:
        q = FirebaseFirestore.instance
            .collection('letter_requests')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', isEqualTo: 'approved');
        break;
    }
    // count only unsigned docs
    return q.snapshots().map(
      (s) => s.docs.where((d) => (d.data() as Map)['signedAt'] == null).length,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ─────────────────────────────────────────
          _buildHeader(),
          const SizedBox(height: 20),

          // ── adviser identity card ──────────────────────────
          if (!_loadingAdviser) _AdviserCard(name: _adviserName, email: _adviserEmail),
          if (!_loadingAdviser) const SizedBox(height: 20),

          // ── stat row ───────────────────────────────────────
          _StatRow(orgId: widget.orgId),
          const SizedBox(height: 20),

          // ── tab bar ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: OrgColors.white,
              border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
            ),
            child: TabBar(
              controller: _tab,
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              indicatorColor: OrgColors.primaryDark,
              indicatorWeight: 2.5,
              tabs: _Tab.values.map((t) {
                final isActive = _activeTab == t;
                return StreamBuilder<int>(
                  stream: _pendingCount(t),
                  builder: (_, snap) {
                    final n = snap.data ?? 0;
                    return Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t.icon, size: 16,
                              color: isActive ? OrgColors.primaryDark : OrgColors.darkGray),
                          const SizedBox(width: 8),
                          Text(t.label,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? OrgColors.primaryDark : OrgColors.darkGray,
                              )),
                          if (n > 0) ...[
                            const SizedBox(width: 8),
                            _Badge(count: n),
                          ],
                        ]),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),

          // ── tab views ──────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ProposalsSigningTab(orgId: widget.orgId, adviserName: _adviserName),
                _ReportsSigningTab(orgId: widget.orgId, adviserName: _adviserName),
                _LettersSigningTab(orgId: widget.orgId, adviserName: _adviserName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Document Signing',
            style: GoogleFonts.beVietnamPro(
                fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
        const SizedBox(height: 2),
        Text('Review and digitally sign approved documents',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
      ]),
      const Spacer(),
      // "Legally binding" info pill
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: OrgColors.infoBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OrgColors.info.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.verified_outlined, size: 15, color: OrgColors.info),
          const SizedBox(width: 6),
          Text('Signatures are digitally recorded',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.info)),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────
// ADVISER IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────
class _AdviserCard extends StatelessWidget {
  final String name, email;
  const _AdviserCard({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFFF7ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.warning.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: OrgColors.primaryDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_circle_outlined,
              color: OrgColors.primaryDark, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Signing as',
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
          Text(name,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          if (email.isNotEmpty)
            Text(email,
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: OrgColors.successBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: OrgColors.success.withOpacity(0.3)),
          ),
          child: Row(children: [
            Container(
              width: 7, height: 7,
              decoration: const BoxDecoration(
                  color: OrgColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text('Adviser',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11, fontWeight: FontWeight.w700, color: OrgColors.success)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// STAT ROW
// ─────────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  final String orgId;
  const _StatRow({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatCard(
        label: 'Proposals to Sign',
        icon: Icons.description_outlined,
        iconColor: OrgColors.warning,
        iconBg: OrgColors.warningBg,
        collection: 'event_proposals',
        orgId: orgId,
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Reports to Sign',
        icon: Icons.summarize_outlined,
        iconColor: OrgColors.purple,
        iconBg: OrgColors.purpleBg,
        collection: 'reports',
        orgId: orgId,
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Letters to Sign',
        icon: Icons.mail_outline,
        iconColor: OrgColors.info,
        iconBg: OrgColors.infoBg,
        collection: 'letter_requests',
        orgId: orgId,
      ),
      const SizedBox(width: 12),
      _SignedTodayCard(orgId: orgId),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, collection, orgId;
  final IconData icon;
  final Color iconColor, iconBg;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.collection,
    required this.orgId,
  });

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(collection)
        .where('orgId', isEqualTo: orgId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((s) => s.docs.where((d) => (d.data())['signedAt'] == null).length);

    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (_, snap) {
          final n = snap.data ?? 0;
          return _CardShell(
            icon: icon, iconColor: iconColor, iconBg: iconBg,
            label: label, value: '$n',
          );
        },
      ),
    );
  }
}

class _SignedTodayCard extends StatelessWidget {
  final String orgId;
  const _SignedTodayCard({required this.orgId});

  @override
  Widget build(BuildContext context) {
    // count docs signed today across all collections
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final stream = FirebaseFirestore.instance
        .collection('activity_logs')
        .where('orgId', isEqualTo: orgId)
        .where('action', whereIn: ['sign_proposal', 'sign_report', 'sign_letter_request'])
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((s) => s.docs.length);

    return Expanded(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (_, snap) {
          final n = snap.data ?? 0;
          return _CardShell(
            icon: Icons.check_circle_outline,
            iconColor: OrgColors.success,
            iconBg: OrgColors.successBg,
            label: 'Signed Today',
            value: '$n',
          );
        },
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, value;

  const _CardShell({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          Text(label,
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// BADGE
// ─────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: OrgColors.error, borderRadius: BorderRadius.circular(20)),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PROPOSALS SIGNING TAB
// ─────────────────────────────────────────────────────────────────────
class _ProposalsSigningTab extends StatelessWidget {
  final String orgId, adviserName;
  const _ProposalsSigningTab({required this.orgId, required this.adviserName});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('submittedAt', descending: true)
      .snapshots();

  Future<void> _sign(BuildContext ctx, String id, String title) async {
    final ok = await _confirmSign(ctx,
        docType: 'Event Proposal',
        docName: title,
        adviserName: adviserName,
        legalNote: 'This action is legally binding and will be recorded.');
    if (!ok) return;
    try {
      await FirebaseFirestore.instance
          .collection('event_proposals').doc(id).update({
        'signedBy':  adviserName,
        'signedAt':  FieldValue.serverTimestamp(),
        'status':    'signed',
      });
      await activity_log.ActivityLogger.log(action: 'sign_proposal', module: 'adviser_signing',
          orgId: orgId, details: {'proposalId': id, 'title': title});
      _snack(ctx, 'Proposal signed successfully ✓', OrgColors.success);
    } catch (e) {
      _snack(ctx, 'Error: $e', OrgColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      filterUnsigned: true,
      emptyIcon: Icons.description_outlined,
      emptyMessage: 'No proposals awaiting signature',
      emptySubtitle: 'Approved proposals will appear here for signing',
      itemBuilder: (ctx, doc) {
        final d = doc.data() as Map<String, dynamic>;
        // skip already-signed docs (null check since Firestore compound
        // inequality on signedAt requires an index; we filter client-side)
        if (d['signedAt'] != null) return const SizedBox.shrink();
        return _SigningCard(
          icon: Icons.description_outlined,
          iconColor: OrgColors.info,
          iconBg: OrgColors.infoBg,
          title: d['title'] ?? 'Untitled',
          subtitle: '${d['category'] ?? '—'}  ·  Approved ${_fmtTs(d['reviewedAt'])}',
          meta: 'Submitted ${_fmtTs(d['submittedAt'])}',
          onSign: () => _sign(ctx, doc.id, d['title'] ?? 'Proposal'),
          onView: () => _showDetail(ctx, d,
              title: d['title'] ?? 'Proposal',
              icon: Icons.description_outlined,
              iconColor: OrgColors.info,
              rows: [
                _DR('Category',    d['category'] ?? '—'),
                _DR('Audience',    d['audience'] ?? '—'),
                _DR('Description', d['description'] ?? '—'),
                _DR('Date',        _fmtTs(d['date'])),
                _DR('Time',        d['time'] ?? '—'),
                _DR('Location',    d['location'] ?? '—'),
                _DR('Submitted',   _fmtTs(d['submittedAt'])),
                _DR('Approved',    _fmtTs(d['reviewedAt'])),
              ],
              attachmentUrl: d['attachmentUrl'] as String?),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// REPORTS SIGNING TAB
// ─────────────────────────────────────────────────────────────────────
class _ReportsSigningTab extends StatelessWidget {
  final String orgId, adviserName;
  const _ReportsSigningTab({required this.orgId, required this.adviserName});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('reports')
      .where('orgId', isEqualTo: orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('submittedAt', descending: true)
      .snapshots();

  Future<void> _sign(BuildContext ctx, String id, String title) async {
    final ok = await _confirmSign(ctx,
        docType: 'Report',
        docName: title,
        adviserName: adviserName,
        legalNote: 'This confirms the accuracy of the report.');
    if (!ok) return;
    try {
      await FirebaseFirestore.instance
          .collection('reports').doc(id).update({
        'signedBy': adviserName,
        'signedAt': FieldValue.serverTimestamp(),
        'status':   'signed',
      });
      await activity_log.ActivityLogger.log(action: 'sign_report', module: 'adviser_signing',
          orgId: orgId, details: {'reportId': id, 'title': title});
      _snack(ctx, 'Report signed successfully ✓', OrgColors.success);
    } catch (e) {
      _snack(ctx, 'Error: $e', OrgColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      filterUnsigned: true,
      emptyIcon: Icons.summarize_outlined,
      emptyMessage: 'No reports awaiting signature',
      emptySubtitle: 'Approved reports will appear here for signing',
      itemBuilder: (ctx, doc) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['signedAt'] != null) return const SizedBox.shrink();
        final type = d['type'] == 'financial' ? 'Financial' : 'Accomplishment';
        return _SigningCard(
          icon: Icons.article_outlined,
          iconColor: OrgColors.purple,
          iconBg: OrgColors.purpleBg,
          title: d['title'] ?? 'Untitled',
          subtitle: '$type Report  ·  Approved ${_fmtTs(d['reviewedAt'])}',
          meta: 'Submitted ${_fmtTs(d['submittedAt'])}',
          onSign: () => _sign(ctx, doc.id, d['title'] ?? 'Report'),
          onView: () => _showDetail(ctx, d,
              title: d['title'] ?? 'Report',
              icon: Icons.article_outlined,
              iconColor: OrgColors.purple,
              rows: [
                _DR('Type',        '$type Report'),
                _DR('Description', d['description'] ?? '—'),
                _DR('Submitted',   _fmtTs(d['submittedAt'])),
                _DR('Approved',    _fmtTs(d['reviewedAt'])),
              ],
              attachmentUrl: d['fileUrl'] as String?),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LETTERS SIGNING TAB
// ─────────────────────────────────────────────────────────────────────
class _LettersSigningTab extends StatelessWidget {
  final String orgId, adviserName;
  const _LettersSigningTab({required this.orgId, required this.adviserName});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('letter_requests')
      .where('orgId', isEqualTo: orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _sign(BuildContext ctx, String id, String subject) async {
    final ok = await _confirmSign(ctx,
        docType: 'Letter Request',
        docName: subject,
        adviserName: adviserName,
        legalNote: 'This confirms the authenticity of the letter.');
    if (!ok) return;
    try {
      await FirebaseFirestore.instance
          .collection('letter_requests').doc(id).update({
        'signedBy': adviserName,
        'signedAt': FieldValue.serverTimestamp(),
        'status':   'signed',
      });
      await activity_log.ActivityLogger.log(action: 'sign_letter_request', module: 'adviser_signing',
          orgId: orgId, details: {'letterId': id, 'subject': subject});
      _snack(ctx, 'Letter signed successfully ✓', OrgColors.success);
    } catch (e) {
      _snack(ctx, 'Error: $e', OrgColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      filterUnsigned: true,
      emptyIcon: Icons.mail_outline,
      emptyMessage: 'No letters awaiting signature',
      emptySubtitle: 'Approved letter requests will appear here for signing',
      itemBuilder: (ctx, doc) {
        final d = doc.data() as Map<String, dynamic>;
        if (d['signedAt'] != null) return const SizedBox.shrink();
        return _SigningCard(
          icon: Icons.mail_outline,
          iconColor: OrgColors.info,
          iconBg: OrgColors.infoBg,
          title: d['subject'] ?? 'Untitled',
          subtitle: '${d['letterType'] ?? '—'}  ·  From ${d['name'] ?? '—'}',
          meta: 'Submitted ${_fmtTs(d['timestamp'])}',
          onSign: () => _sign(ctx, doc.id, d['subject'] ?? 'Letter'),
          onView: () => _showDetail(ctx, d,
              title: d['subject'] ?? 'Letter Request',
              icon: Icons.mail_outline,
              iconColor: OrgColors.info,
              rows: [
                _DR('From',        d['name'] ?? '—'),
                _DR('Email',       d['email'] ?? '—'),
                _DR('Letter Type', d['letterType'] ?? '—'),
                _DR('Message',     d['message'] ?? '—'),
                _DR('Submitted',   _fmtTs(d['timestamp'])),
              ],
              attachmentUrl: d['attachmentUrl'] as String?),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// TAB SHELL
// ─────────────────────────────────────────────────────────────────────
class _TabShell extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final bool filterUnsigned;
  final IconData emptyIcon;
  final String emptyMessage, emptySubtitle;
  final Widget Function(BuildContext, QueryDocumentSnapshot) itemBuilder;

  const _TabShell({
    required this.stream,
    required this.filterUnsigned,
    required this.emptyIcon,
    required this.emptyMessage,
    required this.emptySubtitle,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: OrgColors.primaryDark));
        }
        if (snap.hasError) {
          return _Err(message: snap.error.toString());
        }
        final allDocs = snap.data?.docs ?? [];
        // client-side filter for unsigned
        final docs = filterUnsigned
            ? allDocs.where((d) => (d.data() as Map)['signedAt'] == null).toList()
            : allDocs;

        if (docs.isEmpty) {
          return _Empty(
              icon: emptyIcon, message: emptyMessage, subtitle: emptySubtitle);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c, i) => itemBuilder(c, docs[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SIGNING CARD
// ─────────────────────────────────────────────────────────────────────
class _SigningCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String title, subtitle, meta;
  final VoidCallback onSign, onView;

  const _SigningCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onSign,
    required this.onView,
  });

  @override
  State<_SigningCard> createState() => _SigningCardState();
}

class _SigningCardState extends State<_SigningCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFFFFBF2) : OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover
                ? OrgColors.primaryDark.withOpacity(0.25)
                : OrgColors.mediumGray,
          ),
          boxShadow: _hover
              ? [BoxShadow(
                  color: OrgColors.primaryDark.withOpacity(0.07),
                  blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            // Icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: widget.iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(widget.icon, color: widget.iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: OrgColors.charcoal),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(widget.subtitle,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: OrgColors.darkGray),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 16),

            // Awaiting badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: OrgColors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrgColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.draw_outlined, size: 12, color: OrgColors.primaryDark),
                const SizedBox(width: 5),
                Text('Awaiting Signature',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: OrgColors.primaryDark)),
              ]),
            ),
            const SizedBox(width: 16),

            // Meta
            Row(children: [
              const Icon(Icons.access_time_outlined, size: 13, color: OrgColors.darkGray),
              const SizedBox(width: 4),
              Text(widget.meta,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
            ]),
            const SizedBox(width: 16),

            // View button
            _OutlineBtn(
              icon: Icons.visibility_outlined,
              label: 'View',
              color: OrgColors.darkGray,
              bg: OrgColors.lightGray,
              border: OrgColors.mediumGray,
              onTap: widget.onView,
            ),
            const SizedBox(width: 8),

            // Sign button
            _OutlineBtn(
              icon: Icons.draw_outlined,
              label: 'Sign',
              color: OrgColors.success,
              bg: OrgColors.successBg,
              border: OrgColors.success.withOpacity(0.25),
              onTap: widget.onSign,
            ),
          ]),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg, border;
  final VoidCallback onTap;

  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// CONFIRM SIGN DIALOG
// ─────────────────────────────────────────────────────────────────────
Future<bool> _confirmSign(
  BuildContext ctx, {
  required String docType,
  required String docName,
  required String adviserName,
  required String legalNote,
}) async {
  final result = await showDialog<bool>(
    context: ctx,
    builder: (dctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15),
                blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: OrgColors.successBg, shape: BoxShape.circle),
            child: const Icon(Icons.draw_outlined,
                color: OrgColors.success, size: 26),
          ),
          const SizedBox(height: 16),
          Text('Sign $docType',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: OrgColors.charcoal),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),

          // Document name pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OrgColors.primaryLight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Document',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
              const SizedBox(height: 2),
              Text(docName,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: OrgColors.charcoal)),
            ]),
          ),
          const SizedBox(height: 10),

          // Signer pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: OrgColors.warningBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: OrgColors.warning.withOpacity(0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Signing as',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
              const SizedBox(height: 2),
              Text(adviserName,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: OrgColors.primaryDark)),
            ]),
          ),
          const SizedBox(height: 12),

          // Legal note
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 14, color: OrgColors.info),
            const SizedBox(width: 6),
            Expanded(
              child: Text(legalNote,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: OrgColors.darkGray)),
            ),
          ]),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dctx, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: OrgColors.primaryLight),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(dctx, true),
                icon: const Icon(Icons.draw_outlined,
                    size: 15, color: Colors.white),
                label: Text('Confirm Sign',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return result == true;
}

// ─────────────────────────────────────────────────────────────────────
// DETAIL DIALOG
// ─────────────────────────────────────────────────────────────────────
class _DR {
  final String label, value;
  const _DR(this.label, this.value);
}

void _showDetail(
  BuildContext ctx,
  Map<String, dynamic> data, {
  required String title,
  required IconData icon,
  required Color iconColor,
  required List<_DR> rows,
  String? attachmentUrl,
}) {
  showDialog(
    context: ctx,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15),
                blurRadius: 32, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: OrgColors.primaryLight)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: OrgColors.charcoal),
                    overflow: TextOverflow.ellipsis),
              ),
              // Signed badge if applicable
              if (data['signedAt'] != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: OrgColors.successBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified, size: 12, color: OrgColors.success),
                    const SizedBox(width: 4),
                    Text('Signed',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: OrgColors.success)),
                  ]),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          // body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ...rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 110,
                      child: Text(r.label,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: OrgColors.darkGray)),
                    ),
                    Expanded(
                      child: Text(r.value,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13, color: OrgColors.charcoal)),
                    ),
                  ]),
                )),
                if (data['signedBy'] != null) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.draw_outlined, size: 14, color: OrgColors.success),
                    const SizedBox(width: 6),
                    Text('Signed by ',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: OrgColors.darkGray)),
                    Text(data['signedBy'] as String,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: OrgColors.success)),
                    const SizedBox(width: 8),
                    Text('on ${_fmtTs(data['signedAt'])}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, color: OrgColors.darkGray)),
                  ]),
                ],
                if (attachmentUrl != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Attachment',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: OrgColors.darkGray)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.attach_file, size: 15, color: OrgColors.darkGray),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        Uri.decodeFull(attachmentUrl.split('/').last.split('?').first),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: OrgColors.info,
                            decoration: TextDecoration.underline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: attachmentUrl));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('URL copied')));
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy, size: 15, color: OrgColors.darkGray),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () async {
                        final uri = Uri.parse(attachmentUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.open_in_new, size: 15, color: OrgColors.info),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),

          // footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OrgColors.primaryLight)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Close',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final IconData icon;
  final String message, subtitle;
  const _Empty({required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: OrgColors.lightGray, borderRadius: BorderRadius.circular(18)),
          child: Icon(icon, size: 34, color: OrgColors.mediumGray),
        ),
        const SizedBox(height: 16),
        Text(message,
            style: GoogleFonts.beVietnamPro(
                fontSize: 15, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: OrgColors.successBg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, size: 14, color: OrgColors.success),
            const SizedBox(width: 5),
            Text('All signed!',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: OrgColors.success)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────
class _Err extends StatelessWidget {
  final String message;
  const _Err({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: OrgColors.error),
        const SizedBox(height: 12),
        Text('Failed to load',
            style: GoogleFonts.beVietnamPro(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: OrgColors.charcoal)),
        const SizedBox(height: 4),
        Text(message,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: OrgColors.darkGray),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────
String _fmtTs(dynamic ts) {
  if (ts == null) return '—';
  if (ts is Timestamp) return DateFormat('MMM dd, yyyy').format(ts.toDate());
  return ts.toString();
}

void _snack(BuildContext ctx, String msg, Color color) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg,
        style: GoogleFonts.beVietnamPro(color: Colors.white)),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}



