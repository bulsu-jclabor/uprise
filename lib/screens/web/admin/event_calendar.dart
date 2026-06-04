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
  'General Assembly': const Color(0xFFF59E0B),
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

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
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
  final String id, title, time, category, organization;
  final DateTime date;
  
  _Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.category,
    required this.organization,
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
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
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
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Row(children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E6EA)),
            boxShadow: _DS.cardShadow,
          ),
          child: Row(children: [
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
          ]),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _currentMonth = DateTime.now()),
          icon: const Icon(Icons.today_rounded, size: 15),
          label: Text('Today', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: UpriseColors.primaryDark,
            side: BorderSide(color: UpriseColors.primaryDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
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
            title:        d['title']   ?? 'Untitled',
            date:         (d['date']   as Timestamp).toDate(),
            time:         d['time']    ?? 'TBD',
            category:     d['category'] ?? 'Other',
            organization: d['orgName'] ?? 'Unknown',
          );
        }).toList();

        return _buildCalendarGrid(events);
      },
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────
  Widget _buildCalendarGrid(List<_Event> events) {
    final firstDay       = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday   = firstDay.weekday % 7;
    final daysInMonth    = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

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
            color: Color(0xFFF8F9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
          ),
          child: Row(
            children: weekdays.map((d) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
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
        SizedBox(
          height: 520,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: 42,
            itemBuilder: (_, index) {
              final dayNum = index - startWeekday + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return _buildEmptyCell(
                  isLastRow: index >= 35,
                  colIndex: index % 7,
                  isBottomRight: index == 41,
                  isBottomLeft: index == 35,
                );
              }
              return _buildDayCell(dayNum, byDay[dayNum] ?? []);
            },
          ),
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

  Widget _buildDayCell(int day, List<_Event> events) {
    final isToday = day == DateTime.now().day &&
        _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    final sorted  = List<_Event>.from(events)..sort((a, b) => a.time.compareTo(b.time));
    final display = sorted.take(2).toList();
    final extra   = sorted.length - display.length;

    final firstDay     = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday = firstDay.weekday % 7;
    final cellIndex    = startWeekday + day - 1;
    final colIndex     = cellIndex % 7;
    final isLastRow    = cellIndex >= 35;
    final isBottomLeft  = isLastRow && colIndex == 0;
    final isBottomRight = cellIndex == 41 ||
        (isLastRow &&
            day == DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day);

    return InkWell(
      onTap: events.isEmpty ? null : () => _showDayEventsSheet(day, sorted),
      hoverColor: UpriseColors.primaryDark.withOpacity(0.03),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? UpriseColors.primaryDark.withOpacity(0.04) : null,
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
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: isToday
                  ? BoxDecoration(
                      color: UpriseColors.primaryDark,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...display.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(e.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        left: BorderSide(color: _getCategoryColor(e.category), width: 2),
                      ),
                    ),
                    child: Text(
                      e.title.length > 10 ? '${e.title.substring(0, 10)}…' : e.title,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _getCategoryColor(e.category),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )),
            if (extra > 0)
              Text(
                '+$extra',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 8,
                  color: const Color(0xFF9AA5B4),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Day events bottom sheet ────────────────────────────────────────
  void _showDayEventsSheet(int day, List<_Event> events) {
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime(_currentMonth.year, _currentMonth.month, day));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E6EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.event_rounded, color: UpriseColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(dateLabel,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                    Text('${events.length} event${events.length == 1 ? '' : 's'}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12, color: const Color(0xFF64748B))),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ]),
            ),
            const Divider(height: 24, color: Color(0xFFE8ECF0)),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _EventListTile(
                  event: events[i],
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEventDetailDialog(events[i]);
                  },
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Event detail dialog ───────────────────────────────────────────
  void _showEventDetailDialog(_Event event) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 500,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: _getCategoryColor(event.category),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.event_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(event.title,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text(event.organization,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 12, color: Colors.white.withOpacity(0.8))),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Event Details', icon: Icons.info_outline_rounded),
                      Row(children: [
                        Expanded(child: _detailItem('Category', event.category, Icons.category_outlined, valueColor: _getCategoryColor(event.category))),
                        const SizedBox(width: 16),
                        Expanded(child: _detailItem('Date',     DateFormat('MMMM d, yyyy').format(event.date), Icons.calendar_today_outlined)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _detailItem('Time',     _formatTime(event.time), Icons.access_time_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _detailItem('Organization', event.organization, Icons.group_outlined)),
                      ]),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      ),
                      child: Text('Close',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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
  final VoidCallback onTap;
  const _EventListTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: categoryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: categoryColor.withOpacity(0.2)),
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
                event.time == 'TBD' ? 'TBD' : _fmtTime(event.time),
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4)),
              ),
            ]),
          ]),
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