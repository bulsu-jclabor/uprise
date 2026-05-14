// lib/screens/web/org/adviser_approvals.dart
//
// Redesigned with polished UI.
// Synced with:
//   • event_proposals  → collection: 'event_proposals', fields: title, category,
//                        description, date, time, location, audience, attachmentUrl,
//                        submittedAt, status ('pending' | 'for_review' | 'approved' | 'rejected')
//   • letter_request   → collection: 'letter_requests', fields: name, email,
//                        letterType, subject, message, attachmentUrl, timestamp,
//                        status ('pending' | 'approved' | 'rejected' | 'review' | 'replied')
//   • reports          → collection: 'reports', fields: title, type, description,
//                        fileUrl, submittedAt, status ('pending' | 'approved' | 'rejected')

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────
// COLOR SCHEME  (identical to OrgDashboard so the sidebar gradient
// and card tones match across the whole portal)
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
// TAB DEFINITION
// ─────────────────────────────────────────────────────────────────────
enum _Tab { proposals, letters, reports }

extension _TabX on _Tab {
  String get label {
    switch (this) {
      case _Tab.proposals: return 'Event Proposals';
      case _Tab.letters:   return 'Letter Requests';
      case _Tab.reports:   return 'Reports';
    }
  }

  IconData get icon {
    switch (this) {
      case _Tab.proposals: return Icons.description_outlined;
      case _Tab.letters:   return Icons.mail_outline;
      case _Tab.reports:   return Icons.summarize_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────
class AdviserApprovalsScreen extends StatefulWidget {
  final String orgId;
  const AdviserApprovalsScreen({super.key, required this.orgId});

  @override
  State<AdviserApprovalsScreen> createState() => _AdviserApprovalsScreenState();
}

class _AdviserApprovalsScreenState extends State<AdviserApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _Tab _activeTab = _Tab.proposals;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _Tab.values.length, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) return;
        setState(() => _activeTab = _Tab.values[_tab.index]);
      });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── pending-count badges ─────────────────────────────────
  Stream<int> _pendingCount(_Tab t) {
    late Query q;
    switch (t) {
      case _Tab.proposals:
        q = FirebaseFirestore.instance
            .collection('event_proposals')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', whereIn: ['pending', 'for_review']);
        break;
      case _Tab.letters:
        q = FirebaseFirestore.instance
            .collection('letter_requests')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', isEqualTo: 'pending');
        break;
      case _Tab.reports:
        q = FirebaseFirestore.instance
            .collection('reports')
            .where('orgId', isEqualTo: widget.orgId)
            .where('status', isEqualTo: 'pending');
        break;
    }
    return q.snapshots().map((s) => s.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header ─────────────────────────────────────────
          _Header(orgId: widget.orgId),
          const SizedBox(height: 20),

          // ── stat row ───────────────────────────────────────
          _StatRow(orgId: widget.orgId),
          const SizedBox(height: 20),

          // ── tab bar ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: OrgColors.white,
              border: Border(bottom: BorderSide(color: OrgColors.mediumGray)),
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
                _ProposalsTab(orgId: widget.orgId),
                _LettersTab(orgId: widget.orgId),
                _ReportsTab(orgId: widget.orgId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String orgId;
  const _Header({required this.orgId});

  @override
  Widget build(BuildContext context) {
    // total pending across all types
    final pendingStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: orgId)
        .where('status', whereIn: ['pending', 'for_review'])
        .snapshots()
        .asyncMap((s) async {
          final letters = await FirebaseFirestore.instance
              .collection('letter_requests')
              .where('orgId', isEqualTo: orgId)
              .where('status', isEqualTo: 'pending')
              .get();
          final reports = await FirebaseFirestore.instance
              .collection('reports')
              .where('orgId', isEqualTo: orgId)
              .where('status', isEqualTo: 'pending')
              .get();
          return s.docs.length + letters.docs.length + reports.docs.length;
        });

    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pending Approvals',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          const SizedBox(height: 2),
          Text('Review and act on requests submitted by officers',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
        ]),
        const Spacer(),
        StreamBuilder<int>(
          stream: pendingStream,
          builder: (_, snap) {
            final total = snap.data ?? 0;
            if (total == 0) return const SizedBox();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: OrgColors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrgColors.warning.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.pending_actions, size: 16, color: OrgColors.primaryDark),
                const SizedBox(width: 6),
                Text('$total item${total == 1 ? '' : 's'} awaiting review',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.primaryDark)),
              ]),
            );
          },
        ),
      ],
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
        label: 'Pending Proposals',
        icon: Icons.description_outlined,
        iconColor: OrgColors.warning,
        iconBg: OrgColors.warningBg,
        stream: FirebaseFirestore.instance
            .collection('event_proposals')
            .where('orgId', isEqualTo: orgId)
            .where('status', whereIn: ['pending', 'for_review'])
            .snapshots(),
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Pending Letters',
        icon: Icons.mail_outline,
        iconColor: OrgColors.info,
        iconBg: OrgColors.infoBg,
        stream: FirebaseFirestore.instance
            .collection('letter_requests')
            .where('orgId', isEqualTo: orgId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Pending Reports',
        icon: Icons.summarize_outlined,
        iconColor: OrgColors.purple,
        iconBg: OrgColors.purpleBg,
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('orgId', isEqualTo: orgId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
      ),
      const SizedBox(width: 12),
      _StatCard(
        label: 'Approved Today',
        icon: Icons.check_circle_outline,
        iconColor: OrgColors.success,
        iconBg: OrgColors.successBg,
        stream: FirebaseFirestore.instance
            .collection('event_proposals')
            .where('orgId', isEqualTo: orgId)
            .where('status', isEqualTo: 'approved')
            .snapshots(),
      ),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor, iconBg;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (_, snap) {
          final n = snap.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OrgColors.mediumGray),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$n',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                Text(label,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
              ]),
            ]),
          );
        },
      ),
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
        color: OrgColors.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PROPOSALS TAB
// Synced with event_proposals: status in ['pending', 'for_review']
// On approve  → status: 'approved'
// On reject   → status: 'rejected'
// ─────────────────────────────────────────────────────────────────────
class _ProposalsTab extends StatelessWidget {
  final String orgId;
  const _ProposalsTab({required this.orgId});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: orgId)
      .where('status', whereIn: ['pending', 'for_review'])
      .orderBy('submittedAt', descending: true)
      .snapshots();

  Future<void> _approve(BuildContext ctx, String id, String title) async {
    final ok = await _confirm(ctx,
        title: 'Approve Proposal',
        body: 'Approve "$title"? This will allow the event to proceed.',
        confirmLabel: 'Approve',
        confirmColor: OrgColors.success);
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('event_proposals')
        .doc(id)
        .update({'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp()});
    await activity_log.ActivityLogger.log(action: 'approve_proposal', module: 'adviser_approvals',
        details: {'orgId': orgId, 'proposalId': id, 'title': title});
    _snack(ctx, 'Proposal approved ✓', OrgColors.success);
  }

  Future<void> _reject(BuildContext ctx, String id, String title) async {
    final ok = await _confirm(ctx,
        title: 'Reject Proposal',
        body: 'Reject "$title"? The org will be notified.',
        confirmLabel: 'Reject',
        confirmColor: OrgColors.error);
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('event_proposals')
        .doc(id)
        .update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()});
    await activity_log.ActivityLogger.log(action: 'reject_proposal', module: 'adviser_approvals',
        details: {'orgId': orgId, 'proposalId': id, 'title': title});
    _snack(ctx, 'Proposal rejected', OrgColors.error);
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      emptyIcon: Icons.description_outlined,
      emptyMessage: 'No pending event proposals',
      emptySubtitle: 'New proposals from officers will appear here',
      itemBuilder: (ctx, doc) {
        final d      = doc.data() as Map<String, dynamic>;
        final status = (d['status'] ?? 'pending') as String;
        return _ProposalCard(
          data:     d,
          docId:    doc.id,
          status:   status,
          onApprove: () => _approve(ctx, doc.id, d['title'] ?? 'Proposal'),
          onReject:  () => _reject(ctx, doc.id, d['title'] ?? 'Proposal'),
          onView:    () => _showProposalDetail(ctx, d),
        );
      },
    );
  }

  void _showProposalDetail(BuildContext ctx, Map<String, dynamic> d) {
    showDialog(
      context: ctx,
      builder: (_) => _DetailDialog(
        title: d['title'] ?? 'Proposal',
        icon: Icons.description_outlined,
        iconColor: OrgColors.primaryDark,
        rows: [
          _DetailRow('Category',    d['category'] ?? '—'),
          _DetailRow('Audience',    d['audience']  ?? '—'),
          _DetailRow('Description', d['description'] ?? '—'),
          _DetailRow('Date',        _fmtTs(d['date'])),
          _DetailRow('Time',        d['time'] ?? '—'),
          _DetailRow('Location',    d['location'] ?? '—'),
          _DetailRow('Submitted',   _fmtTs(d['submittedAt'])),
        ],
        attachmentUrl: d['attachmentUrl'] as String?,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PROPOSAL CARD
// ─────────────────────────────────────────────────────────────────────
class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId, status;
  final VoidCallback onApprove, onReject, onView;

  const _ProposalCard({
    required this.data,
    required this.docId,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final isForReview = status == 'for_review';
    return _ItemCard(
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isForReview ? OrgColors.infoBg : OrgColors.warningBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.description_outlined,
          color: isForReview ? OrgColors.info : OrgColors.warning,
          size: 20,
        ),
      ),
      title: data['title'] ?? 'Untitled',
      subtitle: '${data['category'] ?? '—'}  ·  ${_fmtTs(data['submittedAt'])}',
      statusChip: _StatusPill(status: status),
      meta: _fmtTs(data['date']),
      metaIcon: Icons.calendar_today_outlined,
      onView: onView,
      actions: [
        _ActionBtn(
          icon: Icons.check_rounded,
          label: 'Approve',
          color: OrgColors.success,
          bg: OrgColors.successBg,
          onTap: onApprove,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: Icons.close_rounded,
          label: 'Reject',
          color: OrgColors.error,
          bg: OrgColors.errorBg,
          onTap: onReject,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LETTERS TAB
// Synced with letter_requests: status == 'pending'
// On mark replied → status: 'replied', replied: true
// ─────────────────────────────────────────────────────────────────────
class _LettersTab extends StatelessWidget {
  final String orgId;
  const _LettersTab({required this.orgId});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('letter_requests')
      .where('orgId', isEqualTo: orgId)
      .where('status', isEqualTo: 'pending')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _markReplied(BuildContext ctx, String id, String name) async {
    final ok = await _confirm(ctx,
        title: 'Mark as Replied',
        body: 'Mark request from "$name" as replied?',
        confirmLabel: 'Confirm',
        confirmColor: OrgColors.success);
    if (!ok) return;
    await FirebaseFirestore.instance.collection('letter_requests').doc(id).update({
      'status': 'replied',
      'replied': true,
      'repliedAt': FieldValue.serverTimestamp(),
    });
    await activity_log.ActivityLogger.log(action: 'reply_letter_request', module: 'adviser_approvals',
        details: {'orgId': orgId, 'letterId': id, 'name': name});
    _snack(ctx, 'Marked as replied ✓', OrgColors.success);
  }

  Future<void> _approve(BuildContext ctx, String id, String name) async {
    final ok = await _confirm(ctx,
        title: 'Approve Request',
        body: 'Approve letter request from "$name"?',
        confirmLabel: 'Approve',
        confirmColor: OrgColors.success);
    if (!ok) return;
    await FirebaseFirestore.instance.collection('letter_requests').doc(id).update({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await activity_log.ActivityLogger.log(action: 'approve_letter_request', module: 'adviser_approvals',
        details: {'orgId': orgId, 'letterId': id, 'name': name});
    _snack(ctx, 'Request approved ✓', OrgColors.success);
  }

  Future<void> _reject(BuildContext ctx, String id, String name) async {
    final ok = await _confirm(ctx,
        title: 'Reject Request',
        body: 'Reject letter request from "$name"?',
        confirmLabel: 'Reject',
        confirmColor: OrgColors.error);
    if (!ok) return;
    await FirebaseFirestore.instance.collection('letter_requests').doc(id).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await activity_log.ActivityLogger.log(action: 'reject_letter_request', module: 'adviser_approvals',
        details: {'orgId': orgId, 'letterId': id, 'name': name});
    _snack(ctx, 'Request rejected', OrgColors.error);
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      emptyIcon: Icons.mail_outline,
      emptyMessage: 'No pending letter requests',
      emptySubtitle: 'Letter requests submitted by officers will appear here',
      itemBuilder: (ctx, doc) {
        final d    = doc.data() as Map<String, dynamic>;
        final name = d['name'] ?? 'Unknown';
        return _LetterCard(
          data:          d,
          onMarkReplied: () => _markReplied(ctx, doc.id, name),
          onApprove:     () => _approve(ctx, doc.id, name),
          onReject:      () => _reject(ctx, doc.id, name),
          onView:        () => _showLetterDetail(ctx, d),
        );
      },
    );
  }

  void _showLetterDetail(BuildContext ctx, Map<String, dynamic> d) {
    showDialog(
      context: ctx,
      builder: (_) => _DetailDialog(
        title: d['subject'] ?? 'Letter Request',
        icon: Icons.mail_outline,
        iconColor: OrgColors.info,
        rows: [
          _DetailRow('From',        d['name']  ?? '—'),
          _DetailRow('Email',       d['email'] ?? '—'),
          _DetailRow('Letter Type', d['letterType'] ?? '—'),
          _DetailRow('Message',     d['message'] ?? '—'),
          _DetailRow('Submitted',   _fmtTs(d['timestamp'])),
        ],
        attachmentUrl: d['attachmentUrl'] as String?,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// LETTER CARD
// ─────────────────────────────────────────────────────────────────────
class _LetterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onMarkReplied, onApprove, onReject, onView;

  const _LetterCard({
    required this.data,
    required this.onMarkReplied,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final letterId = data['letterId'] as String? ?? '—';
    return _ItemCard(
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: OrgColors.infoBg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.mail_outline, color: OrgColors.info, size: 20),
      ),
      title: data['name'] ?? 'Unknown',
      subtitle: '${data['letterType'] ?? '—'}  ·  $letterId',
      statusChip: _StatusPill(status: data['status'] ?? 'pending'),
      meta: _fmtTs(data['timestamp']),
      metaIcon: Icons.access_time_outlined,
      onView: onView,
      actions: [
        _ActionBtn(
          icon: Icons.mark_email_read_outlined,
          label: 'Replied',
          color: OrgColors.success,
          bg: OrgColors.successBg,
          onTap: onMarkReplied,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: Icons.check_rounded,
          label: 'Approve',
          color: OrgColors.info,
          bg: OrgColors.infoBg,
          onTap: onApprove,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: Icons.close_rounded,
          label: 'Reject',
          color: OrgColors.error,
          bg: OrgColors.errorBg,
          onTap: onReject,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// REPORTS TAB
// Synced with reports: status == 'pending'
// On approve → status: 'approved'
// On reject  → status: 'rejected'
// ─────────────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  final String orgId;
  const _ReportsTab({required this.orgId});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('reports')
      .where('orgId', isEqualTo: orgId)
      .where('status', isEqualTo: 'pending')
      .orderBy('submittedAt', descending: true)
      .snapshots();

  Future<void> _approve(BuildContext ctx, String id, String title) async {
    final ok = await _confirm(ctx,
        title: 'Approve Report',
        body: 'Approve "$title"?',
        confirmLabel: 'Approve',
        confirmColor: OrgColors.success);
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(id)
        .update({'status': 'approved', 'reviewedAt': FieldValue.serverTimestamp()});
    await activity_log.ActivityLogger.log(action: 'approve_report', module: 'adviser_approvals',
        details: {'orgId': orgId, 'reportId': id, 'title': title});
    _snack(ctx, 'Report approved ✓', OrgColors.success);
  }

  Future<void> _reject(BuildContext ctx, String id, String title) async {
    final ok = await _confirm(ctx,
        title: 'Reject Report',
        body: 'Reject "$title"?',
        confirmLabel: 'Reject',
        confirmColor: OrgColors.error);
    if (!ok) return;
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(id)
        .update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()});
    await activity_log.ActivityLogger.log(action: 'reject_report', module: 'adviser_approvals',
        details: {'orgId': orgId, 'reportId': id, 'title': title});
    _snack(ctx, 'Report rejected', OrgColors.error);
  }

  @override
  Widget build(BuildContext context) {
    return _TabShell(
      stream: _stream,
      emptyIcon: Icons.summarize_outlined,
      emptyMessage: 'No pending reports',
      emptySubtitle: 'Financial and accomplishment reports will appear here',
      itemBuilder: (ctx, doc) {
        final d     = doc.data() as Map<String, dynamic>;
        final title = d['title'] ?? 'Untitled';
        return _ReportCard(
          data:      d,
          onApprove: () => _approve(ctx, doc.id, title),
          onReject:  () => _reject(ctx, doc.id, title),
          onView:    () => _showReportDetail(ctx, d),
        );
      },
    );
  }

  void _showReportDetail(BuildContext ctx, Map<String, dynamic> d) {
    final type = d['type'] == 'financial' ? 'Financial Report' : 'Accomplishment Report';
    showDialog(
      context: ctx,
      builder: (_) => _DetailDialog(
        title: d['title'] ?? 'Report Details',
        icon: Icons.summarize_outlined,
        iconColor: OrgColors.purple,
        rows: [
          _DetailRow('Type',        type),
          _DetailRow('Description', d['description'] ?? '—'),
          _DetailRow('Submitted',   _fmtTs(d['submittedAt'])),
        ],
        attachmentUrl: d['fileUrl'] as String?,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// REPORT CARD
// ─────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove, onReject, onView;

  const _ReportCard({
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] == 'financial' ? 'Financial' : 'Accomplishment';
    return _ItemCard(
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: OrgColors.purpleBg, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.article_outlined, color: OrgColors.purple, size: 20),
      ),
      title: data['title'] ?? 'Untitled',
      subtitle: '$type Report  ·  ${_fmtTs(data['submittedAt'])}',
      statusChip: _StatusPill(status: data['status'] ?? 'pending'),
      meta: _fmtTs(data['submittedAt']),
      metaIcon: Icons.calendar_today_outlined,
      onView: onView,
      actions: [
        _ActionBtn(
          icon: Icons.check_rounded,
          label: 'Approve',
          color: OrgColors.success,
          bg: OrgColors.successBg,
          onTap: onApprove,
        ),
        const SizedBox(width: 8),
        _ActionBtn(
          icon: Icons.close_rounded,
          label: 'Reject',
          color: OrgColors.error,
          bg: OrgColors.errorBg,
          onTap: onReject,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// TAB SHELL — wraps loading / empty / list for every tab
// ─────────────────────────────────────────────────────────────────────
class _TabShell extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final IconData emptyIcon;
  final String emptyMessage, emptySubtitle;
  final Widget Function(BuildContext, QueryDocumentSnapshot) itemBuilder;

  const _TabShell({
    required this.stream,
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
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _Empty(icon: emptyIcon, message: emptyMessage, subtitle: emptySubtitle);
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
// ITEM CARD  — shared layout for all three tabs
// ─────────────────────────────────────────────────────────────────────
class _ItemCard extends StatefulWidget {
  final Widget leading;
  final String title, subtitle;
  final Widget statusChip;
  final String meta;
  final IconData metaIcon;
  final VoidCallback onView;
  final List<Widget> actions;

  const _ItemCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.statusChip,
    required this.meta,
    required this.metaIcon,
    required this.onView,
    required this.actions,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
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
            color: _hover ? OrgColors.primaryDark.withOpacity(0.25) : OrgColors.mediumGray,
          ),
          boxShadow: _hover
              ? [BoxShadow(color: OrgColors.primaryDark.withOpacity(0.07),
                  blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            // Leading icon
            widget.leading,
            const SizedBox(width: 14),

            // Title + subtitle
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(widget.subtitle,
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 16),

            // Status chip
            widget.statusChip,
            const SizedBox(width: 16),

            // Meta date
            Row(children: [
              Icon(widget.metaIcon, size: 13, color: OrgColors.darkGray),
              const SizedBox(width: 4),
              Text(widget.meta,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
            ]),
            const SizedBox(width: 16),

            // View button
            InkWell(
              onTap: widget.onView,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: OrgColors.lightGray,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: OrgColors.mediumGray),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_outlined, size: 14, color: OrgColors.darkGray),
                  const SizedBox(width: 4),
                  Text('View', style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
                ]),
              ),
            ),
            const SizedBox(width: 10),

            // Action buttons
            ...widget.actions,
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
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
          border: Border.all(color: color.withOpacity(0.25)),
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
// STATUS PILL
// ─────────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status.toLowerCase()) {
      case 'approved':
        bg = OrgColors.successBg; fg = OrgColors.success; label = 'Approved'; break;
      case 'rejected':
        bg = OrgColors.errorBg;   fg = OrgColors.error;   label = 'Rejected'; break;
      case 'for_review':
        bg = OrgColors.infoBg;    fg = OrgColors.info;    label = 'For Review'; break;
      case 'replied':
        bg = OrgColors.successBg; fg = OrgColors.success; label = 'Replied'; break;
      case 'review':
        bg = OrgColors.purpleBg;  fg = OrgColors.purple;  label = 'On Review'; break;
      default:
        bg = OrgColors.warningBg; fg = OrgColors.primaryDark; label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// DETAIL DIALOG
// ─────────────────────────────────────────────────────────────────────
class _DetailRow {
  final String label, value;
  const _DetailRow(this.label, this.value);
}

class _DetailDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_DetailRow> rows;
  final String? attachmentUrl;

  const _DetailDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.rows,
    this.attachmentUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 32, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: const Border(bottom: BorderSide(color: OrgColors.mediumGray)),
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
                        fontSize: 15, fontWeight: FontWeight.w700, color: OrgColors.charcoal),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...rows.map((r) => _row(r.label, r.value)),
                  if (attachmentUrl != null) ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Attachment',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, fontWeight: FontWeight.w700, color: OrgColors.darkGray)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.attach_file, size: 15, color: OrgColors.darkGray),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          Uri.decodeFull(
                              attachmentUrl!.split('/').last.split('?').first),
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12, color: OrgColors.info,
                              decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: attachmentUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('URL copied')));
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.copy, size: 15, color: OrgColors.darkGray),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(attachmentUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.open_in_new, size: 15, color: OrgColors.info),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OrgColors.mediumGray)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrgColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Close',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal)),
        ),
      ]),
    );
  }
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
            color: OrgColors.lightGray,
            borderRadius: BorderRadius.circular(18),
          ),
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
            color: OrgColors.successBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, size: 14, color: OrgColors.success),
            const SizedBox(width: 5),
            Text('All caught up!',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.success)),
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
        Text('Failed to load', style: GoogleFonts.beVietnamPro(
            fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
        const SizedBox(height: 4),
        Text(message, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
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

Future<bool> _confirm(
  BuildContext ctx, {
  required String title,
  required String body,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: ctx,
    builder: (dctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
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
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: confirmColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              confirmColor == OrgColors.error
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: confirmColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(dctx, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: OrgColors.mediumGray),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Cancel',
                    style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(confirmLabel,
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return result == true;
}

void _snack(BuildContext ctx, String msg, Color color) {
  if (!ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: GoogleFonts.beVietnamPro(color: Colors.white)),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}

