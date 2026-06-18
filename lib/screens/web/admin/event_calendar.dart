import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:intl/intl.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category Colors - matching the submission form categories
// ─────────────────────────────────────────────────────────────────────────────
Map<String, Color> _categoryColors = {
  'Workshop':         const Color(0xFF8B5CF6),
  'Seminar':          const Color(0xFF3B82F6),
  'Competition':      const Color(0xFFEF4444),
  'General Assembly': const Color(0xFFF97316),
  'Social':           const Color(0xFFEC4899),
  'Outreach':         const Color(0xFF10B981),
  'Sports':           const Color(0xFF14B8A6),
  'Academic':         const Color(0xFF6366F1),
  'Technical':        const Color(0xFF06B6D4),
  'Cultural':         const Color(0xFFD946EF),
  'Other':            const Color(0xFF6B7280),
};

Color _getCategoryColor(String category) {
  return _categoryColors[category] ?? const Color(0xFF6B7280);
}
// ─── Category chip colors (matching org version) ────────────────
class CategoryColors {
  static const Map<String, Color> bg = {
    'Academic': Color(0xFFDCFCE7),
    'Technical': Color(0xFFDBEAFE),
    'Cultural': Color(0xFFFCE7F3),
    'Sports': Color(0xFFFFEDD5),
    'Workshop': Color(0xFFFEF3C7),
    'Other': Color(0xFFF3F4F6),
  };
  static const Map<String, Color> fg = {
    'Academic': Color(0xFF15803D),
    'Technical': Color(0xFF1D4ED8),
    'Cultural': Color(0xFFBE185D),
    'Sports': Color(0xFFEA580C),
    'Workshop': Color(0xFFEA580C),
    'Other': Color(0xFF374151),
  };
  static Color getBg(String cat) => bg[cat] ?? bg['Other']!;
  static Color getFg(String cat) => fg[cat] ?? fg['Other']!;
}

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusLg = 16;
  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: UpriseColors.primaryDark),
        const SizedBox(width: 8),
      ],
      Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: UpriseColors.primaryDark,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event model
// ─────────────────────────────────────────────────────────────────────────────
class _Event {
  final String id, title, time, category, organization, orgId, createdFromProposalId;
  final String location, description, guestSpeaker;
  final int capacity;
  final List<String> tags;
  final DateTime date;

  _Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.category,
    required this.organization,
    this.orgId = '',
    this.createdFromProposalId = '',
    this.location = '',
    this.description = '',
    this.guestSpeaker = '',
    this.capacity = 0,
    this.tags = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class EventCalendar extends StatefulWidget {
  const EventCalendar({super.key});

  @override
  _EventCalendarState createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(isMobile, isTablet),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendarStream(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar (no status filter) ───────────────────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final navAndToday = Row(children: [
      InkWell(
        onTap: () => setState(() => _currentMonth = DateTime.now()),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: UpriseColors.primaryDark.withAlpha(70), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.today_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 7),
              Text('Today', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        height: 40,
        constraints: const BoxConstraints(minWidth: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E6EA)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              }),
            ),
          ],
        ),
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                navAndToday,
                const SizedBox(height: 10),
                _ExportEventsButton(),
              ],
            )
          : Row(children: [
              navAndToday,
              const Spacer(),
              _ExportEventsButton(),
            ]),
    );
  }

  // ── Calendar stream (only approved events) ───────────────────────
  Widget _buildCalendarStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final events = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _Event(
            id:           doc.id,
            title:        d['title']    ?? 'Untitled',
            date:         (d['date']    as Timestamp).toDate(),
            time:         d['startTime'] ?? d['time'] ?? 'TBD',
            category:     d['category'] ?? 'Other',
            organization: d['orgName']  ?? 'Unknown',
            orgId:        (d['orgId'] ?? '').toString(),
            createdFromProposalId: (d['createdFromProposalId'] ?? '').toString(),
            location:     d['location']    ?? '',
            description:  d['description'] ?? '',
            guestSpeaker: d['guestSpeaker'] ?? '',
            capacity:     (d['capacity'] as num?)?.toInt() ?? 0,
            tags:         List<String>.from(d['tags'] ?? []),
          );
        }).toList();

        return _buildCalendarGrid(events);
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: UpriseColors.primaryDark),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1A202C),
          ),
        ),
      ],
    ),
  );
}

  // ── Calendar grid ─────────────────────────────────────────────────
  int get _totalRows {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    return ((startWeekday + daysInMonth) / 7).ceil();
  }

  Widget _buildCalendarGrid(List<_Event> events) {
    final firstDay       = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday   = firstDay.weekday % 7;
    final daysInMonth    = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final totalRows      = _totalRows;

    final Map<int, List<_Event>> byDay = {};
    for (final e in events) {
      if (e.date.year == _currentMonth.year && e.date.month == _currentMonth.month) {
        byDay.putIfAbsent(e.date.day, () => []).add(e);
      }
    }

    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7ED),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: UpriseColors.primaryLight)),
          ),
          child: Row(
            children: weekdays.map((d) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 120,
          ),
          itemCount: totalRows * 7,
          itemBuilder: (_, index) {
            final dayNum = index - startWeekday + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return _buildEmptyCell(
                isLastRow: index >= (totalRows - 1) * 7,
                colIndex: index % 7,
                isBottomRight: index == totalRows * 7 - 1,
                isBottomLeft: index == (totalRows - 1) * 7,
              );
            }
            return _buildDayCell(dayNum, byDay[dayNum] ?? [], totalRows);
          },
        ),
      ]),
    );
  }

  Widget _buildEmptyCell({
    bool isLastRow = false,
    int colIndex = 0,
    bool isBottomRight = false,
    bool isBottomLeft = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        border: Border(
          right: colIndex < 6
              ? const BorderSide(color: Color(0xFFF1F5F9))
              : BorderSide.none,
          bottom: !isLastRow
              ? const BorderSide(color: Color(0xFFF1F5F9))
              : BorderSide.none,
        ),
        borderRadius: isBottomLeft
            ? const BorderRadius.only(bottomLeft: Radius.circular(14))
            : isBottomRight
                ? const BorderRadius.only(bottomRight: Radius.circular(14))
                : null,
      ),
    );
  }

  Widget _buildDayCell(int day, List<_Event> events, int totalRows) {
  final isToday = day == DateTime.now().day &&
      _currentMonth.year == DateTime.now().year &&
      _currentMonth.month == DateTime.now().month;

  final sorted = List<_Event>.from(events)..sort((a, b) => a.time.compareTo(b.time));
  final display = sorted.take(3).toList();
  final extra = sorted.length - display.length;

  final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
  final startWeekday = firstDay.weekday % 7;
  final cellIndex = startWeekday + day - 1;
  final colIndex = cellIndex % 7;
  final isLastRow = cellIndex >= (totalRows - 1) * 7;
  final isBottomLeft = isLastRow && colIndex == 0;
  final isBottomRight = cellIndex == totalRows * 7 - 1 ||
      (isLastRow && day == DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day);

  return InkWell(
    onTap: events.isEmpty ? null : () => _showDayEventsSheet(day, sorted),
    hoverColor: UpriseColors.primaryDark.withAlpha(8),
    child: Container(
      decoration: BoxDecoration(
        color: isToday ? UpriseColors.primaryDark.withAlpha(10) : null,
        border: Border(
          right: colIndex < 6 ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
          bottom: !isLastRow ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
        ),
        borderRadius: isBottomLeft
            ? const BorderRadius.only(bottomLeft: Radius.circular(14))
            : isBottomRight ? const BorderRadius.only(bottomRight: Radius.circular(14)) : null,
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 4), // reduced vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 20, height: 20,
                decoration: isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: UpriseColors.primaryDark,
                        boxShadow: [BoxShadow(color: UpriseColors.primaryDark.withAlpha(70), blurRadius: 6, offset: const Offset(0, 2))],
                      )
                    : null,
                alignment: Alignment.center,
                child: Text('$day',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday ? Colors.white : const Color(0xFF1A202C),
                    )),
              ),
              if (events.length > 1)
                Text('${events.length}',
                    style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF9AA5B4))),
            ],
          ),
          const SizedBox(height: 2),
          ...display.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _getCategoryColor(e.category).withAlpha(26),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 5, height: 5,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(color: _getCategoryColor(e.category), shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Text(
                      e.title,
                      style: GoogleFonts.beVietnamPro(fontSize: 10.5, fontWeight: FontWeight.w600, color: _getCategoryColor(e.category)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('+$extra more', style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF9AA5B4), fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    ),
  );
}

  // ── Day events dialog (web-appropriate, replaces mobile bottom sheet) ──
  Future<void> _showDayEventsSheet(int day, List<_Event> events) async {
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime(_currentMonth.year, _currentMonth.month, day));

    // Resolve the real submitted start time from each linked proposal,
    // instead of trusting the (possibly stale) cached field on the event doc.
    final resolvedTimes = <String, String>{};
    await Future.wait(events.map((e) async {
      if (e.createdFromProposalId.isEmpty) {
        resolvedTimes[e.id] = e.time;
        return;
      }
      try {
        final propDoc = await FirebaseFirestore.instance
            .collection('event_proposals')
            .doc(e.createdFromProposalId)
            .get();
        final pd = propDoc.data();
        resolvedTimes[e.id] = pd != null ? (pd['startTime'] ?? '').toString() : e.time;
      } catch (_) {
        resolvedTimes[e.id] = e.time;
      }
    }));

    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 460,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
                  decoration: const BoxDecoration(color: UpriseColors.primaryDark),
                  child: Stack(children: [
                    Positioned(
                      right: -20, top: -20,
                      child: Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(20)),
                      ),
                    ),
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.event_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(dateLabel,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('${events.length} event${events.length == 1 ? '' : 's'}',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 12, color: Colors.white.withAlpha(204))),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ]),
                  ]),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _EventListTile(
                    event: events[i],
                    displayTime: resolvedTimes[events[i].id],
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEventDetailDialog(events[i]);
                    },
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: Text('Close', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

 Future<void> _showEventDetailDialog(_Event event) async {
  // Fetch latest data from proposal (if available)
  var time = event.time;
  var capacity = event.capacity;
  var guestSpeaker = event.guestSpeaker;

  if (event.createdFromProposalId.isNotEmpty) {
    try {
      final propDoc = await FirebaseFirestore.instance
          .collection('event_proposals')
          .doc(event.createdFromProposalId)
          .get();
      if (propDoc.exists) {
        final pd = propDoc.data()!;
        final start = (pd['startTime'] ?? '').toString();
        final end = (pd['endTime'] ?? '').toString();
        time = start.isNotEmpty ? (end.isNotEmpty ? '$start - $end' : start) : '';
        capacity = (pd['capacity'] is num) ? (pd['capacity'] as num).toInt() : 0;
        guestSpeaker = (pd['guestSpeaker'] ?? '').toString();
      }
    } catch (_) {}
  }

  if (!mounted) return;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_DS.radiusLg),
      ),
      child: Container(
        width: 560,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Slim Header ──────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_DS.radiusLg),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
                decoration: const BoxDecoration(
                  color: UpriseColors.primaryDark, // consistent with org version
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              // Category chip (reuse existing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CategoryColors.getBg(event.category),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  event.category.toUpperCase(),
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: CategoryColors.getFg(event.category),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              // We don't have status in admin calendar, but we can skip
                              // Or if status exists, add it similarly.
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick Info Chips ──────────────────────────────
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(
                          Icons.calendar_today_rounded,
                          DateFormat('MMM d, yyyy').format(event.date),
                        ),
                        if (time.isNotEmpty && time != 'TBD')
                          _buildInfoChip(
                            Icons.access_time_rounded,
                            time,
                          ),
                        if (event.location.isNotEmpty)
                          _buildInfoChip(
                            Icons.location_on_rounded,
                            event.location,
                          ),
                        if (capacity > 0)
                          _buildInfoChip(
                            Icons.group_rounded,
                            '$capacity capacity',
                          ),
                        if (event.organization.isNotEmpty && event.organization != 'Unknown')
                          _buildInfoChip(
                            Icons.business_center,
                            event.organization,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Description ───────────────────────────────────
                    if (event.description.isNotEmpty) ...[
                      _sectionLabel(
                        'Description',
                        icon: Icons.description_outlined,
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E6EA)),
                        ),
                        child: Text(
                          event.description,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: const Color(0xFF374151),
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Event Details (two‑column) ──────────────────
                    _sectionLabel(
                      'Event Details',
                      icon: Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildDetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: event.category,
                          valueColor: _getCategoryColor(event.category),
                        ),
                        if (time.isNotEmpty && time != 'TBD')
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Time',
                            value: time,
                          ),
                        if (event.location.isNotEmpty)
                          _buildDetailRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: event.location,
                          ),
                        if (capacity > 0)
                          _buildDetailRow(
                            icon: Icons.group_outlined,
                            label: 'Capacity',
                            value: '$capacity attendees',
                          ),
                        if (event.organization.isNotEmpty && event.organization != 'Unknown')
                          _buildDetailRow(
                            icon: Icons.business_center,
                            label: 'Organization',
                            value: event.organization,
                          ),
                      ],
                    ),

                    // ── Guest Speaker ────────────────────────────────
                    if (guestSpeaker.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionLabel(
                        'Guest Speaker',
                        icon: Icons.person_outline,
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(event.category).withAlpha(26),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _getCategoryColor(event.category).withAlpha(51),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(event.category).withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: _getCategoryColor(event.category),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                guestSpeaker,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF1A202C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Tags ─────────────────────────────────────────
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionLabel(
                        'Tags',
                        icon: Icons.local_offer_outlined,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(event.category).withAlpha(26),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getCategoryColor(event.category).withAlpha(77),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _getCategoryColor(event.category),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Footer ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE8ECF0)),
                ),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(_DS.radiusLg),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper for detail rows (if not already present)
Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  return SizedBox(
    width: 240,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9AA5B4)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _detailItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF1A202C))),
    ]);
  }

  String _formatTime(String time) {
    try {
      final parts  = time.split(':');
      int hour     = int.parse(parts[0]);
      int minute   = int.parse(parts[1]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return time;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 20, color: UpriseColors.primaryDark),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final _Event event;
  final String? displayTime;
  final VoidCallback onTap;
  const _EventListTile({required this.event, this.displayTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);
    final rawTime = displayTime ?? event.time;
    final timeLabel = (rawTime.isEmpty || rawTime == 'TBD') ? 'TBD' : _fmtTime(rawTime);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: categoryColor.withAlpha(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: categoryColor.withAlpha(13),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: categoryColor.withAlpha(51)),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(event.category,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: categoryColor)),
                const SizedBox(width: 8),
                Text(event.organization,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF9AA5B4)),
              const SizedBox(width: 3),
              Text(
                timeLabel,
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4)),
              ),
            ]),
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF9AA5B4)),
        ]),
      ),
    );
  }

  String _fmtTime(String time) {
    try {
      final parts  = time.split(':');
      int hour     = int.parse(parts[0]);
      int minute   = int.parse(parts[1]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return time;
    }
  }
}

class _ExportEventsButton extends StatelessWidget {
  const _ExportEventsButton();

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(onSelected: (choice) => _doExport(context, choice));
  }

  Future<void> _doExport(BuildContext context, String format) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved')
          .orderBy('date')
          .get();
      var docs = snap.docs;

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No data to export.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      String content, fileName;
      final now = DateTime.now().toString().substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('Title,Organization,Category,Date,Time');
        for (final doc in docs) {
          final d    = doc.data();
          final date = (d['date'] as Timestamp).toDate();
          String esc(String s) => '"${s.replaceAll('"', '""')}"';
          buf.writeln([
            esc(d['title']   ?? ''),
            esc(d['orgName'] ?? ''),
            esc(d['category'] ?? 'Other'),
            esc(DateFormat('yyyy-MM-dd').format(date)),
            esc(d['time']    ?? ''),
          ].join(','));
        }
        content  = buf.toString();
        fileName = 'events_$now.csv';
        await AdminExportUtil.saveText(
          content,
          fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d    = doc.data();
          final date = (d['date'] as Timestamp).toDate();
          return [
            d['title']   ?? '',
            d['orgName'] ?? '',
            d['category'] ?? 'Other',
            DateFormat('yyyy-MM-dd').format(date),
            d['time']    ?? '',
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Event Calendar Report',
          headers: const ['Title', 'Organization', 'Category', 'Date', 'Time'],
          rows: rows,
        );

        await AdminExportUtil.saveBytes(
          pdfBytes,
          'events_$now.pdf',
          mimeType: 'application/pdf',
        );
      } else {
        throw UnsupportedError('Unsupported export format: $format');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: UpriseColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}