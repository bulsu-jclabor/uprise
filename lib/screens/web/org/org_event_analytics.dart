// lib/screens/web/org/org_event_analytics.dart

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

// ── Colors ─────────────────────────────────────────────────────
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
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ── Data Model ─────────────────────────────────────────────────
class _AnalyticsData {
  final List<Map<String, dynamic>> feedbacks;
  final List<Map<String, dynamic>> events;
  const _AnalyticsData({required this.feedbacks, required this.events});

  int get totalFeedbacks => feedbacks.length;

  double get avgRating {
    if (feedbacks.isEmpty) return 0;
    final sum = feedbacks.fold<int>(0, (s, f) => s + (f['rating'] as int? ?? 0));
    return sum / feedbacks.length;
  }

  Map<String, double> get avgByEvent {
    final Map<String, List<int>> byEvent = {};
    for (final f in feedbacks) {
      final id = f['eventId'] as String? ?? '';
      byEvent.putIfAbsent(id, () => []).add(f['rating'] as int? ?? 0);
    }
    return byEvent.map((k, v) => MapEntry(k, v.reduce((a, b) => a + b) / v.length));
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

  String eventTitle(String id) =>
      events.firstWhere((e) => e['id'] == id,
          orElse: () => {'title': id})['title'] as String;
}

// ── Screen ─────────────────────────────────────────────────────
class OrgEventAnalyticsScreen extends StatefulWidget {
  final String orgId;
  const OrgEventAnalyticsScreen({super.key, required this.orgId});

  @override
  State<OrgEventAnalyticsScreen> createState() => _OrgEventAnalyticsScreenState();
}

class _OrgEventAnalyticsScreenState extends State<OrgEventAnalyticsScreen> {
  late Future<_AnalyticsData> _dataFuture;

  // ── Filter / Search state ──
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery    = '';
  String _selectedEvent  = 'All Events';
  int?   _selectedRating; // null = all
  bool   _filterOpen     = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    activity_log.ActivityLogger.log(
      action: 'view_analytics',
      module: 'event_analytics',
      details: {'orgId': widget.orgId},
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_AnalyticsData> _loadAll() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('event_feedbacks').where('orgId', isEqualTo: widget.orgId).get(),
      db.collection('events').where('orgId', isEqualTo: widget.orgId).get(),
    ]);

    final feedbacks = results[0].docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList();

    final events = results[1].docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'id'      : d.id,
        'title'   : data['title'] as String? ?? 'Untitled',
        'capacity': (data['capacity'] ?? data['expectedAttendees'] ?? 1) as int,
      };
    }).toList();

    return _AnalyticsData(feedbacks: feedbacks, events: events);
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadAll();
      _searchCtrl.clear();
      _selectedEvent  = 'All Events';
      _selectedRating = null;
      _filterOpen     = false;
    });
  }

  // ── Apply search + filter to feedback list ──
  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> feedbacks, _AnalyticsData data) {
    return feedbacks.where((f) {
      final eventId    = f['eventId'] as String? ?? '';
      final eventTitle = data.eventTitle(eventId).toLowerCase();
      final comment    = (f['comment'] as String? ?? '').toLowerCase();
      final rating     = f['rating']  as int? ?? 0;

      final matchesSearch = _searchQuery.isEmpty ||
          eventTitle.contains(_searchQuery) ||
          comment.contains(_searchQuery);

      final matchesEvent = _selectedEvent == 'All Events' ||
          data.eventTitle(eventId) == _selectedEvent;

      final matchesRating =
          _selectedRating == null || rating == _selectedRating;

      return matchesSearch && matchesEvent && matchesRating;
    }).toList();
  }

  Future<void> _exportAnalytics(String choice, _AnalyticsData data) async {
    final filtered = _applyFilters([...data.feedbacks], data)
      ..sort((a, b) {
        final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No records to export', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final rows = filtered.asMap().entries.map((e) {
      final f = e.value;
      final title = data.eventTitle(f['eventId'] as String? ?? '');
      final date = (f['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      return [
        '${e.key + 1}',
        title,
        '${f['rating'] ?? ''}',
        (f['comment'] as String? ?? '').replaceAll('"', '""'),
        DateFormat('MMM dd, yyyy').format(date),
      ];
    }).toList();

    try {
      if (choice == 'csv') {
        final csv = [
          ['#', 'Event', 'Rating', 'Comment', 'Date'],
          ...rows,
        ].map((row) => row.map((cell) => '"$cell"').join(',')).join('\n');
        await OrgExportUtil.saveText(csv, 'event_feedback_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv', mimeType: 'text/csv');
      } else if (choice == 'pdf') {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Event Feedback',
          headers: ['#', 'Event', 'Rating', 'Comment', 'Date'],
          rows: rows,
        );
        await OrgExportUtil.saveBytes(pdfBytes, 'event_feedback_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', mimeType: 'application/pdf');
      }

      activity_log.ActivityLogger.log(
        action: choice == 'csv' ? 'export_csv' : 'export_pdf',
        module: 'event_analytics',
        details: {'orgId': widget.orgId, 'rows': filtered.length},
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${filtered.length} records', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e', style: GoogleFonts.beVietnamPro()),
          backgroundColor: OrgColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedEvent != 'All Events' ||
      _selectedRating != null;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AnalyticsData>(
      future: _dataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: OrgColors.primaryDark));
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: OrgColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Failed to load analytics',
                    style: GoogleFonts.beVietnamPro(color: OrgColors.charcoal)),
                const SizedBox(height: 8),
                TextButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data     = snap.data!;
        final filtered = _applyFilters([...data.feedbacks], data);

        // Event dropdown options
        final eventOptions = [
          'All Events',
          ...data.events.map((e) => e['title'] as String),
        ];

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          color: OrgColors.primaryDark,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Event Analytics & Evaluation',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 24, fontWeight: FontWeight.bold,
                                  color: OrgColors.charcoal)),
                          const SizedBox(height: 4),
                          Text(
                            'Track event performance and participant feedback across all active campaigns',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13, color: OrgColors.darkGray),
                          ),
                        ],
                      ),
                    ),
                    // Export button
                    AdminExportButton(
                      label: 'Export',
                      onSelected: (choice) => _exportAnalytics(choice, data),
                    ),
                    const SizedBox(width: 8),
                    _HeaderButton(
                      icon: Icons.refresh,
                      label: 'Refresh',
                      color: OrgColors.primaryDark,
                      onTap: _refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Search + Filter bar ──
                _SearchFilterBar(
                  controller: _searchCtrl,
                  filterOpen: _filterOpen,
                  hasActiveFilters: _hasActiveFilters,
                  onToggleFilter: () =>
                      setState(() => _filterOpen = !_filterOpen),
                  onClearAll: () => setState(() {
                    _searchCtrl.clear();
                    _selectedEvent  = 'All Events';
                    _selectedRating = null;
                  }),
                ),

                // ── Filter Panel (collapsible) ──
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState: _filterOpen
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _FilterPanel(
                    eventOptions: eventOptions,
                    selectedEvent: _selectedEvent,
                    selectedRating: _selectedRating,
                    onEventChanged: (v) =>
                        setState(() => _selectedEvent = v ?? 'All Events'),
                    onRatingChanged: (v) =>
                        setState(() => _selectedRating = v),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // ── Active filter chips ──
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  _ActiveFilterChips(
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
                  ),
                ],
                const SizedBox(height: 24),

                // ── KPI Row (always shows full dataset) ──
                _KpiRow(data: data),
                const SizedBox(height: 24),

                // ── Satisfaction + Distribution (full dataset) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SatisfactionCard(data: data)),
                    const SizedBox(width: 20),
                    Expanded(child: _DistributionCard(data: data)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Completion (full dataset) ──
                _CompletionCard(data: data),
                const SizedBox(height: 24),

                // ── Feedback (filtered) ──
                _FeedbackCard(
                  data: data,
                  filtered: filtered,
                  isFiltered: _hasActiveFilters,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Header Button ──────────────────────────────────────────────
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _HeaderButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label,
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Search + Filter Bar ────────────────────────────────────────
class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final bool filterOpen;
  final bool hasActiveFilters;
  final VoidCallback onToggleFilter;
  final VoidCallback onClearAll;
  const _SearchFilterBar({
    required this.controller, required this.filterOpen,
    required this.hasActiveFilters, required this.onToggleFilter,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search field
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: OrgColors.white,
              border: Border.all(color: OrgColors.primaryLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
              decoration: InputDecoration(
                hintText: 'Search by event name or feedback comment…',
                hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: OrgColors.darkGray),
                prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16, color: OrgColors.darkGray),
                        onPressed: controller.clear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Filter toggle button
        GestureDetector(
          onTap: onToggleFilter,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: filterOpen ? OrgColors.primaryDark : OrgColors.white,
              border: Border.all(
                color: filterOpen ? OrgColors.primaryDark : OrgColors.mediumGray,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.tune,
                    size: 16,
                    color: filterOpen ? OrgColors.white : OrgColors.charcoal),
                const SizedBox(width: 6),
                Text('Filter',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: filterOpen ? OrgColors.white : OrgColors.charcoal)),
                if (hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: OrgColors.error, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Clear all (if filters active)
        if (hasActiveFilters) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onClearAll,
            child: Text('Clear all',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: OrgColors.error)),
          ),
        ],
      ],
    );
  }
}

// ── Filter Panel ───────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final List<String> eventOptions;
  final String selectedEvent;
  final int? selectedRating;
  final ValueChanged<String?> onEventChanged;
  final ValueChanged<int?> onRatingChanged;
  const _FilterPanel({
    required this.eventOptions, required this.selectedEvent,
    required this.selectedRating, required this.onEventChanged,
    required this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        border: Border.all(color: OrgColors.primaryLight),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event filter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Event',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: OrgColors.darkGray)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: OrgColors.primaryLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedEvent,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 13, color: OrgColors.charcoal),
                      items: eventOptions
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: onEventChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Star rating filter
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: OrgColors.darkGray)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // "All" chip
                    _RatingChip(
                      label: 'All',
                      selected: selectedRating == null,
                      onTap: () => onRatingChanged(null),
                    ),
                    const SizedBox(width: 6),
                    ...List.generate(5, (i) {
                      final star = 5 - i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _RatingChip(
                          label: '$star★',
                          selected: selectedRating == star,
                          onTap: () => onRatingChanged(
                              selectedRating == star ? null : star),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RatingChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? OrgColors.primaryDark : OrgColors.lightGray,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? OrgColors.primaryDark : OrgColors.mediumGray,
          ),
        ),
        child: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: selected ? OrgColors.white : OrgColors.charcoal,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── Active Filter Chips ────────────────────────────────────────
class _ActiveFilterChips extends StatelessWidget {
  final String searchQuery, selectedEvent;
  final int? selectedRating;
  final int filteredCount, totalCount;
  final VoidCallback onRemoveSearch, onRemoveEvent, onRemoveRating;
  const _ActiveFilterChips({
    required this.searchQuery, required this.selectedEvent,
    required this.selectedRating, required this.filteredCount,
    required this.totalCount, required this.onRemoveSearch,
    required this.onRemoveEvent, required this.onRemoveRating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Showing $filteredCount of $totalCount',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: OrgColors.darkGray)),
        const SizedBox(width: 10),
        if (searchQuery.isNotEmpty)
          _Chip(label: '"$searchQuery"', onRemove: onRemoveSearch),
        if (selectedEvent != 'All Events')
          _Chip(label: selectedEvent, onRemove: onRemoveEvent),
        if (selectedRating != null)
          _Chip(label: '$selectedRating★ only', onRemove: onRemoveRating),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OrgColors.primaryDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: OrgColors.primaryDark.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11, color: OrgColors.primaryDark,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 12, color: OrgColors.primaryDark),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// KPI ROW
// ══════════════════════════════════════════════════════════════
class _KpiRow extends StatelessWidget {
  final _AnalyticsData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final avgByEvent = data.avgByEvent;
    String highestEvent = '—'; double highestScore = 0.0;
    String lowestEvent  = '—'; double lowestScore  = 5.1;

    for (final e in avgByEvent.entries) {
      final title = data.eventTitle(e.key);
      if (e.value > highestScore) { highestScore = e.value; highestEvent = title; }
      if (e.value < lowestScore)  { lowestScore  = e.value; lowestEvent  = title; }
    }
    if (avgByEvent.isEmpty) { highestScore = 0; lowestScore = 0; }

    return Row(children: [
      Expanded(child: _KpiCard(
        icon: Icons.assessment_outlined,
        label: 'Total Evaluations',
        value: data.totalFeedbacks.toString(),
        sub: data.totalFeedbacks > 0
            ? '+${(data.totalFeedbacks * 0.12).toInt()} from last month'
            : 'No data yet',
        subColor: OrgColors.success,
        color: OrgColors.info,
      )),
      const SizedBox(width: 14),
      Expanded(child: _KpiCard(
        icon: Icons.star_outline,
        label: 'Average Rating',
        value: data.avgRating.toStringAsFixed(1),
        sub: 'Based on ${data.totalFeedbacks} responses',
        color: OrgColors.warning,
      )),
      const SizedBox(width: 14),
      Expanded(child: _KpiCard(
        icon: Icons.emoji_events_outlined,
        label: 'Highest Rated',
        value: highestEvent,
        sub: 'Score: ${highestScore.toStringAsFixed(1)} / 5.0',
        color: OrgColors.success,
      )),
      const SizedBox(width: 14),
      Expanded(child: _KpiCard(
        icon: Icons.trending_down,
        label: 'Needs Improvement',
        value: lowestEvent,
        sub: 'Score: ${lowestScore.toStringAsFixed(1)} / 5.0',
        color: OrgColors.error,
      )),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final Color? subColor;
  const _KpiCard({
    required this.icon, required this.label,
    required this.value, required this.sub,
    required this.color, this.subColor,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: OrgColors.darkGray)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: OrgColors.charcoal)),
                Text(sub,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 10, color: subColor ?? OrgColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SATISFACTION SCORES
// ══════════════════════════════════════════════════════════════
class _SatisfactionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _SatisfactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.avgByEvent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Event Satisfaction Scores',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal)),
          ),
          const Divider(height: 1),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: Text('No feedback data yet',
                      style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray))),
            )
          else
            ...List.generate(sorted.length, (i) {
              final score  = sorted[i].value;
              final title  = data.eventTitle(sorted[i].key);
              final isLast = i == sorted.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(title,
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: OrgColors.charcoal)),
                          ),
                          Text(score.toStringAsFixed(1),
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13, fontWeight: FontWeight.bold,
                                  color: OrgColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: score / 5.0,
                          backgroundColor: OrgColors.lightGray,
                          color: OrgColors.primaryDark,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1),
              ]);
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RATING DISTRIBUTION
// ══════════════════════════════════════════════════════════════
class _DonutSegment {
  final int stars, count;
  final Color color;
  const _DonutSegment({required this.stars, required this.count, required this.color});
}

class _DistributionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _DistributionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts   = data.starCounts;
    final total    = data.totalFeedbacks;
    final segments = [
      _DonutSegment(stars: 5, count: counts[5]!, color: const Color(0xFFB45309)),
      _DonutSegment(stars: 4, count: counts[4]!, color: const Color(0xFFD97706)),
      _DonutSegment(stars: 3, count: counts[3]!, color: const Color(0xFFF59E0B)),
      _DonutSegment(stars: 2, count: counts[2]!, color: const Color(0xFFFCD34D)),
      _DonutSegment(stars: 1, count: counts[1]!, color: const Color(0xFFE5E7EB)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rating Distribution',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: OrgColors.charcoal)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 160, height: 160,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: segments, total: total,
                    label: data.avgRating.toStringAsFixed(1),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((s) {
                    final pct = total > 0 ? s.count / total * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Container(
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text('${s.stars} Star${s.stars > 1 ? "s" : ""}',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12, color: OrgColors.darkGray)),
                        const Spacer(),
                        Text('${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: OrgColors.charcoal)),
                      ]),
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

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final int total;
  final String label;
  const _DonutPainter({required this.segments, required this.total, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 16;
    const sw  = 26.0;
    const gap = 0.04;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      paint.color = const Color(0xFFE5E7EB);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    } else {
      double start  = -math.pi / 2;
      final nonZero = segments.where((s) => s.count > 0).length;
      for (final seg in segments) {
        if (seg.count == 0) continue;
        final sweep  = seg.count / total * 2 * math.pi;
        final actual = nonZero > 1 ? math.max(0.0, sweep - gap) : sweep;
        paint.color  = seg.color;
        canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r),
            start, actual, false, paint);
        start += sweep;
      }
    }

    final big   = GoogleFonts.beVietnamPro(
        fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF111827));
    final small = GoogleFonts.beVietnamPro(
        fontSize: 11, color: const Color(0xFF6B7280));

    final tp1 = TextPainter(
        text: TextSpan(text: label, style: big),
        textDirection: ui.TextDirection.ltr)..layout();
    final tp2 = TextPainter(
        text: TextSpan(text: 'average', style: small),
        textDirection: ui.TextDirection.ltr)..layout();

    tp1.paint(canvas, ui.Offset(cx - tp1.width / 2, cy - tp1.height / 2 - 8));
    tp2.paint(canvas, ui.Offset(cx - tp2.width / 2, cy + tp1.height / 2 - 4));
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total || old.label != label;
}

// ══════════════════════════════════════════════════════════════
// COMPLETION CARD
// ══════════════════════════════════════════════════════════════
class _CompletionCard extends StatelessWidget {
  final _AnalyticsData data;
  const _CompletionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final countByEvent = data.feedbackCountByEvent;
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Evaluation Completion by Event',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal)),
          ),
          const Divider(height: 1),
          if (data.events.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No events found')))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: data.events.map((event) {
                  final id       = event['id']       as String;
                  final title    = event['title']    as String;
                  final capacity = event['capacity'] as int;
                  final received = countByEvent[id] ?? 0;
                  final pct      = capacity > 0
                      ? (received / capacity).clamp(0.0, 1.0)
                      : 0.0;
                  return SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 13, fontWeight: FontWeight.w500,
                                      color: OrgColors.charcoal)),
                            ),
                            const SizedBox(width: 8),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13, fontWeight: FontWeight.bold,
                                    color: OrgColors.primaryDark)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: OrgColors.lightGray,
                            color: OrgColors.primaryDark,
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FEEDBACK CARD  (respects filters)
// ══════════════════════════════════════════════════════════════
class _FeedbackCard extends StatelessWidget {
  final _AnalyticsData data;
  final List<Map<String, dynamic>> filtered;
  final bool isFiltered;
  const _FeedbackCard({
    required this.data, required this.filtered, required this.isFiltered,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...filtered]
      ..sort((a, b) {
        final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    final items = sorted.take(50).toList(); // show more when filtered

    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Participant Feedback',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: OrgColors.charcoal)),
                const Spacer(),
                if (isFiltered)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: OrgColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('${items.length} result${items.length != 1 ? "s" : ""}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, color: OrgColors.info,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off, color: OrgColors.mediumGray, size: 40),
                    const SizedBox(height: 10),
                    Text('No feedback matches your filters',
                        style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                  ],
                ),
              ),
            )
          else
            ...List.generate(items.length, (i) {
              final f          = items[i];
              final rating     = f['rating']  as int?    ?? 0;
              final comment    = f['comment'] as String? ?? '';
              final eventId    = f['eventId'] as String? ?? '';
              final eventTitle = data.eventTitle(eventId);
              final createdAt  =
                  (f['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
              final isLast = i == items.length - 1;

              return Column(children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: OrgColors.primaryDark.withOpacity(0.1),
                    child: Text('${i + 1}',
                        style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w600,
                            color: OrgColors.primaryDark)),
                  ),
                  title: Row(children: [
                    Expanded(
                      child: Text(eventTitle,
                          style: GoogleFonts.beVietnamPro(
                              fontWeight: FontWeight.w600, fontSize: 13,
                              color: OrgColors.charcoal)),
                    ),
                    _StarRow(rating: rating),
                  ]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(comment,
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13, color: OrgColors.darkGray)),
                      ],
                      const SizedBox(height: 4),
                      Text(DateFormat('MMM dd, yyyy').format(createdAt),
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10, color: OrgColors.darkGray)),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 1),
              ]);
            }),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < rating ? Icons.star : Icons.star_border,
        size: 16, color: OrgColors.warning,
      )),
    );
  }
}

