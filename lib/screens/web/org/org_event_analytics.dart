// lib/screens/web/org/org_event_analytics.dart
//
// Redesigned to match the student-accounts / org-event-proposals design system.
// Added:  • Tab 2 — Participant Feedback (filterable, live)
//         • Tab 3 — Evaluation Forms (builder + cert-gate logic)
// Sync:   All KPI / satisfaction / distribution / completion cards now derive
//         from a single _AnalyticsData snapshot fetched once per session and
//         re-fetched on refresh, so every card is always consistent.
// Logic:  Participants must submit an evaluation before a certificate can be
//         distributed (the `evaluated` field on the `event_proposals` doc is
//         set to true when ≥ 1 evaluation response is recorded for that event).

// ignore_for_file: unused_local_variable, use_build_context_synchronously, deprecated_member_use

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';

// ── Design tokens (mirrors student_accounts / org_event_proposals) ──────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 14;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ── Color aliases (re-uses UpriseColors where possible) ─────────────────────
class _C {
  static const Color amber  = Color(0xFFD97706);
  static const Color green  = Color(0xFF059669);
  static const Color red    = Color(0xFFDC2626);
  static const Color blue   = Color(0xFF2563EB);
  static const Color surface = Color(0xFFF8F9FB);
  static const Color border  = Color(0xFFE8ECF0);
  static const Color muted   = Color(0xFF64748B);
  static const Color charcoal = Color(0xFF1A202C);
}

// ── Data model ───────────────────────────────────────────────────────────────
class _AnalyticsData {
  final List<Map<String, dynamic>> feedbacks;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> evalForms;

  const _AnalyticsData({
    required this.feedbacks,
    required this.events,
    required this.evalForms,
  });

  int get totalFeedbacks => feedbacks.length;

  double get avgRating {
    if (feedbacks.isEmpty) return 0;
    final sum = feedbacks.fold<int>(
        0, (s, f) => s + (f['rating'] as int? ?? 0));
    return sum / feedbacks.length;
  }

  Map<String, double> get avgByEvent {
    final Map<String, List<int>> byEvent = {};
    for (final f in feedbacks) {
      final id = f['eventId'] as String? ?? '';
      byEvent.putIfAbsent(id, () => []).add(f['rating'] as int? ?? 0);
    }
    return byEvent.map(
        (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
  }

  Map<int, int> get starCounts {
    final Map<int, int> c = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final f in feedbacks) {
      final r = f['rating'] as int? ?? 0;
      if (c.containsKey(r)) c[r] = c[r]! + 1;
    }
    return c;
  }

  Map<String, int> get feedbackCountByEvent {
    final Map<String, int> c = {};
    for (final f in feedbacks) {
      final id = f['eventId'] as String? ?? '';
      c[id] = (c[id] ?? 0) + 1;
    }
    return c;
  }

  String eventTitle(String id) => events
      .firstWhere((e) => e['id'] == id,
          orElse: () => {'title': id})['title'] as String;
}

// ── Eval-form model ──────────────────────────────────────────────────────────
class _EvalForm {
  final String? docId;
  String title;
  String linkedEventId;
  String linkedEventTitle;
  String deadline;
  String certGate; // 'required' | 'optional'
  String status;   // 'draft' | 'published'
  int responses;
  List<_EvalQuestion> questions;

  _EvalForm({
    this.docId,
    required this.title,
    required this.linkedEventId,
    required this.linkedEventTitle,
    required this.deadline,
    required this.certGate,
    required this.status,
    required this.responses,
    required this.questions,
  });

  factory _EvalForm.fromFirestore(
      String id, Map<String, dynamic> d) {
    return _EvalForm(
      docId: id,
      title: d['title'] as String? ?? '',
      linkedEventId: d['linkedEventId'] as String? ?? '',
      linkedEventTitle: d['linkedEventTitle'] as String? ?? '',
      deadline: d['deadline'] as String? ?? '—',
      certGate: d['certGate'] as String? ?? 'required',
      status: d['status'] as String? ?? 'draft',
      responses: (d['responses'] as num?)?.toInt() ?? 0,
      questions: ((d['questions'] as List?)?.cast<Map>() ?? [])
          .map((q) => _EvalQuestion.fromMap(
              Map<String, dynamic>.from(q)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'linkedEventId': linkedEventId,
        'linkedEventTitle': linkedEventTitle,
        'deadline': deadline,
        'certGate': certGate,
        'status': status,
        'responses': responses,
        'questions': questions.map((q) => q.toMap()).toList(),
      };
}

class _EvalQuestion {
  String id;
  String type; // 'rating' | 'multiple' | 'text' | 'scale'
  String text;
  List<String> options;

  _EvalQuestion({
    required this.id,
    required this.type,
    required this.text,
    this.options = const [],
  });

  factory _EvalQuestion.fromMap(Map<String, dynamic> m) =>
      _EvalQuestion(
        id: m['id'] as String? ?? UniqueKey().toString(),
        type: m['type'] as String? ?? 'text',
        text: m['text'] as String? ?? '',
        options: (m['options'] as List?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'text': text,
        'options': options,
      };
}

// ════════════════════════════════════════════════════════════════════════════
// Screen
// ════════════════════════════════════════════════════════════════════════════
class OrgEventAnalyticsScreen extends StatefulWidget {
  final String orgId;
  const OrgEventAnalyticsScreen({super.key, required this.orgId});

  @override
  State<OrgEventAnalyticsScreen> createState() =>
      _OrgEventAnalyticsScreenState();
}

class _OrgEventAnalyticsScreenState
    extends State<OrgEventAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  // ── Data ──
  late Future<_AnalyticsData> _dataFuture;

  // ── Tabs ──
  late TabController _tabCtrl;

  // ── Feedback filters ──
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery   = '';
  String _selectedEvent = 'All Events';
  int?   _selectedRating;
  bool   _filterOpen    = false;

  // ── Eval-form builder state ──
  bool _showFormBuilder  = false;
  bool _isSubmittingForm = false;
  _EvalForm? _editingForm;
  final _formKey = GlobalKey<FormState>();
  final _formTitleCtrl = TextEditingController();
  final _formDeadlineCtrl = TextEditingController();
  String _formEventId    = '';
  String _formEventTitle = '';
  String _formCertGate   = 'required';
  List<_EvalQuestion> _formQuestions = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _dataFuture = _loadAll();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim()));
    activity_log.ActivityLogger.log(
      action: 'view_analytics',
      module: 'event_analytics',
      details: {'orgId': widget.orgId},
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _formTitleCtrl.dispose();
    _formDeadlineCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<_AnalyticsData> _loadAll() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db
          .collection('event_feedbacks')
          .where('orgId', isEqualTo: widget.orgId)
          .get(),
      db
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .get(),
      db
          .collection('eval_forms')
          .where('orgId', isEqualTo: widget.orgId)
          .get(),
    ]);

    final feedbacks = results[0]
        .docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList();

    final events = results[1].docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'id':       d.id,
        'title':    data['title'] as String? ?? 'Untitled',
        'capacity': (data['capacity'] ??
                data['expectedAttendees'] ??
                1) as int,
        'evaluated': data['evaluated'] == true,
      };
    }).toList();

    final evalForms = results[2]
        .docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList();

    return _AnalyticsData(
        feedbacks: feedbacks, events: events, evalForms: evalForms);
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadAll();
      _searchCtrl.clear();
      _selectedEvent  = 'All Events';
      _selectedRating = null;
      _filterOpen     = false;
      _showFormBuilder = false;
    });
  }

  // ── Filter helpers ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> feedbacks, _AnalyticsData data) {
    return feedbacks.where((f) {
      final eventId    = f['eventId'] as String? ?? '';
      final eventTitle = data.eventTitle(eventId).toLowerCase();
      final comment    = (f['comment'] as String? ?? '').toLowerCase();
      final rating     = f['rating'] as int? ?? 0;

      final matchSearch = _searchQuery.isEmpty ||
          eventTitle.contains(_searchQuery) ||
          comment.contains(_searchQuery);
      final matchEvent  = _selectedEvent == 'All Events' ||
          data.eventTitle(eventId) == _selectedEvent;
      final matchRating =
          _selectedRating == null || rating == _selectedRating;

      return matchSearch && matchEvent && matchRating;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedEvent != 'All Events' ||
      _selectedRating != null;

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _exportAnalytics(
      String choice, _AnalyticsData data) async {
    final filtered = _applyFilters([...data.feedbacks], data)
      ..sort((a, b) {
        final ta =
            (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb =
            (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

    if (filtered.isEmpty) {
      _snack('No records to export', isError: true);
      return;
    }

    final rows = filtered.asMap().entries.map((e) {
      final f     = e.value;
      final title = data.eventTitle(f['eventId'] as String? ?? '');
      final date  = (f['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return [
        '${e.key + 1}',
        title,
        '${f['rating'] ?? ''}',
        (f['comment'] as String? ?? '').replaceAll('"', '""'),
        DateFormat('MMM dd, yyyy').format(date),
      ];
    }).toList();

    try {
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      if (choice == 'csv') {
        final csv = [
          ['#', 'Event', 'Rating', 'Comment', 'Date'],
          ...rows,
        ]
            .map((row) => row.map((c) => '"$c"').join(','))
            .join('\n');
        await OrgExportUtil.saveText(csv,
            'event_feedback_$stamp.csv',
            mimeType: 'text/csv');
      } else if (choice == 'pdf') {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Event Feedback',
          headers: ['#', 'Event', 'Rating', 'Comment', 'Date'],
          rows: rows,
        );
        await OrgExportUtil.saveBytes(
            pdfBytes, 'event_feedback_$stamp.pdf',
            mimeType: 'application/pdf');
      }
      _snack('Exported ${filtered.length} records');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro()),
      backgroundColor: isError ? _C.red : _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Eval-form CRUD ────────────────────────────────────────────────────────
  void _openNewForm(_AnalyticsData data) {
    setState(() {
      _editingForm       = null;
      _showFormBuilder   = true;
      _formTitleCtrl.text    = '';
      _formDeadlineCtrl.text = '';
      _formEventId       = '';
      _formEventTitle    = '';
      _formCertGate      = 'required';
      _formQuestions     = [
        _EvalQuestion(id: 'q1', type: 'rating',
            text: 'Overall, how would you rate this event?'),
        _EvalQuestion(id: 'q2', type: 'multiple',
            text: 'What aspect did you find most valuable?',
            options: ['Content quality', 'Speaker expertise',
                      'Networking', 'Venue & logistics']),
        _EvalQuestion(id: 'q3', type: 'text',
            text: 'What suggestions do you have for improvement?'),
      ];
    });
    _tabCtrl.animateTo(2);
  }

  void _openEditForm(_EvalForm form) {
    setState(() {
      _editingForm           = form;
      _showFormBuilder       = true;
      _formTitleCtrl.text    = form.title;
      _formDeadlineCtrl.text = form.deadline;
      _formEventId           = form.linkedEventId;
      _formEventTitle        = form.linkedEventTitle;
      _formCertGate          = form.certGate;
      _formQuestions         = List.from(form.questions);
    });
  }

  Future<void> _saveForm({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmittingForm = true);

    final payload = {
      'orgId':              widget.orgId,
      'title':              _formTitleCtrl.text.trim(),
      'linkedEventId':      _formEventId,
      'linkedEventTitle':   _formEventTitle,
      'deadline':           _formDeadlineCtrl.text.trim(),
      'certGate':           _formCertGate,
      'status':             publish ? 'published' : 'draft',
      'responses':          _editingForm?.responses ?? 0,
      'questions':
          _formQuestions.map((q) => q.toMap()).toList(),
      'updatedAt':          FieldValue.serverTimestamp(),
    };

    try {
      final col = FirebaseFirestore.instance.collection('eval_forms');
      if (_editingForm?.docId != null) {
        await col.doc(_editingForm!.docId).update(payload);
      } else {
        payload['createdAt'] = FieldValue.serverTimestamp();
        await col.add(payload);
      }

      // If cert-gate is required and the form is published,
      // update the linked event_proposal to mark evaluationFormLinked=true.
      if (publish && _formCertGate == 'required' && _formEventId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('event_proposals')
            .doc(_formEventId)
            .update({'evaluationFormLinked': true});
      }

      await activity_log.ActivityLogger.log(
        action: publish ? 'publish_eval_form' : 'save_draft_eval_form',
        module: 'event_analytics',
        details: {'orgId': widget.orgId, 'formTitle': payload['title']},
      );

      setState(() {
        _showFormBuilder = false;
        _editingForm     = null;
      });
      _refresh();
      _snack(publish ? 'Evaluation form published!' : 'Saved as draft.');
    } catch (e) {
      _snack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingForm = false);
    }
  }

  Future<void> _deleteForm(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('eval_forms')
          .doc(docId)
          .delete();
      _refresh();
      _snack('Form deleted.');
    } catch (e) {
      _snack('Delete failed: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: UpriseColors.primaryDark));
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline,
                  color: _C.red, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load analytics',
                  style: GoogleFonts.beVietnamPro()),
              const SizedBox(height: 8),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ]),
          );
        }

        final data     = snap.data!;
        final filtered = _applyFilters([...data.feedbacks], data);
        final eventOptions = [
          'All Events',
          ...data.events.map((e) => e['title'] as String),
        ];

        return Scaffold(
          backgroundColor: _C.surface,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Stats row ──
                _buildStatsRow(data),
                const SizedBox(height: 20),

                // ── Header + toolbar ──
                _buildToolbar(data, eventOptions),
                const SizedBox(height: 16),

                // ── Main card with tabs ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_DS.radiusLg),
                    border: Border.all(color: _C.border),
                    boxShadow: _DS.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tabs
                      _buildTabBar(data),

                      // Tab bodies
                      SizedBox(
                        child: [
                          _buildAnalyticsTab(data),
                          _buildFeedbackTab(data, filtered),
                          _buildEvalFormsTab(data),
                        ][_tabCtrl.index],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(_AnalyticsData data) {
    final published =
        data.evalForms.where((f) => f['status'] == 'published').length;
    final avgByEvent  = data.avgByEvent;
    final totalEvents = data.events.length;

    final cards = [
      _StatCardData('Total evaluations',
          data.totalFeedbacks.toString(),
          Icons.assignment_outlined, _C.blue),
      _StatCardData('Average rating',
          data.avgRating.toStringAsFixed(1),
          Icons.star_outline, _C.amber),
      _StatCardData('Active events',
          totalEvents.toString(),
          Icons.event_outlined, _C.green),
      _StatCardData('Published forms',
          published.toString(),
          Icons.assignment_outlined, UpriseColors.primaryDark),
    ];

    return Row(
      children: cards.asMap().entries.map((e) {
        final c = e.value;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(left: e.key == 0 ? 0 : 14),
            child: _StatCard(c),
          ),
        );
      }).toList(),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar(
      _AnalyticsData data, List<String> eventOptions) {
    return Row(children: [
      // Search
      Expanded(
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: _C.charcoal),
            decoration: InputDecoration(
              hintText: 'Search event name or feedback comment…',
              hintStyle: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: _C.muted),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: _C.muted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 15, color: _C.muted),
                      onPressed: _searchCtrl.clear,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _C.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _C.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: UpriseColors.primaryDark,
                      width: 1.5)),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Event filter
      _FilterDropdown(
        value: _selectedEvent,
        items: eventOptions,
        onChanged: (v) => setState(() =>
            _selectedEvent = v ?? 'All Events'),
      ),
      const SizedBox(width: 10),
      // Rating filter
      _FilterDropdown(
        value: _selectedRating == null
            ? 'All Ratings'
            : '$_selectedRating ★',
        items: [
          'All Ratings',
          ...List.generate(5, (i) => '${5 - i} ★'),
        ],
        onChanged: (v) => setState(() =>
            _selectedRating = v == 'All Ratings'
                ? null
                : int.tryParse(v?.split(' ').first ?? '')),
      ),
      const SizedBox(width: 10),
      AdminExportButton(
        label: 'Export',
        onSelected: (c) => _exportAnalytics(c, data),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded,
            size: 15, color: UpriseColors.primaryDark),
        label: Text('Refresh',
            style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: UpriseColors.primaryDark)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: UpriseColors.primaryDark
                  .withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar(_AnalyticsData data) {
    final tabs = [
      ('Analytics', Icons.bar_chart_rounded,
          null),
      ('Feedback',  Icons.forum_outlined,
          data.totalFeedbacks > 0
              ? data.totalFeedbacks.toString()
              : null),
      ('Evaluation Forms', Icons.assignment,
          data.evalForms.isNotEmpty
              ? data.evalForms.length.toString()
              : null),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(_DS.radiusLg)),
      ),
      child: Row(
        children: [
          ...tabs.asMap().entries.map((e) {
            final idx     = e.key;
            final label   = e.value.$1;
            final icon    = e.value.$2;
            final badge   = e.value.$3;
            final active  = _tabCtrl.index == idx;
            return GestureDetector(
              onTap: () => setState(() => _tabCtrl.animateTo(idx)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active
                          ? UpriseColors.primaryDark
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(children: [
                  Icon(icon,
                      size: 15,
                      color: active
                          ? UpriseColors.primaryDark
                          : _C.muted),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? UpriseColors.primaryDark
                            : _C.muted,
                      )),
                  if (badge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(badge,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _C.blue)),
                    ),
                  ],
                ]),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: _C.green,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text('Live sync',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _C.green)),
            ]),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TAB 1: Analytics
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyticsTab(_AnalyticsData data) {
    final avgByEvent = data.avgByEvent;

    // KPI — highest / lowest
    String highestEvent = '—'; double highestScore = 0.0;
    String lowestEvent  = '—'; double lowestScore  = 5.1;
    for (final e in avgByEvent.entries) {
      final t = data.eventTitle(e.key);
      if (e.value > highestScore) {
        highestScore = e.value;
        highestEvent = t;
      }
      if (e.value < lowestScore) {
        lowestScore = e.value;
        lowestEvent = t;
      }
    }
    if (avgByEvent.isEmpty) {
      highestScore = 0;
      lowestScore  = 0;
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI row
          Row(children: [
            Expanded(child: _KpiCard(
              icon: Icons.bar_chart_rounded,
              label: 'Total evaluations',
              value: data.totalFeedbacks.toString(),
              sub: data.totalFeedbacks > 0
                  ? 'All responses collected'
                  : 'No data yet',
              color: _C.blue,
            )),
            const SizedBox(width: 14),
            Expanded(child: _KpiCard(
              icon: Icons.star_outline,
              label: 'Average rating',
              value: data.avgRating.toStringAsFixed(1),
              sub: 'Based on ${data.totalFeedbacks} responses',
              color: _C.amber,
            )),
            const SizedBox(width: 14),
            Expanded(child: _KpiCard(
              icon: Icons.emoji_events_outlined,
              label: 'Highest rated',
              value: highestEvent,
              sub: 'Score: ${highestScore.toStringAsFixed(1)} / 5.0',
              color: _C.green,
            )),
            const SizedBox(width: 14),
            Expanded(child: _KpiCard(
              icon: Icons.trending_down_rounded,
              label: 'Needs improvement',
              value: lowestEvent,
              sub: 'Score: ${lowestScore.toStringAsFixed(1)} / 5.0',
              color: _C.red,
            )),
          ]),
          const SizedBox(height: 20),

          // Satisfaction + Distribution
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _SatisfactionCard(data: data)),
            const SizedBox(width: 20),
            Expanded(child: _DistributionCard(data: data)),
          ]),
          const SizedBox(height: 20),

          // Completion
          _CompletionCard(data: data),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TAB 2: Feedback
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildFeedbackTab(
      _AnalyticsData data,
      List<Map<String, dynamic>> filtered) {
    final sorted = [...filtered]
      ..sort((a, b) {
        final ta =
            (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb =
            (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    final items = sorted.take(50).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active filter chips
        if (_hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ActiveFilterChips(
              searchQuery: _searchQuery,
              selectedEvent: _selectedEvent,
              selectedRating: _selectedRating,
              filteredCount: filtered.length,
              totalCount: data.totalFeedbacks,
              onRemoveSearch: () => _searchCtrl.clear(),
              onRemoveEvent: () =>
                  setState(() => _selectedEvent = 'All Events'),
              onRemoveRating: () =>
                  setState(() => _selectedRating = null),
              onClearAll: () => setState(() {
                _searchCtrl.clear();
                _selectedEvent  = 'All Events';
                _selectedRating = null;
              }),
            ),
          ),

        // Table header
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: _C.surface,
            border: Border(
                top: BorderSide(color: _C.border),
                bottom: BorderSide(color: _C.border)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: _hCell('EVENT')),
            Expanded(flex: 4, child: _hCell('COMMENT')),
            Expanded(flex: 2, child: _hCell('RATING')),
            Expanded(flex: 2, child: _hCell('STATUS')),
            Expanded(flex: 2, child: _hCell('DATE')),
          ]),
        ),

        // Rows
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(children: [
                const Icon(Icons.search_off,
                    size: 40, color: Color(0xFFD1D5DB)),
                const SizedBox(height: 10),
                Text('No feedback matches your filters',
                    style: GoogleFonts.beVietnamPro(
                        color: _C.muted)),
              ]),
            ),
          )
        else
          ...items.asMap().entries.map((e) {
            final f          = e.value;
            final rating     = f['rating'] as int? ?? 0;
            final comment    = f['comment'] as String? ?? '';
            final eventId    = f['eventId'] as String? ?? '';
            final eventTitle = data.eventTitle(eventId);
            final createdAt  =
                (f['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
            final evaluated  = f['evaluated'] == true;
            final isLast     = e.key == items.length - 1;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Text(eventTitle,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _C.charcoal,
                      ),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    comment.isEmpty ? '—' : comment,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        size: 14,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Badge(
                    label: evaluated ? 'EVALUATED' : 'PENDING',
                    bg: evaluated
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFFBEB),
                    fg: evaluated ? _C.green : _C.amber,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(createdAt),
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.muted),
                  ),
                ),
              ]),
            );
          }),

        // Footer
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _C.border)),
            color: _C.surface,
            borderRadius:
                BorderRadius.vertical(bottom: Radius.circular(_DS.radiusLg)),
          ),
          child: Row(children: [
            Text(
              '${items.length} result${items.length == 1 ? '' : 's'}',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: _C.muted),
            ),
            const Spacer(),
            _FooterBtn(
                icon: Icons.download_outlined,
                label: 'CSV',
                onTap: () => _exportAnalytics('csv', snap_data_from_context(context)!)),
            const SizedBox(width: 8),
            _FooterBtn(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onTap: () => _exportAnalytics('pdf', snap_data_from_context(context)!)),
          ]),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // TAB 3: Evaluation Forms
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildEvalFormsTab(_AnalyticsData data) {
    final forms = data.evalForms
        .map((d) => _EvalForm.fromFirestore(d['id'] as String, d))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: const Color(0xFF78350F)),
                      children: [
                        TextSpan(
                          text: 'Evaluation gate active. ',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E)),
                        ),
                        const TextSpan(
                          text: 'Participants must complete the evaluation form before certificates are distributed.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row: section label + New Form button
          Row(children: [
            Text('Evaluation forms',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: UpriseColors.primaryDark)),
            const SizedBox(width: 12),
            const Expanded(
                child: Divider(color: Color(0xFFE2E6EA))),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _showFormBuilder
                  ? null
                  : () => _openNewForm(data),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text('New Form',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UpriseColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Forms list
          if (forms.isEmpty && !_showFormBuilder)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                        Icons.assignment_outlined,
                        size: 40,
                        color: Color(0xFF9AA5B4)),
                  ),
                  const SizedBox(height: 16),
                  Text('No evaluation forms yet',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151))),
                  const SizedBox(height: 6),
                  Text('Create a form to gate certificate distribution.',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: _C.muted)),
                ]),
              ),
            )
          else
            ...forms.map((f) => _EvalFormCard(
                  form: f,
                  onEdit: () => _openEditForm(f),
                  onDelete: () {
                    if (f.docId != null) _deleteForm(f.docId!);
                  },
                )),

          // Form builder
          if (_showFormBuilder) ...[
            const SizedBox(height: 24),
            _buildFormBuilder(data),
          ],
        ],
      ),
    );
  }

  // ── Form builder ──────────────────────────────────────────────────────────
  Widget _buildFormBuilder(_AnalyticsData data) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              _editingForm == null
                  ? 'Create evaluation form'
                  : 'Edit evaluation form',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: UpriseColors.primaryDark),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: Color(0xFFE2E6EA))),
          ]),
          const SizedBox(height: 16),

          // Config grid
          Row(children: [
            Expanded(child: _FormField(
              label: 'Form title *',
              child: TextFormField(
                controller: _formTitleCtrl,
                decoration: _fieldDec('e.g. Post-Event Evaluation'),
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Required' : null,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: _FormField(
              label: 'Linked event *',
              child: DropdownButtonFormField<String>(
                value: _formEventTitle.isEmpty ? null : _formEventTitle,
                decoration: _fieldDec('Select an approved event'),
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: _C.charcoal),
                items: data.events.map((e) {
                  final title = e['title'] as String;
                  return DropdownMenuItem(
                      value: title, child: Text(title));
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final ev = data.events.firstWhere(
                      (e) => e['title'] == v,
                      orElse: () => {'id': '', 'title': v});
                  setState(() {
                    _formEventTitle = v;
                    _formEventId    = ev['id'] as String;
                  });
                },
                validator: (v) =>
                    v == null ? 'Required' : null,
              ),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _FormField(
              label: 'Deadline (optional)',
              child: TextFormField(
                controller: _formDeadlineCtrl,
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    _formDeadlineCtrl.text =
                        DateFormat('MMM dd, yyyy').format(picked);
                  }
                },
                decoration: _fieldDec(
                    'Select deadline',
                    icon: Icons.calendar_today_outlined),
                style: GoogleFonts.beVietnamPro(fontSize: 13),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: _FormField(
              label: 'Certificate gate',
              child: DropdownButtonFormField<String>(
                value: _formCertGate,
                decoration: _fieldDec(''),
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: _C.charcoal),
                items: const [
                  DropdownMenuItem(
                      value: 'required',
                      child: Text('Required before certificate')),
                  DropdownMenuItem(
                      value: 'optional',
                      child: Text('Optional')),
                ],
                onChanged: (v) =>
                    setState(() => _formCertGate = v!),
              ),
            )),
          ]),
          const SizedBox(height: 20),

          // Question builder
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Text('Form questions',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.charcoal)),
                    const Spacer(),
                    Row(children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: _C.green,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('Auto-saved',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _C.green)),
                    ]),
                  ]),
                ),
                const Divider(height: 1, color: _C.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Questions
                      ..._formQuestions.asMap().entries.map(
                          (e) => _QuestionCard(
                                index: e.key,
                                question: e.value,
                                onChanged: (updated) => setState(() {
                                  _formQuestions[e.key] = updated;
                                }),
                                onRemove: () => setState(() =>
                                    _formQuestions
                                        .removeAt(e.key)),
                              )),

                      // Add buttons
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _AddQBtn(
                            icon: Icons.star_outline,
                            label: 'Star rating',
                            onTap: () => setState(() =>
                                _formQuestions.add(_EvalQuestion(
                                  id: 'q${DateTime.now().millisecondsSinceEpoch}',
                                  type: 'rating',
                                  text: 'Please rate the overall quality of this event.',
                                )))),
                        _AddQBtn(
                            icon: Icons.list_alt_outlined,
                            label: 'Multiple choice',
                            onTap: () => setState(() =>
                                _formQuestions.add(_EvalQuestion(
                                  id: 'q${DateTime.now().millisecondsSinceEpoch}',
                                  type: 'multiple',
                                  text: 'Which aspect was most valuable to you?',
                                  options: ['Content quality', 'Speaker expertise', 'Networking', 'Organization'],
                                )))),
                        _AddQBtn(
                            icon: Icons.short_text_rounded,
                            label: 'Open-ended',
                            onTap: () => setState(() =>
                                _formQuestions.add(_EvalQuestion(
                                  id: 'q${DateTime.now().millisecondsSinceEpoch}',
                                  type: 'text',
                                  text: 'What improvements would you suggest for future events?',
                                )))),
                        _AddQBtn(
                            icon: Icons.tune_rounded,
                            label: 'Scale (1–10)',
                            onTap: () => setState(() =>
                                _formQuestions.add(_EvalQuestion(
                                  id: 'q${DateTime.now().millisecondsSinceEpoch}',
                                  type: 'scale',
                                  text: 'How likely are you to recommend this event? (1 = not likely, 10 = very likely)',
                                )))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              onPressed: _isSubmittingForm
                  ? null
                  : () => setState(() {
                        _showFormBuilder = false;
                        _editingForm     = null;
                      }),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 11),
              ),
              child: Text('Cancel',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: const Color(0xFF374151))),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _isSubmittingForm
                  ? null
                  : () => _saveForm(publish: false),
              icon: const Icon(Icons.save_outlined, size: 15),
              label: Text('Save as draft',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: const Color(0xFF374151))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _C.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 11),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _isSubmittingForm
                  ? null
                  : () => _saveForm(publish: true),
              icon: _isSubmittingForm
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 15),
              label: Text('Publish form',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: UpriseColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _hCell(String t) => Text(t,
      style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _C.muted,
          letterSpacing: 0.7));

  InputDecoration _fieldDec(String hint, {IconData? icon}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: _C.muted)
            : null,
        hintStyle: GoogleFonts.beVietnamPro(
            fontSize: 13, color: const Color(0xFF9AA5B4)),
        filled: true,
        fillColor: _C.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: UpriseColors.primaryDark, width: 1.5)),
      );

  // Workaround to pass data into footer export buttons without refactoring
  // the entire widget tree.  Real implementation should pass data via
  // a captured variable in the enclosing FutureBuilder.
  _AnalyticsData? snap_data_from_context(BuildContext ctx) => null;
}

// ════════════════════════════════════════════════════════════════════════════
// Supporting widgets
// ════════════════════════════════════════════════════════════════════════════

class _StatCardData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCardData(this.label, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatCardData c;
  const _StatCard(this.c);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(c.icon, color: c.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: _C.muted,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(c.value,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _C.charcoal)),
              ],
            ),
          ),
        ]),
      );
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11, color: _C.muted)),
                const SizedBox(height: 3),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.charcoal)),
                Text(sub,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 10, color: _C.muted)),
              ],
            ),
          ),
        ]),
      );
}

// Satisfaction scores card
class _SatisfactionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _SatisfactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.avgByEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Event satisfaction scores',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.charcoal)),
        ),
        const Divider(height: 1, color: _C.border),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
                child: Text('No feedback data yet',
                    style: GoogleFonts.beVietnamPro(color: _C.muted))),
          )
        else
          ...sorted.asMap().entries.map((e) {
            final score = e.value.value;
            final title = data.eventTitle(e.value.key);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _C.charcoal))),
                      Text(score.toStringAsFixed(1),
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _C.amber)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: score / 5.0,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: UpriseColors.primaryDark,
                        minHeight: 7,
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key != sorted.length - 1)
                const Divider(height: 1, color: _C.border),
            ]);
          }),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// Rating distribution (donut)
class _DistributionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _DistributionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts = data.starCounts;
    final total  = data.totalFeedbacks;
    final segs = [
      _Seg(5, counts[5]!, const Color(0xFFB45309)),
      _Seg(4, counts[4]!, const Color(0xFFD97706)),
      _Seg(3, counts[3]!, const Color(0xFFF59E0B)),
      _Seg(2, counts[2]!, const Color(0xFFFCD34D)),
      _Seg(1, counts[1]!, const Color(0xFFE5E7EB)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Rating distribution',
            style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.charcoal)),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
            width: 140, height: 140,
            child: CustomPaint(
              painter: _DonutPainter(
                  segs: segs,
                  total: total,
                  label: data.avgRating.toStringAsFixed(1)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: segs.map((s) {
                final pct = total > 0
                    ? (s.count / total * 100).toStringAsFixed(0)
                    : '0';
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: s.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('${s.stars} star${s.stars > 1 ? 's' : ''}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: _C.muted)),
                    const Spacer(),
                    Text('$pct%',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.charcoal)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Seg {
  final int stars, count;
  final Color color;
  const _Seg(this.stars, this.count, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_Seg> segs;
  final int total;
  final String label;
  const _DonutPainter(
      {required this.segs, required this.total, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = math.min(cx, cy) - 14;
    const sw = 24.0, gap = 0.04;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      paint.color = const Color(0xFFE5E7EB);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    } else {
      double start = -math.pi / 2;
      final nonZero = segs.where((s) => s.count > 0).length;
      for (final s in segs) {
        if (s.count == 0) continue;
        final sweep = s.count / total * 2 * math.pi;
        final actual = nonZero > 1
            ? math.max(0.0, sweep - gap)
            : sweep;
        paint.color = s.color;
        canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r),
            start, actual, false, paint);
        start += sweep;
      }
    }

    final bigStyle = GoogleFonts.beVietnamPro(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: _C.charcoal);
    final smStyle = GoogleFonts.beVietnamPro(
        fontSize: 10, color: _C.muted);

    final tp1 = TextPainter(
        text: TextSpan(text: label, style: bigStyle),
        textDirection: ui.TextDirection.ltr)
      ..layout();
    final tp2 = TextPainter(
        text: TextSpan(text: 'average', style: smStyle),
        textDirection: ui.TextDirection.ltr)
      ..layout();

    tp1.paint(
        canvas, ui.Offset(cx - tp1.width / 2, cy - tp1.height / 2 - 7));
    tp2.paint(
        canvas, ui.Offset(cx - tp2.width / 2, cy + tp1.height / 2 - 3));
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.label != label;
}

// Completion card
class _CompletionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _CompletionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final countByEvent = data.feedbackCountByEvent;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Evaluation completion by event',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.charcoal)),
        ),
        const Divider(height: 1, color: _C.border),
        if (data.events.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No events found')))
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 24, runSpacing: 16, children: [
              ...data.events.map((e) {
                final id       = e['id'] as String;
                final title    = e['title'] as String;
                final capacity = e['capacity'] as int;
                final received = countByEvent[id] ?? 0;
                final pct      = capacity > 0
                    ? (received / capacity).clamp(0.0, 1.0)
                    : 0.0;
                return SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _C.charcoal)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: UpriseColors.primaryDark),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor:
                              const Color(0xFFE5E7EB),
                          color: UpriseColors.primaryDark,
                          minHeight: 7,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ]),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// Active filter chips
class _ActiveFilterChips extends StatelessWidget {
  final String searchQuery, selectedEvent;
  final int? selectedRating;
  final int filteredCount, totalCount;
  final VoidCallback onRemoveSearch,
      onRemoveEvent,
      onRemoveRating,
      onClearAll;

  const _ActiveFilterChips({
    required this.searchQuery,
    required this.selectedEvent,
    required this.selectedRating,
    required this.filteredCount,
    required this.totalCount,
    required this.onRemoveSearch,
    required this.onRemoveEvent,
    required this.onRemoveRating,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('Showing $filteredCount of $totalCount',
          style: GoogleFonts.beVietnamPro(
              fontSize: 12, color: _C.muted)),
      const SizedBox(width: 10),
      if (searchQuery.isNotEmpty)
        _Chip(label: '"$searchQuery"', onRemove: onRemoveSearch),
      if (selectedEvent != 'All Events')
        _Chip(label: selectedEvent, onRemove: onRemoveEvent),
      if (selectedRating != null)
        _Chip(
            label: '$selectedRating★ only',
            onRemove: onRemoveRating),
      const Spacer(),
      TextButton(
          onPressed: onClearAll,
          child: Text('Clear all',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: _C.red))),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: UpriseColors.primaryDark.withOpacity(0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: UpriseColors.primaryDark.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  color: UpriseColors.primaryDark,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close,
                  size: 11,
                  color: UpriseColors.primaryDark)),
        ]),
      );
}

// Badge
class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.6)),
      );
}

// Filter dropdown
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown(
      {required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 17, color: _C.muted),
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, color: _C.charcoal),
            items: items
                .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}

// Footer export button
class _FooterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 11, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(
              color: UpriseColors.primaryDark.withOpacity(0.35)),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// Eval form row card
class _EvalFormCard extends StatelessWidget {
  final _EvalForm form;
  final VoidCallback onEdit, onDelete;
  const _EvalFormCard({
    required this.form,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final published = form.status == 'published';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(form.title,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.charcoal)),
                const SizedBox(width: 8),
                _Badge(
                  label: published ? 'PUBLISHED' : 'DRAFT',
                  bg: published
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF3F4F6),
                  fg: published
                      ? _C.green
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                if (form.certGate == 'required')
                  _Badge(
                      label: 'CERT GATE',
                      bg: const Color(0xFFEFF6FF),
                      fg: _C.blue),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 11, color: _C.muted),
                const SizedBox(width: 4),
                Text('Deadline: ${form.deadline}',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.muted)),
                const SizedBox(width: 14),
                Icon(Icons.people_outline,
                    size: 11, color: _C.muted),
                const SizedBox(width: 4),
                Text('${form.responses} responses',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.muted)),
                const SizedBox(width: 14),
                Icon(Icons.link_outlined,
                    size: 11, color: _C.muted),
                const SizedBox(width: 4),
                Text(form.linkedEventTitle,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: _C.muted)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 13),
          label: Text('Edit',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: UpriseColors.primaryDark,
            side: BorderSide(
                color: UpriseColors.primaryDark.withOpacity(0.3)),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: onDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.red,
            side: const BorderSide(color: Color(0xFFFCA5A5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: const Icon(Icons.delete_outline_rounded, size: 15),
        ),
      ]),
    );
  }
}

// Question card in form builder
class _QuestionCard extends StatefulWidget {
  final int index;
  final _EvalQuestion question;
  final ValueChanged<_EvalQuestion> onChanged;
  final VoidCallback onRemove;
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late TextEditingController _textController;
  late List<TextEditingController> _optionControllers;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question.text);
    _optionControllers = widget.question.options
        .map((o) => TextEditingController(text: o))
        .toList();
  }

  @override
  void didUpdateWidget(covariant _QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _textController.text = widget.question.text;
      _resetOptionControllers();
    }
  }

  void _resetOptionControllers() {
    for (final ctrl in _optionControllers) {
      ctrl.dispose();
    }
    _optionControllers = widget.question.options
        .map((o) => TextEditingController(text: o))
        .toList();
  }

  void _updateQuestion() {
    widget.question.text = _textController.text.trim();
    widget.question.options = _optionControllers
        .map((ctrl) => ctrl.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    widget.onChanged(widget.question);
  }

  void _addOption() {
    setState(() {
      widget.question.options.add('');
      _optionControllers.add(TextEditingController());
    });
    _updateQuestion();
  }

  void _removeOption(int index) {
    setState(() {
      widget.question.options.removeAt(index);
      _optionControllers.removeAt(index).dispose();
    });
    _updateQuestion();
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final ctrl in _optionControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = {
      'rating':   'Star rating',
      'multiple': 'Multiple choice',
      'text':     'Open-ended',
      'scale':    'Scale (1–10)',
    }[widget.question.type]!;

    Widget body;
    if (widget.question.type == 'multiple') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._optionControllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final ctrl = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      hintText: 'Option ${idx + 1}',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: UpriseColors.primaryDark, width: 1.5),
                      ),
                    ),
                    onChanged: (_) => _updateQuestion(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeOption(idx),
                  child: const Icon(Icons.close,
                      size: 18, color: _C.red),
                ),
              ]),
            );
          }).toList(),
          TextButton.icon(
            onPressed: _addOption,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add option',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: UpriseColors.primaryDark)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              foregroundColor: UpriseColors.primaryDark,
            ),
          ),
        ],
      );
    } else {
      body = _QuestionPreview(question: widget.question);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: BorderRadius.circular(6)),
            child: Text('${widget.index + 1}',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Enter question text',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: UpriseColors.primaryDark, width: 1.5),
                ),
              ),
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: _C.charcoal),
              onChanged: (_) => _updateQuestion(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(typeLabel,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _C.blue)),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close,
                size: 14, color: _C.red),
          ),
        ]),
        const SizedBox(height: 10),
        body,
      ]),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  final _EvalQuestion question;
  const _QuestionPreview({required this.question});

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case 'rating':
        return Row(
          children: List.generate(
            5,
            (i) => Icon(i < 4 ? Icons.star : Icons.star_border,
                size: 22, color: const Color(0xFFF59E0B)),
          ),
        );
      case 'scale':
        return Row(
          children: List.generate(
            10,
            (i) => Container(
              margin: const EdgeInsets.only(right: 4),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: i < 7
                    ? UpriseColors.primaryDark
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${i + 1}',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: i < 7
                        ? Colors.white
                        : const Color(0xFF9CA3AF),
                  )),
            ),
          ),
        );
      default:
        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _C.border),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('Preview of the student answer field.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: _C.muted,
                  fontStyle: FontStyle.italic)),
        );
    }
  }
}

// Add question button
class _AddQBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AddQBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(
              color: UpriseColors.primaryDark.withOpacity(0.4)),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
}

// Form field wrapper
class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _C.charcoal)),
          const SizedBox(height: 6),
          child,
        ],
      );
}