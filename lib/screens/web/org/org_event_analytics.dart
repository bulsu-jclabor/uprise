// lib/screens/web/org/org_event_analytics.dart

import 'dart:async';
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
import '../../../theme/app_theme.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final cardShadowHover = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
  );
}

// ── Color aliases ────────────────────────────────────────────────────────────
class _C {
  static const Color amber = Color(0xFFF59E0B);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color muted = Color(0xFF64748B);
  static const Color charcoal = Color(0xFF0F172A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
}

// ── Data model ───────────────────────────────────────────────────────────────
class _AnalyticsData {
  final List<Map<String, dynamic>> feedbacks;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> evalForms;

  final Map<String, String> _eventTitleCache = {};

  _AnalyticsData({
    required this.feedbacks,
    required this.events,
    required this.evalForms,
  });

  int get totalFeedbacks => feedbacks.length;

  double get avgRating {
    if (feedbacks.isEmpty) return 0;
    final sum = feedbacks.fold<int>(
      0,
      (s, f) => s + (f['rating'] as int? ?? 0),
    );
    return sum / feedbacks.length;
  }

  Map<String, double> get avgByEvent {
    final Map<String, List<int>> byEvent = {};
    for (final f in feedbacks) {
      final id = f['eventId'] as String? ?? '';
      byEvent.putIfAbsent(id, () => []).add(f['rating'] as int? ?? 0);
    }
    return byEvent.map(
      (k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length),
    );
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

  /// Matches an eventId against known events using several strategies.
  /// Returns the raw eventId untouched if nothing matches (used internally).
  String eventTitle(String eventId) {
    if (_eventTitleCache.containsKey(eventId)) {
      return _eventTitleCache[eventId]!;
    }

    String result = eventId;

    for (final event in events) {
      final id = event['id'] as String? ?? '';
      if (id == eventId) {
        final title = event['title'] as String? ?? '';
        if (title.isNotEmpty) {
          _eventTitleCache[eventId] = title;
          return title;
        }
      }
    }

    for (final event in events) {
      final evEventId = event['eventId'] as String? ?? '';
      if (evEventId == eventId) {
        final title = event['title'] as String? ?? '';
        if (title.isNotEmpty) {
          _eventTitleCache[eventId] = title;
          return title;
        }
      }
    }

    for (final event in events) {
      final title = event['title'] as String? ?? '';
      if (title == eventId) {
        _eventTitleCache[eventId] = title;
        return title;
      }
    }

    for (final event in events) {
      final title = event['title'] as String? ?? '';
      if (title.isNotEmpty && eventId.isNotEmpty) {
        if (title.contains(eventId) || eventId.contains(title)) {
          _eventTitleCache[eventId] = title;
          return title;
        }
      }
    }

    _eventTitleCache[eventId] = result;
    return result;
  }

  /// Human-friendly title for display. Falls back to a clear label instead
  /// of a raw Firestore document id when no matching event can be found
  /// (e.g. the event was deleted, or belongs to another org).
  String eventDisplayTitle(String eventId) {
    if (eventId.isEmpty) return 'Unknown event';
    final title = eventTitle(eventId);
    if (title == eventId) return 'Deleted / unlinked event';
    return title;
  }

  String? eventIdByTitle(String title) {
    for (final event in events) {
      final t = event['title'] as String? ?? '';
      if (t == title) {
        return event['id'] as String?;
      }
    }
    return null;
  }

  List<String> get eventTitles {
    final titles = <String>{};
    for (final event in events) {
      final title = event['title'] as String? ?? '';
      if (title.isNotEmpty) titles.add(title);
    }
    return titles.toList()..sort();
  }
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

class _OrgEventAnalyticsScreenState extends State<OrgEventAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late Future<_AnalyticsData> _dataFuture;
  late TabController _tabCtrl;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedEvent = 'All Events';
  int? _selectedRating;

  StreamSubscription<QuerySnapshot>? _feedbackSubscription;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _dataFuture = _loadAll();
    _searchCtrl.addListener(
      () =>
          setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim()),
    );
    _listenForUpdates();
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
    _feedbackSubscription?.cancel();
    super.dispose();
  }

  Future<_AnalyticsData> _loadAll() async {
    final db = FirebaseFirestore.instance;

    try {
      final feedbackSnapshot = await db.collection('feedback').get();

      final eventsSnapshot = await db
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .get();

      final evalFormsSnapshot = await db
          .collection('eval_forms')
          .where('orgId', isEqualTo: widget.orgId)
          .get();

      final feedbacks = feedbackSnapshot.docs
          .map((d) => {
                ...d.data(),
                'id': d.id,
                'eventId': d.data()['eventId'] as String? ?? '',
              })
          .toList();

      final events = eventsSnapshot.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': data['title'] as String? ?? 'Untitled Event',
          'eventId': data['eventId'] as String? ?? d.id,
        };
      }).toList();

      final evalForms = evalFormsSnapshot.docs
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      return _AnalyticsData(
        feedbacks: feedbacks,
        events: events,
        evalForms: evalForms,
      );
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      rethrow;
    }
  }

  void _listenForUpdates() {
    _feedbackSubscription?.cancel();
    _feedbackSubscription = FirebaseFirestore.instance
        .collection('feedback')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _dataFuture = _loadAll();
        });
      }
    }, onError: (error) {
      debugPrint('Feedback listener error: $error');
    });
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadAll();
      _searchCtrl.clear();
      _selectedEvent = 'All Events';
      _selectedRating = null;
    });
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> feedbacks,
    _AnalyticsData data,
  ) {
    return feedbacks.where((f) {
      final eventId = f['eventId'] as String? ?? '';
      final eventTitle = data.eventDisplayTitle(eventId).toLowerCase();
      final comment = (f['comment'] as String? ?? '').toLowerCase();
      final rating = f['rating'] as int? ?? 0;

      final matchSearch = _searchQuery.isEmpty ||
          eventTitle.contains(_searchQuery) ||
          comment.contains(_searchQuery);
      final matchEvent = _selectedEvent == 'All Events' ||
          data.eventTitle(eventId) == _selectedEvent;
      final matchRating = _selectedRating == null || rating == _selectedRating;

      return matchSearch && matchEvent && matchRating;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedEvent != 'All Events' ||
      _selectedRating != null;

  Future<void> _exportAnalytics(String choice, _AnalyticsData data) async {
    final filtered = _applyFilters([...data.feedbacks], data)
      ..sort((a, b) {
        final ta = (a['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

    if (filtered.isEmpty) {
      _snack('No records to export', isError: true);
      return;
    }

    final rows = filtered.asMap().entries.map((e) {
      final f = e.value;
      final title = data.eventDisplayTitle(f['eventId'] as String? ?? '');
      final date = (f['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
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
        ].map((row) => row.map((c) => '"$c"').join(',')).join('\n');
        await OrgExportUtil.saveText(
          csv,
          'event_feedback_$stamp.csv',
          mimeType: 'text/csv',
        );
      } else if (choice == 'pdf') {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Event Feedback',
          headers: ['#', 'Event', 'Rating', 'Comment', 'Date'],
          rows: rows,
        );
        await OrgExportUtil.saveBytes(
          pdfBytes,
          'event_feedback_$stamp.pdf',
          mimeType: 'application/pdf',
        );
      }
      _snack('Exported ${filtered.length} records');
    } catch (e) {
      _snack('Export failed: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.beVietnamPro()),
        backgroundColor: isError ? _C.red : _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: UpriseColors.primaryDark),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _C.red, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load analytics', style: GoogleFonts.beVietnamPro()),
                const SizedBox(height: 8),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snap.data!;
        final filtered = _applyFilters([...data.feedbacks], data);
        final eventOptions = ['All Events', ...data.eventTitles];

        return Scaffold(
          backgroundColor: _C.surface,
          body: Builder(
            builder: (context) {
              final width = MediaQuery.of(context).size.width;
              final isMobile = width < 720;
              final isTablet = width >= 720 && width < 1200;
              final horizontalPadding =
                  isMobile ? 16.0 : (isTablet ? 22.0 : 28.0);

              return SingleChildScrollView(
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(data, isMobile),
                    SizedBox(height: isMobile ? 14 : 20),
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
                          _buildTabBar(data),
                          [
                            _buildAnalyticsTab(data),
                            _buildFeedbackTab(data, filtered, eventOptions, isMobile),
                          ][_tabCtrl.index],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(_AnalyticsData data, bool isMobile) {
    final published = data.evalForms.where((f) => f['status'] == 'published').length;
    final totalEvents = data.events.length;

    final cards = [
      _StatCardData('Total evaluations', data.totalFeedbacks.toString(),
          Icons.assignment_outlined, _C.blue),
      _StatCardData(
          'Average rating',
          data.totalFeedbacks > 0 ? data.avgRating.toStringAsFixed(1) : '—',
          Icons.star_outline,
          _C.amber),
      _StatCardData(
          'Active events', totalEvents.toString(), Icons.event_outlined, _C.green),
      _StatCardData('Published forms', published.toString(),
          Icons.assignment_outlined, UpriseColors.primaryDark),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StatCard(c),
                ))
            .toList(),
      );
    }

    return Row(
      children: cards.asMap().entries.map((e) {
        final c = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 14),
            child: _StatCard(c),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabBar(_AnalyticsData data) {
    final tabs = [
      ('Analytics', Icons.bar_chart_rounded, null),
      (
        'Feedback',
        Icons.forum_outlined,
        data.totalFeedbacks > 0 ? data.totalFeedbacks.toString() : null,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.border)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(_DS.radiusLg)),
      ),
      child: Row(
        children: [
          ...tabs.asMap().entries.map((e) {
            final idx = e.key;
            final label = e.value.$1;
            final icon = e.value.$2;
            final badge = e.value.$3;
            final active = _tabCtrl.index == idx;
            return GestureDetector(
              onTap: () => setState(() => _tabCtrl.animateTo(idx)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? UpriseColors.primaryDark : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 15, color: active ? UpriseColors.primaryDark : _C.muted),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? UpriseColors.primaryDark : _C.muted,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: _C.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live sync',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.green,
                  ),
                ),
                const SizedBox(width: 14),
                _RefreshButton(onTap: _refresh),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Analytics tab ──────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab(_AnalyticsData data) {
    final avgByEvent = data.avgByEvent;

    String highestEvent = '—';
    double highestScore = 0.0;
    String lowestEvent = '—';
    double lowestScore = 5.1;

    for (final entry in avgByEvent.entries) {
      final title = data.eventDisplayTitle(entry.key);
      final score = entry.value;
      if (score > highestScore) {
        highestScore = score;
        highestEvent = title;
      }
      if (score < lowestScore) {
        lowestScore = score;
        lowestEvent = title;
      }
    }
    if (avgByEvent.isEmpty) {
      highestScore = 0;
      lowestScore = 0;
      highestEvent = '—';
      lowestEvent = '—';
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            final kpis = [
              _KpiCard(
                icon: Icons.bar_chart_rounded,
                label: 'Total evaluations',
                value: data.totalFeedbacks.toString(),
                sub: data.totalFeedbacks > 0 ? 'All responses collected' : 'No data yet',
                color: _C.blue,
              ),
              _KpiCard(
                icon: Icons.star_outline,
                label: 'Average rating',
                value: data.totalFeedbacks > 0 ? data.avgRating.toStringAsFixed(1) : '—',
                sub: data.totalFeedbacks > 0
                    ? 'Based on ${data.totalFeedbacks} responses'
                    : 'No ratings yet',
                color: _C.amber,
              ),
              _KpiCard(
                icon: Icons.emoji_events_outlined,
                label: 'Highest rated',
                value: highestEvent,
                sub: avgByEvent.isNotEmpty
                    ? 'Score: ${highestScore.toStringAsFixed(1)} / 5.0'
                    : 'No data yet',
                color: _C.green,
              ),
              _KpiCard(
                icon: Icons.trending_down_rounded,
                label: 'Needs improvement',
                value: lowestEvent,
                sub: avgByEvent.isNotEmpty
                    ? 'Score: ${lowestScore.toStringAsFixed(1)} / 5.0'
                    : 'No data yet',
                color: _C.red,
              ),
            ];
            if (narrow) {
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: kpis.map((k) => SizedBox(width: (constraints.maxWidth - 14) / 2, child: k)).toList(),
              );
            }
            return Row(
              children: kpis.asMap().entries.map((e) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: e.key == 0 ? 0 : 14),
                    child: e.value,
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final stack = constraints.maxWidth < 900;
            final satisfaction = _SatisfactionCard(data: data);
            final distribution = _DistributionCard(data: data);
            if (stack) {
              return Column(children: [satisfaction, const SizedBox(height: 20), distribution]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: satisfaction),
                const SizedBox(width: 20),
                Expanded(child: distribution),
              ],
            );
          }),
          const SizedBox(height: 20),
          _CompletionCard(data: data),
        ],
      ),
    );
  }

  // ── Feedback tab ───────────────────────────────────────────────────────────
  Widget _buildFeedbackTab(
    _AnalyticsData data,
    List<Map<String, dynamic>> filtered,
    List<String> eventOptions,
    bool isMobile,
  ) {
    final sorted = [...filtered]
      ..sort((a, b) {
        final ta = (a['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['submittedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    final items = sorted.take(50).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Feedback responses',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _C.charcoal,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${data.totalFeedbacks} total',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFeedbackFilterBar(data, eventOptions),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            _ActiveFilterChips(
              searchQuery: _searchQuery,
              selectedEvent: _selectedEvent,
              selectedRating: _selectedRating,
              filteredCount: filtered.length,
              totalCount: data.totalFeedbacks,
              onRemoveSearch: () => _searchCtrl.clear(),
              onRemoveEvent: () => setState(() => _selectedEvent = 'All Events'),
              onRemoveRating: () => setState(() => _selectedRating = null),
              onClearAll: () => setState(() {
                _searchCtrl.clear();
                _selectedEvent = 'All Events';
                _selectedRating = null;
              }),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_DS.radiusMd),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: _C.surface,
                    border: Border(bottom: BorderSide(color: _C.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _hCell('EVENT')),
                      Expanded(flex: 2, child: _hCell('RATING')),
                      Expanded(flex: 5, child: _hCell('COMMENT')),
                      Expanded(flex: 2, child: _hCell('DATE')),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off, size: 42, color: Color(0xFFD1D5DB)),
                          const SizedBox(height: 10),
                          Text(
                            'No feedback matches your filters',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...items.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    final rating = f['rating'] as int? ?? 0;
                    final comment = f['comment'] as String? ?? '';
                    final eventId = f['eventId'] as String? ?? '';
                    final eventTitle = data.eventDisplayTitle(eventId);
                    final createdAt =
                        (f['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final isLast = i == items.length - 1;
                    final ratingColor = rating >= 4
                        ? _C.green
                        : rating == 3
                            ? _C.amber
                            : _C.red;
                    final ratingBg = rating >= 4
                        ? const Color(0xFFECFDF5)
                        : rating == 3
                            ? const Color(0xFFFFFBEB)
                            : const Color(0xFFFEF2F2);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: i.isOdd ? const Color(0xFFFBFCFE) : Colors.white,
                        border: isLast
                            ? null
                            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              eventTitle,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _C.charcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: ratingBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 14, color: ratingColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$rating.0',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: ratingColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                comment.isEmpty ? '—' : comment,
                                style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: _C.muted),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(createdAt),
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.muted),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    border: const Border(top: BorderSide(color: _C.border)),
                    color: _C.surface,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
                  ),
                  child: Text(
                    '${items.length} result${items.length == 1 ? '' : 's'}',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackFilterBar(_AnalyticsData data, List<String> eventOptions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth > 900;
        final fieldWidth = useRow ? 360.0 : double.infinity;

        final searchField = SizedBox(
          width: fieldWidth,
          height: 42,
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.charcoal),
            decoration: InputDecoration(
              hintText: 'Search event name or feedback comment…',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.muted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _C.muted),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 15, color: _C.muted),
                      onPressed: _searchCtrl.clear,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
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
                borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
              ),
            ),
          ),
        );

        final actionControls = [
          _FilterDropdown(
            value: _selectedEvent,
            items: eventOptions,
            onChanged: (v) => setState(() => _selectedEvent = v ?? 'All Events'),
          ),
          _FilterDropdown(
            value: _selectedRating == null ? 'All Ratings' : '$_selectedRating ★',
            items: ['All Ratings', ...List.generate(5, (i) => '${5 - i} ★')],
            onChanged: (v) => setState(
              () => _selectedRating =
                  v == 'All Ratings' ? null : int.tryParse(v?.split(' ').first ?? ''),
            ),
          ),
          AdminExportButton(
            label: 'Export',
            onSelected: (c) => _exportAnalytics(c, data),
          ),
        ];

        if (useRow) {
          return Row(
            children: [
              searchField,
              const SizedBox(width: 12),
              ...actionControls
                  .expand((w) => [w, const SizedBox(width: 10)])
                  .toList()
                ..removeLast(),
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [searchField, ...actionControls],
        );
      },
    );
  }

  Widget _hCell(String t) => Text(
        t.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _C.muted,
          letterSpacing: 0.8,
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Supporting widgets
// ════════════════════════════════════════════════════════════════════════════

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.refresh_rounded, size: 15, color: UpriseColors.primaryDark),
        label: Text(
          'Refresh',
          style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: UpriseColors.primaryDark),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _C.border.withOpacity(0.5)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.color.withOpacity(0.15), c.color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(_DS.radiusMd),
              ),
              child: Icon(c.icon, color: c.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _C.muted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.value,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _C.charcoal,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _C.border.withOpacity(0.5)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _C.muted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _C.charcoal,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.inter(fontSize: 10, color: _C.muted, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SatisfactionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _SatisfactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.avgByEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _C.border.withOpacity(0.5)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_events_outlined, size: 16, color: _C.blue),
                ),
                const SizedBox(width: 10),
                Text(
                  'Event satisfaction scores',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _C.charcoal),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 40, color: _C.border),
                    const SizedBox(height: 8),
                    Text('No feedback data yet', style: GoogleFonts.inter(fontSize: 13, color: _C.muted)),
                  ],
                ),
              ),
            )
          else
            ...sorted.asMap().entries.map((entry) {
              final eventKey = entry.value.key;
              final score = entry.value.value;
              final title = data.eventDisplayTitle(eventKey);
              final isLast = entry.key == sorted.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _C.charcoal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: score >= 4.0
                                    ? const Color(0xFFECFDF5)
                                    : score >= 3.0
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                score.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: score >= 4.0 ? _C.green : (score >= 3.0 ? _C.amber : _C.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: score / 5.0,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: score >= 4.0 ? _C.green : (score >= 3.0 ? _C.amber : _C.red),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, color: _C.border),
                ],
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _DistributionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts = data.starCounts;
    final total = data.totalFeedbacks;

    final segs = [
      _Seg(5, counts[5]!, const Color(0xFF10B981)),
      _Seg(4, counts[4]!, const Color(0xFF34D399)),
      _Seg(3, counts[3]!, const Color(0xFFFBBF24)),
      _Seg(2, counts[2]!, const Color(0xFFFB923C)),
      _Seg(1, counts[1]!, const Color(0xFFF87171)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _C.border.withOpacity(0.5)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_chart_outlined, size: 16, color: _C.amber),
              ),
              const SizedBox(width: 10),
              Text(
                'Rating distribution',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _C.charcoal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            Container(
              height: 140,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 40, color: _C.border),
                  const SizedBox(height: 8),
                  Text('No feedback yet', style: GoogleFonts.inter(fontSize: 13, color: _C.muted)),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CustomPaint(
                    painter: _DonutPainter(segs: segs, total: total, label: data.avgRating.toStringAsFixed(1)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: segs.map((s) {
                      final pct = total > 0 ? (s.count / total * 100).toStringAsFixed(0) : '0';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${s.stars} star${s.stars > 1 ? 's' : ''}',
                              style: GoogleFonts.inter(fontSize: 12, color: _C.muted),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: s.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$pct%',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: s.color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
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
  const _DonutPainter({required this.segs, required this.total, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 14;
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
        final actual = nonZero > 1 ? math.max(0.0, sweep - gap) : sweep;
        paint.color = s.color;
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start, actual, false, paint);
        start += sweep;
      }
    }

    final bigStyle = GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: _C.charcoal);
    final smStyle = GoogleFonts.inter(fontSize: 11, color: _C.muted, fontWeight: FontWeight.w500);

    final tp1 = TextPainter(text: TextSpan(text: label, style: bigStyle), textDirection: ui.TextDirection.ltr)
      ..layout();
    final tp2 = TextPainter(text: TextSpan(text: 'average', style: smStyle), textDirection: ui.TextDirection.ltr)
      ..layout();

    tp1.paint(canvas, ui.Offset(cx - tp1.width / 2, cy - tp1.height / 2 - 7));
    tp2.paint(canvas, ui.Offset(cx - tp2.width / 2, cy + tp1.height / 2 - 3));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.total != total || old.label != label;
}

/// Redesigned "Evaluation completion by event" widget.
/// Replaces the old messy wrap-of-chips grid with a clean, scrollable,
/// sorted list — events with feedback first, clearer typography and
/// consistent row heights so it stays readable even with many events.
class _CompletionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _CompletionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final countByEvent = data.feedbackCountByEvent;

    final rows = [...data.events];
    rows.sort((a, b) {
      final ra = countByEvent[a['id']] ?? 0;
      final rb = countByEvent[b['id']] ?? 0;
      if (ra != rb) return rb.compareTo(ra);
      return (a['title'] as String).toLowerCase().compareTo((b['title'] as String).toLowerCase());
    });

    final withFeedback = rows.where((e) => (countByEvent[e['id']] ?? 0) > 0).length;

    return Container(
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _C.border.withOpacity(0.5)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.checklist_outlined, size: 16, color: _C.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Evaluation completion by event',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _C.charcoal),
                      ),
                      if (rows.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$withFeedback of ${rows.length} events have received feedback',
                          style: GoogleFonts.inter(fontSize: 11.5, color: _C.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No events found')),
            )
          else
            SizedBox(
              height: math.min(rows.length * 52.0, 360.0),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, i) {
                  final event = rows[i];
                  final title = event['title'] as String;
                  final received = countByEvent[event['id']] ?? 0;
                  final hasFeedback = received > 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: hasFeedback ? _C.green : const Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _C.charcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasFeedback ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasFeedback ? '$received response${received == 1 ? '' : 's'}' : 'No responses yet',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: hasFeedback ? const Color(0xFF166534) : _C.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  final String searchQuery, selectedEvent;
  final int? selectedRating;
  final int filteredCount, totalCount;
  final VoidCallback onRemoveSearch, onRemoveEvent, onRemoveRating, onClearAll;

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
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          'Showing $filteredCount of $totalCount',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.muted),
        ),
        if (searchQuery.isNotEmpty) _Chip(label: '"$searchQuery"', onRemove: onRemoveSearch),
        if (selectedEvent != 'All Events') _Chip(label: selectedEvent, onRemove: onRemoveEvent),
        if (selectedRating != null) _Chip(label: '$selectedRating★ only', onRemove: onRemoveRating),
        TextButton(
          onPressed: onClearAll,
          child: Text('Clear all', style: GoogleFonts.beVietnamPro(fontSize: 12, color: _C.red)),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: UpriseColors.primaryDark.withOpacity(0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: UpriseColors.primaryDark.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.primaryDark, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close, size: 11, color: UpriseColors.primaryDark),
            ),
          ],
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: _C.muted),
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: _C.charcoal),
            items: items
                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}