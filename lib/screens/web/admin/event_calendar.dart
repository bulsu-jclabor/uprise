import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts / event_proposals
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

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
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

Widget _statusBadge(String status) {
  const Map<String, _BadgeStyle> styles = {
    'approved': _BadgeStyle(Color(0xFFECFDF5), Color(0xFF059669), 'APPROVED'),
    'pending':  _BadgeStyle(Color(0xFFFFFBEB), Color(0xFFD97706), 'PENDING'),
    'rejected': _BadgeStyle(Color(0xFFFEF2F2), Color(0xFFDC2626), 'REJECTED'),
    'archived': _BadgeStyle(Color(0xFFF3F4F6), Color(0xFF6B7280), 'ARCHIVED'),
  };
  final s = styles[status.toLowerCase()] ??
      const _BadgeStyle(Color(0xFFF3F4F6), Color(0xFF6B7280), '—');
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s.bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      s.label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: s.fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved': return const Color(0xFF059669);
    case 'pending':  return const Color(0xFFD97706);
    case 'rejected': return const Color(0xFFDC2626);
    case 'archived': return const Color(0xFF6B7280);
    default:         return UpriseColors.primaryDark;
  }
}

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Event model
// ─────────────────────────────────────────────────────────────────────────────
class _Event {
  final String id, title, time, type, organization, status;
  final DateTime date;
  const _Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.type,
    required this.organization,
    required this.status,
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
  String _statusFilter = 'All';

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(),
            _buildToolbar(),
            const SizedBox(height: 16),
            _buildCalendarStream(),
            _buildLegend(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            if (status == 'pending')  pending++;
            if (status == 'approved') approved++;
            if (status == 'rejected') rejected++;
            if (status == 'archived') archived++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total Events', value: '$total',    icon: Icons.event_rounded,           color: UpriseColors.primaryDark),
            const SizedBox(width: 14),
            _StatCard(label: 'Approved',     value: '$approved', icon: Icons.check_circle_rounded,    color: const Color(0xFF059669)),
            const SizedBox(width: 14),
            _StatCard(label: 'Pending',      value: '$pending',  icon: Icons.pending_rounded,         color: const Color(0xFFD97706)),
            const SizedBox(width: 14),
            _StatCard(label: 'Rejected',     value: '$rejected', icon: Icons.cancel_rounded,          color: const Color(0xFFDC2626)),
            const SizedBox(width: 14),
            _StatCard(label: 'Archived',     value: '$archived', icon: Icons.archive_rounded,         color: const Color(0xFF6B7280)),
          ]),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(children: [
        // Month navigator
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
        // Today
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
        // Status filter
        _FilterDropdown(
          value: _statusFilter,
          items: const ['All', 'Pending', 'Approved', 'Rejected', 'Archived'],
          onChanged: (v) => setState(() => _statusFilter = v!),
        ),
        const SizedBox(width: 10),
        // Export
        _ExportEventsButton(statusFilter: _statusFilter),
      ]),
    );
  }

  // ── Calendar stream ───────────────────────────────────────────────
  Widget _buildCalendarStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
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

        final allEvents = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _Event(
            id:           doc.id,
            title:        d['title']   ?? 'Untitled',
            date:         (d['date']   as Timestamp).toDate(),
            time:         d['time']    ?? 'TBD',
            type:         d['type']    ?? 'In Person',
            organization: d['orgName'] ?? 'Unknown',
            status:       d['status']  ?? 'pending',
          );
        }).toList();

        final filtered = _statusFilter == 'All'
            ? allEvents
            : allEvents.where((e) => e.status.toLowerCase() == _statusFilter.toLowerCase()).toList();

        return _buildCalendarGrid(filtered);
      },
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────
  Widget _buildCalendarGrid(List<_Event> events) {
    final firstDay       = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday   = firstDay.weekday % 7; // 0 = Sun
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
        // Weekday header row
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
        // Day cells
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.85,
          ),
          itemCount: 42,
          itemBuilder: (_, index) {
            final dayNum = index - startWeekday + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return _buildEmptyCell(
                isFirstRow: index < 7,
                isLastRow: index >= 35,
                colIndex: index % 7,
                // bottom-right radius on last cell
                isBottomRight: index == 41,
                isBottomLeft: index == 35,
              );
            }
            return _buildDayCell(dayNum, byDay[dayNum] ?? []);
          },
        ),
      ]),
    );
  }

  Widget _buildEmptyCell({
    bool isFirstRow = false,
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
    final display = sorted.take(3).toList();
    final extra   = sorted.length - display.length;

    // Is it a last-row cell?
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
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 24,
                  height: 24,
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
                if (events.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _statusColor(sorted.first.status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${events.length}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(sorted.first.status),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            // Event pills
            ...display.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(e.status).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(4),
                      border: Border(
                        left: BorderSide(color: _statusColor(e.status), width: 2),
                      ),
                    ),
                    child: Text(
                      e.title.length > 13 ? '${e.title.substring(0, 13)}…' : e.title,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(e.status),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )),
            if (extra > 0)
              Text(
                '+$extra more',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 9,
                  color: const Color(0xFF9AA5B4),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Legend ────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot('Approved', const Color(0xFF059669)),
            const SizedBox(width: 20),
            _legendDot('Pending',  const Color(0xFFD97706)),
            const SizedBox(width: 20),
            _legendDot('Rejected', const Color(0xFFDC2626)),
            const SizedBox(width: 20),
            _legendDot('Archived', const Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
    ]);
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E6EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
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
            // Event list
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
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
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
                              fontSize: 12, color: Colors.white.withOpacity(0.7))),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Event Details', icon: Icons.info_outline_rounded),
                      Row(children: [
                        Expanded(child: _detailItem('Status',   event.status[0].toUpperCase() + event.status.substring(1), Icons.circle_outlined, valueColor: _statusColor(event.status))),
                        const SizedBox(width: 16),
                        Expanded(child: _detailItem('Type',     event.type, Icons.category_outlined)),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: _detailItem('Date',     DateFormat('MMMM d, yyyy').format(event.date), Icons.calendar_today_outlined)),
                        const SizedBox(width: 16),
                        Expanded(child: _detailItem('Time',     _formatTime(event.time), Icons.access_time_rounded)),
                      ]),
                      const SizedBox(height: 14),
                      _detailItem('Organization', event.organization, Icons.group_outlined),
                    ],
                  ),
                ),
              ),
              // Footer
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

  // ── Helpers ───────────────────────────────────────────────────────
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

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _statusColor(event.status).withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _statusColor(event.status).withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: _statusColor(event.status),
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
              Text(event.organization,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _statusBadge(event.status),
            const SizedBox(height: 4),
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
  final String statusFilter;
  const _ExportEventsButton({required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: PopupMenuButton<String>(
        onSelected: (choice) => _doExport(context, choice),
        itemBuilder: (_) => [
          _item('csv',  Icons.table_chart_rounded,  'Export as CSV'),
          _item('pdf',  Icons.picture_as_pdf_rounded, 'Export as PDF'),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            const Icon(Icons.download_rounded, size: 16, color: Color(0xFF374151)),
            const SizedBox(width: 6),
            Text('Export',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA5B4)),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13)),
      ]),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .get();
      var docs = snap.docs;

      if (statusFilter != 'All') {
        docs = docs.where((d) =>
            (d.data())['status'] == statusFilter.toLowerCase()).toList();
      }

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
        buf.writeln('Title,Organization,Date,Time,Type,Status');
        for (final doc in docs) {
          final d    = doc.data();
          final date = (d['date'] as Timestamp).toDate();
          String esc(String s) => '"${s.replaceAll('"', '""')}"';
          buf.writeln([
            esc(d['title']   ?? ''),
            esc(d['orgName'] ?? ''),
            esc(DateFormat('yyyy-MM-dd').format(date)),
            esc(d['time']    ?? ''),
            esc(d['type']    ?? ''),
            esc(d['status']  ?? ''),
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
            DateFormat('yyyy-MM-dd').format(date),
            d['time']    ?? '',
            d['type']    ?? '',
            d['status']  ?? '',
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Event Calendar Report',
          headers: const ['Title', 'Organization', 'Date', 'Time', 'Type', 'Status'],
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