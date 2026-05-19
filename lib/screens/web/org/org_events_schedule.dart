// lib/screens/web/org/org_events_schedule.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ============ COLOR SCHEME ============
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

// ============ CATEGORY COLORS ============
class CategoryColors {
  static const Map<String, Color> bg = {
    'Academic':  Color(0xFFDCFCE7),
    'Technical': Color(0xFFDBEAFE),
    'Cultural':  Color(0xFFFCE7F3),
    'Sports':    Color(0xFFFFEDD5),
    'Other':     Color(0xFFF3F4F6),
  };
  static const Map<String, Color> fg = {
    'Academic':  Color(0xFF15803D),
    'Technical': Color(0xFF1D4ED8),
    'Cultural':  Color(0xFFBE185D),
    'Sports':    Color(0xFFEA580C),
    'Other':     Color(0xFF374151),
  };
  static const Map<String, Color> dot = {
    'Academic':  Color(0xFF22C55E),
    'Technical': Color(0xFF3B82F6),
    'Cultural':  Color(0xFFEC4899),
    'Sports':    Color(0xFFF97316),
    'Other':     Color(0xFF9CA3AF),
  };

  static Color getBg(String cat) => bg[cat] ?? bg['Other']!;
  static Color getFg(String cat) => fg[cat] ?? fg['Other']!;
  static Color getDot(String cat) => dot[cat] ?? dot['Other']!;
}

// ============ MAIN SCREEN ============
class OrgEventsScheduleScreen extends StatefulWidget {
  final String orgId;
  const OrgEventsScheduleScreen({super.key, required this.orgId});

  @override
  State<OrgEventsScheduleScreen> createState() => _OrgEventsScheduleScreenState();
}

class _OrgEventsScheduleScreenState extends State<OrgEventsScheduleScreen> {
  String    _viewMode     = 'calendar';
  DateTime  _focusedMonth = DateTime.now();
  EventModel? _selectedEvent;

  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('date', descending: false)
      .snapshots();

  void _openEventModal({EventModel? event}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EventModal(orgId: widget.orgId, existingEvent: event),
    ).then((_) => setState(() {}));
  }

  void _openDetailModal(EventModel event) {
    showDialog(
      context: context,
      builder: (_) => _EventDetailModal(event: event, orgId: widget.orgId,
        onEdit: () {
          Navigator.pop(context);
          _openEventModal(event: event);
        },
        onDelete: () {
          Navigator.pop(context);
          _deleteEvent(event);
        },
      ),
    );
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: OrgColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_event', module: 'events_schedule',
        details: {'orgId': widget.orgId, 'eventId': event.id, 'title': event.title},
      );
      if (mounted) {
        setState(() { if (_selectedEvent?.id == event.id) _selectedEvent = null; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---- Header ----
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Events and Schedules',
              style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: OrgColors.charcoal)),
            const SizedBox(height: 2),
            Text('View all events in calendar format',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
          ]),
          const Spacer(),
          // View toggle
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: OrgColors.primaryLight),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              _toggleBtn('Calendar View', 'calendar'),
              _toggleBtn('Archived List', 'list'),
            ]),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _openEventModal(),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: Text('Create Event',
              style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ---- Main content ----
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OrgColors.primaryLight),
            ),
            child: Column(children: [
              // Calendar toolbar
              _buildCalendarToolbar(),
              Expanded(
                child: _viewMode == 'calendar'
                    ? _buildCalendarView()
                    : _buildListView(),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _toggleBtn(String label, String value) {
    final isActive = _viewMode == value;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? OrgColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          color: isActive ? Colors.white : OrgColors.darkGray,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        )),
      ),
    );
  }

  // Month nav + category legend
  Widget _buildCalendarToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        // Month navigation
        IconButton(
          onPressed: () => setState(() =>
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1)),
          icon: Icon(Icons.chevron_left, size: 20, color: OrgColors.primaryDark),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Text(DateFormat('MMMM yyyy').format(_focusedMonth),
          style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
        const SizedBox(width: 8),
        // Today button
        GestureDetector(
          onTap: () => setState(() => _focusedMonth = DateTime.now()),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: OrgColors.primaryLight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('TODAY', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
          ),
        ),
        IconButton(
          onPressed: () => setState(() =>
            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1)),
          icon: Icon(Icons.chevron_right, size: 20, color: OrgColors.primaryDark),
          padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const Spacer(),
        // Category legend
        ...[
          ('Academic', CategoryColors.getDot('Academic')),
          ('Technical', CategoryColors.getDot('Technical')),
          ('Cultural', CategoryColors.getDot('Cultural')),
          ('Sports', CategoryColors.getDot('Sports')),
        ].map((item) => Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(item.$1, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
          ]),
        )),
      ]),
    );
  }

  // ============ CALENDAR VIEW ============
  Widget _buildCalendarView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        final events = snapshot.hasData
            ? snapshot.data!.docs.map((d) => EventModel.fromFirestore(d)).toList()
            : <EventModel>[];
        return _CalendarGrid(
          focusedMonth: _focusedMonth,
          events: events,
          onEventTap: _openDetailModal,
        );
      },
    );
  }

  // ============ LIST VIEW ============
  Widget _buildListView() {
    return StreamBuilder<QuerySnapshot>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.event_busy, size: 48, color: OrgColors.mediumGray),
            const SizedBox(height: 12),
            Text('No events scheduled', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
          ]));
        }
        final events = snapshot.data!.docs.map((d) => EventModel.fromFirestore(d)).toList();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: OrgColors.mediumGray),
          itemBuilder: (context, i) {
            final event = events[i];
            return ListTile(
              leading: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: CategoryColors.getDot(event.category), shape: BoxShape.circle),
              ),
              title: Text(event.title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                '${DateFormat('MMM dd, yyyy').format(event.date)} • ${event.startTime} - ${event.endTime} • ${event.location}',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              ),
              trailing: _CategoryChip(category: event.category),
              onTap: () => _openDetailModal(event),
            );
          },
        );
      },
    );
  }
}

// ============ CALENDAR GRID ============
class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final List<EventModel> events;
  final Function(EventModel) onEventTap;

  const _CalendarGrid({required this.focusedMonth, required this.events, required this.onEventTap});

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  int get _daysInMonth => DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
  int get _firstWeekday => DateTime(focusedMonth.year, focusedMonth.month, 1).weekday % 7;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<EventModel>> byDate = {};
    for (final e in events) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      byDate.putIfAbsent(key, () => []).add(e);
    }

    final totalCells = ((_firstWeekday + _daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    return Column(children: [
      // Weekday headers
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: _weekdays.map((d) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(d, textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600,
                  color: OrgColors.darkGray, letterSpacing: 0.5)),
            ),
          )).toList(),
        ),
      ),
      Divider(height: 1, color: OrgColors.mediumGray),

      // Day cells
      Expanded(
        child: LayoutBuilder(builder: (context, constraints) {
          final rows = (totalCells / 7).ceil();
          final cellH = constraints.maxHeight / rows;

          return Column(
            children: List.generate(rows, (row) {
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(7, (col) {
                    final index = row * 7 + col;
                    final dayNum = index - _firstWeekday + 1;
                    final inMonth = dayNum >= 1 && dayNum <= _daysInMonth;
                    final date = inMonth
                        ? DateTime(focusedMonth.year, focusedMonth.month, dayNum)
                        : null;
                    final key = date != null ? DateFormat('yyyy-MM-dd').format(date) : null;
                    final dayEvents = key != null ? byDate[key] ?? [] : <EventModel>[];
                    final isToday = date != null &&
                        date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
                    final isWeekend = col == 0 || col == 6;

                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isWeekend && inMonth
                              ? const Color(0xFFFAFAFA)
                              : OrgColors.white,
                          border: Border(
                            right: col < 6 ? BorderSide(color: OrgColors.primaryLight, width: 0.5) : BorderSide.none,
                            bottom: row < rows - 1 ? BorderSide(color: OrgColors.primaryLight, width: 0.5) : BorderSide.none,
                          ),
                        ),
                        child: inMonth
                            ? _DayCell(
                                dayNum: dayNum,
                                isToday: isToday,
                                events: dayEvents,
                                onEventTap: onEventTap,
                              )
                            : const SizedBox(),
                      ),
                    );
                  }),
                ),
              );
            }),
          );
        }),
      ),
    ]);
  }
}

// ============ DAY CELL ============
class _DayCell extends StatelessWidget {
  final int dayNum;
  final bool isToday;
  final List<EventModel> events;
  final Function(EventModel) onEventTap;

  const _DayCell({
    required this.dayNum,
    required this.isToday,
    required this.events,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Day number
        Align(
          alignment: Alignment.topRight,
          child: Container(
            width: 24, height: 24,
            decoration: isToday
                ? BoxDecoration(color: OrgColors.primaryDark, shape: BoxShape.circle)
                : null,
            child: Center(
              child: Text(
                dayNum.toString(),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday ? Colors.white : OrgColors.charcoal,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Event chips — show up to 2, then "+N more"
        ...events.take(2).map((e) => _EventChip(event: e, onTap: () => onEventTap(e))),
        if (events.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text('+${events.length - 2} more',
              style: GoogleFonts.beVietnamPro(fontSize: 9, color: OrgColors.darkGray)),
          ),
      ]),
    );
  }
}

// ============ EVENT CHIP (on calendar cell) ============
class _EventChip extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  const _EventChip({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: CategoryColors.getBg(event.category),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: CategoryColors.getDot(event.category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(event.title,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: CategoryColors.getFg(event.category),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}

// ============ CATEGORY CHIP ============
class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CategoryColors.getBg(category),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(category,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: CategoryColors.getFg(category),
        )),
    );
  }
}

// ============ EVENT DETAIL MODAL (dark design from screenshot) ============
class _EventDetailModal extends StatelessWidget {
  final EventModel event;
  final String orgId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventDetailModal({
    required this.event,
    required this.orgId,
    required this.onEdit,
    required this.onDelete,
  });

  Future<int> _getAttendeeCount() async {
    final snap = await FirebaseFirestore.instance
        .collection('events').doc(event.id)
        .collection('attendances')
        .where('status', isEqualTo: 'present')
        .get();
    return snap.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 32, offset: const Offset(0, 12))],
        ),
        child: Row(children: [
          // ---- Left: dark panel ----
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CategoryColors.getBg(event.category),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(event.category.toUpperCase(),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: CategoryColors.getFg(event.category),
                    letterSpacing: 0.5,
                  )),
              ),
              const SizedBox(height: 14),
              // Title
              Text(event.title,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
              const SizedBox(height: 8),
              Text('Scheduled for ${_semester(event.date)}\nAcademic Year ${_academicYear(event.date)}',
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white54, height: 1.5)),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              // Date & time
              _darkInfoRow(Icons.calendar_today_outlined,
                'DATE & TIME',
                '${DateFormat('MMMM d, yyyy').format(event.date)}\n${event.startTime} - ${event.endTime}'),
              const SizedBox(height: 14),
              _darkInfoRow(Icons.location_on_outlined, 'LOCATION', event.location),
              const SizedBox(height: 14),
              _darkInfoRow(Icons.person_outline, 'GUEST SPEAKER', event.guestSpeaker.isNotEmpty ? event.guestSpeaker : '—'),
              const Spacer(),
              // Registration progress
              FutureBuilder<int>(
                future: _getAttendeeCount(),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  final cap = event.capacity > 0 ? event.capacity : 100;
                  final pct = (count / cap).clamp(0.0, 1.0);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Registration Progress',
                        style: GoogleFonts.beVietnamPro(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w600)),
                      Text('$count/$cap',
                        style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.accent, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(OrgColors.accent),
                      ),
                    ),
                  ]);
                },
              ),
            ]),
          ),

          // ---- Right: white panel ----
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: OrgColors.white,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              ),
              child: Column(children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(children: [
                    Text('EVENT OVERVIEW',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700,
                        color: OrgColors.darkGray, letterSpacing: 0.8)),
                    const Spacer(),
                    // Edit & Delete actions
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 18, color: OrgColors.primaryDark),
                      tooltip: 'Edit',
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline, size: 18, color: OrgColors.error),
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: OrgColors.lightGray,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.close, size: 16, color: OrgColors.darkGray),
                      ),
                    ),
                  ]),
                ),
                Divider(height: 1, color: OrgColors.mediumGray),

                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Description
                      Text(event.description.isNotEmpty ? event.description : 'No description provided.',
                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal, height: 1.6)),
                      const SizedBox(height: 20),

                      // Resources & Lab Preparation cards
                      Row(children: [
                        Expanded(child: _infoCard(
                          icon: Icons.folder_outlined,
                          title: 'Resources',
                          items: event.resources.isNotEmpty ? event.resources : ['Virtual Machine, Container, Lab Actions Files'],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _infoCard(
                          icon: Icons.settings_outlined,
                          title: 'Lab Preparation',
                          items: event.labPreparation.isNotEmpty ? event.labPreparation : ['Lab is pre-configured for all registered participants'],
                        )),
                      ]),
                      const SizedBox(height: 20),

                      // Tags / additional info row
                      if (event.tags.isNotEmpty) ...[
                        Text('Tags',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6, runSpacing: 6,
                          children: event.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: OrgColors.lightGray, borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: OrgColors.primaryLight)),
                            child: Text(tag, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                          )).toList(),
                        ),
                      ],
                    ]),
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        side: BorderSide(color: OrgColors.primaryLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Close', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: onEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrgColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text('Edit Event', style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _darkInfoRow(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white38, letterSpacing: 0.6)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 6),
        Expanded(child: Text(value,
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white, height: 1.4))),
      ]),
    ],
  );

  Widget _infoCard({required IconData icon, required String title, required List<String> items}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: OrgColors.primaryDark),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: OrgColors.darkGray, shape: BoxShape.circle))),
            const SizedBox(width: 6),
            Expanded(child: Text(item, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray, height: 1.4))),
          ]),
        )),
      ]),
    );
  }

  String _semester(DateTime date) {
    final month = date.month;
    if (month >= 8 && month <= 12) return '1st Semester';
    if (month >= 1 && month <= 5)  return '2nd Semester';
    return 'Summer';
  }

  String _academicYear(DateTime date) {
    final y = date.year;
    return date.month >= 8 ? '$y - ${y + 1}' : '${y - 1} - $y';
  }
}

// ============ ADD/EDIT EVENT MODAL ============
class _EventModal extends StatefulWidget {
  final String orgId;
  final EventModel? existingEvent;
  const _EventModal({required this.orgId, this.existingEvent});

  @override
  State<_EventModal> createState() => _EventModalState();
}

class _EventModalState extends State<_EventModal> {
  final _formKey        = GlobalKey<FormState>();
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _locationCtrl   = TextEditingController();
  final _capacityCtrl   = TextEditingController();
  final _startTimeCtrl  = TextEditingController();
  final _endTimeCtrl    = TextEditingController();
  final _speakerCtrl    = TextEditingController();
  final _resourcesCtrl  = TextEditingController();
  final _labPrepCtrl    = TextEditingController();
  final _tagsCtrl       = TextEditingController();

  DateTime? _selectedDate;
  String _selectedCategory = 'Academic';
  bool _isSubmitting = false;

  static const _categories = ['Academic', 'Technical', 'Cultural', 'Sports', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    if (e != null) {
      _titleCtrl.text     = e.title;
      _descCtrl.text      = e.description;
      _locationCtrl.text  = e.location;
      _capacityCtrl.text  = e.capacity.toString();
      _startTimeCtrl.text = e.startTime;
      _endTimeCtrl.text   = e.endTime;
      _speakerCtrl.text   = e.guestSpeaker;
      _resourcesCtrl.text = e.resources.join(', ');
      _labPrepCtrl.text   = e.labPreparation.join(', ');
      _tagsCtrl.text      = e.tags.join(', ');
      _selectedDate       = e.date;
      _selectedCategory   = e.category;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose();
    _capacityCtrl.dispose(); _startTimeCtrl.dispose(); _endTimeCtrl.dispose();
    _speakerCtrl.dispose(); _resourcesCtrl.dispose(); _labPrepCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }
    setState(() => _isSubmitting = true);

    List<String> splitComma(String s) =>
        s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final data = {
      'orgId':          widget.orgId,
      'title':          _titleCtrl.text.trim(),
      'description':    _descCtrl.text.trim(),
      'location':       _locationCtrl.text.trim(),
      'capacity':       int.tryParse(_capacityCtrl.text.trim()) ?? 0,
      'startTime':      _startTimeCtrl.text.trim(),
      'endTime':        _endTimeCtrl.text.trim(),
      'guestSpeaker':   _speakerCtrl.text.trim(),
      'resources':      splitComma(_resourcesCtrl.text),
      'labPreparation': splitComma(_labPrepCtrl.text),
      'tags':           splitComma(_tagsCtrl.text),
      'category':       _selectedCategory,
      'date':           Timestamp.fromDate(_selectedDate!),
      'updatedAt':      FieldValue.serverTimestamp(),
    };

    try {
      if (widget.existingEvent != null) {
        await FirebaseFirestore.instance.collection('events').doc(widget.existingEvent!.id).update(data);
        await activity_log.ActivityLogger.log(action: 'edit_event', module: 'events_schedule',
          details: {'orgId': widget.orgId, 'eventId': widget.existingEvent!.id, 'title': data['title']});
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').add(data);
        await activity_log.ActivityLogger.log(action: 'create_event', module: 'events_schedule',
          details: {'orgId': widget.orgId, 'title': data['title']});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEvent != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
              ),
              child: Row(children: [
                Icon(Icons.event_note, color: OrgColors.primaryDark, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Event' : 'Create Event',
                    style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
                  Text('Fill in the event details below',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                ])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _field('Event Title *', _textInput(_titleCtrl, 'e.g. Hacking Workshop',
                      validator: (v) => v!.isEmpty ? 'Required' : null))),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Category *', _dropdownInput())),
                  ]),
                  const SizedBox(height: 14),
                  _field('Description', _textInput(_descCtrl, 'Describe the event...', maxLines: 3)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _field('Date *', _dateInput())),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Location *', _textInput(_locationCtrl, 'e.g. CIT Lab 2',
                      validator: (v) => v!.isEmpty ? 'Required' : null))),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _field('Start Time', _timeInput(_startTimeCtrl, 'Start time'))),
                    const SizedBox(width: 12),
                    Expanded(child: _field('End Time', _timeInput(_endTimeCtrl, 'End time'))),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Capacity', _textInput(_capacityCtrl, '100', keyboardType: TextInputType.number))),
                  ]),
                  const SizedBox(height: 14),
                  _field('Guest Speaker', _textInput(_speakerCtrl, 'Full name and title')),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _field('Resources (comma-separated)', _textInput(_resourcesCtrl, 'e.g. Slides, Lab Files'))),
                    const SizedBox(width: 12),
                    Expanded(child: _field('Lab Preparation', _textInput(_labPrepCtrl, 'e.g. Pre-configured VMs'))),
                  ]),
                  const SizedBox(height: 14),
                  _field('Tags (comma-separated)', _textInput(_tagsCtrl, 'e.g. Cybersecurity, Networking')),
                ]),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: OrgColors.primaryLight))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(color: OrgColors.primaryLight),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'Save Changes' : 'Create Event',
                          style: GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
      const SizedBox(height: 6),
      child,
    ],
  );

  Widget _textInput(TextEditingController ctrl, String hint,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType, validator: validator,
      style: GoogleFonts.beVietnamPro(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
        filled: true, fillColor: OrgColors.lightGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryDark, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.error)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 10 : 0),
      ),
    );
  }

  Widget _dropdownInput() => DropdownButtonFormField<String>(
    value: _selectedCategory,
    items: _categories.map((c) => DropdownMenuItem(value: c, child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: CategoryColors.getDot(c), shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(c),
    ]))).toList(),
    onChanged: (v) => setState(() => _selectedCategory = v!),
    style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
    decoration: InputDecoration(
      filled: true, fillColor: OrgColors.lightGray,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryLight)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: OrgColors.primaryDark, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
    ),
  );

  Widget _dateInput() => GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime(2030));
      if (picked != null) setState(() => _selectedDate = picked);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today, size: 15, color: OrgColors.darkGray),
        const SizedBox(width: 8),
        Text(
          _selectedDate != null ? DateFormat('MM/dd/yyyy').format(_selectedDate!) : 'Select date',
          style: GoogleFonts.beVietnamPro(fontSize: 13,
            color: _selectedDate != null ? OrgColors.charcoal : OrgColors.darkGray),
        ),
      ]),
    ),
  );

  Widget _timeInput(TextEditingController ctrl, String hint) => GestureDetector(
    onTap: () async {
      final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (picked != null && mounted) setState(() => ctrl.text = picked.format(context));
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OrgColors.lightGray, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(children: [
        Icon(Icons.access_time, size: 15, color: OrgColors.darkGray),
        const SizedBox(width: 8),
        Text(ctrl.text.isEmpty ? hint : ctrl.text,
          style: GoogleFonts.beVietnamPro(fontSize: 13,
            color: ctrl.text.isEmpty ? OrgColors.darkGray : OrgColors.charcoal)),
      ]),
    ),
  );
}

// ============ EVENT MODEL ============
class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final int capacity;
  final String startTime;
  final String endTime;
  final String category;
  final String guestSpeaker;
  final List<String> resources;
  final List<String> labPreparation;
  final List<String> tags;
  final DateTime date;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.capacity,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.guestSpeaker,
    required this.resources,
    required this.labPreparation,
    required this.tags,
    required this.date,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<String> toList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }
    return EventModel(
      id:             doc.id,
      title:          d['title'] ?? '',
      description:    d['description'] ?? '',
      location:       d['location'] ?? '',
      capacity:       d['capacity'] ?? 0,
      startTime:      d['startTime'] ?? '',
      endTime:        d['endTime'] ?? '',
      category:       d['category'] ?? 'Other',
      guestSpeaker:   d['guestSpeaker'] ?? '',
      resources:      toList(d['resources']),
      labPreparation: toList(d['labPreparation']),
      tags:           toList(d['tags']),
      date:           (d['date'] as Timestamp).toDate(),
    );
  }
}



