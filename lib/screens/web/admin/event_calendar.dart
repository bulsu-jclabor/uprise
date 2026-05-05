// lib/screens/admin/event_calendar.dart – Fixed Header Layout
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class EventCalendar extends StatefulWidget {
  @override
  _EventCalendarState createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  DateTime _currentMonth = DateTime.now();
  List<Event> _events = [];
  bool _isLoading = true;
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .get();
      _events = snapshot.docs.map((doc) {
        final data = doc.data();
        return Event(
          id: doc.id,
          title: data['title'] ?? 'Untitled',
          date: (data['date'] as Timestamp).toDate(),
          type: data['type'] ?? 'In Person',
          organization: data['orgName'] ?? 'Unknown',
          status: data['status'] ?? 'pending',
        );
      }).toList();
    } catch (e) {
      print('Error loading events: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER (left‑aligned) ----------
            Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              color: UpriseColors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'College Event Calendar',
                    style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Management and scheduling view for College of Information and Communications Technology.',
                    style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                  ),
                ],
              ),
            ),
            // ---------- STATS CARDS ----------
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  _statCard('TOTAL EVENTS', '${_events.length} Scheduled', UpriseColors.primaryDark),
                  SizedBox(width: 16),
                  _statCard('PENDING APPROVALS', '${_events.where((e) => e.status == 'pending').length} Requests', UpriseColors.warning),
                  SizedBox(width: 16),
                  _statCard('SPACE AVAILABILITY', '80% Utilization', UpriseColors.success),
                ],
              ),
            ),
            // ---------- TOOLBAR (month + filter) ----------
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: UpriseColors.primaryDark),
                        onPressed: () => setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                        }),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(),
                        style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: UpriseColors.primaryDark),
                        onPressed: () => setState(() {
                          _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                        }),
                      ),
                    ],
                  ),
                  // Filter dropdown
                  Container(
                    height: 36,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: UpriseColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: UpriseColors.mediumGray),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterType,
                        items: ['All', 'Pending', 'Approved']
                            .map((f) => DropdownMenuItem(value: f, child: Text(f, style: GoogleFonts.beVietnamPro(fontSize: 13))))
                            .toList(),
                        onChanged: (value) => setState(() => _filterType = value!),
                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                        icon: Icon(Icons.filter_list, color: UpriseColors.darkGray, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ---------- CALENDAR GRID ----------
            if (_isLoading)
              Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark))
            else
              _buildCalendarGrid(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    // Filter events
    List<Event> filteredEvents = _events;
    if (_filterType == 'Pending') {
      filteredEvents = _events.where((e) => e.status == 'pending').toList();
    } else if (_filterType == 'Approved') {
      filteredEvents = _events.where((e) => e.status == 'approved').toList();
    }

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    // Group events by day (only for current month)
    Map<int, List<Event>> eventsByDay = {};
    for (var event in filteredEvents) {
      if (event.date.year == _currentMonth.year && event.date.month == _currentMonth.month) {
        eventsByDay.putIfAbsent(event.date.day, () => []).add(event);
      }
    }

    List<Widget> cells = [];
    final weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    // Weekday headers
    for (var day in weekdays) {
      cells.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(day, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        ),
      );
    }

    // Empty cells before month starts
    for (int i = 0; i < startingWeekday; i++) {
      cells.add(_buildDayCell(null, null));
    }

    // Days of month
    for (int day = 1; day <= daysInMonth; day++) {
      final eventsOnDay = eventsByDay[day] ?? [];
      cells.add(_buildDayCell(day, eventsOnDay));
    }

    // Fill remaining cells to complete 42
    int remaining = 42 - cells.length;
    for (int i = 0; i < remaining; i++) {
      cells.add(_buildDayCell(null, null));
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1.2,
        padding: EdgeInsets.all(8),
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(int? day, List<Event>? events) {
    if (day == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: UpriseColors.mediumGray.withOpacity(0.3)),
        ),
      );
    }

    bool isToday = day == DateTime.now().day &&
        _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: UpriseColors.mediumGray.withOpacity(0.3)),
        color: isToday ? UpriseColors.primaryDark.withOpacity(0.05) : null,
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.toString(),
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? UpriseColors.primaryDark : UpriseColors.charcoal,
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              itemCount: events!.length > 2 ? 2 : events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 2),
                  child: Text(
                    event.title.length > 12 ? '${event.title.substring(0, 12)}...' : event.title,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 10,
                      color: event.status == 'pending' ? UpriseColors.warning : UpriseColors.success,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          if (events.length > 2)
            Text(
              '+${events.length - 2} more',
              style: GoogleFonts.beVietnamPro(fontSize: 9, color: UpriseColors.darkGray),
            ),
        ],
      ),
    );
  }
}

class Event {
  final String id;
  final String title;
  final DateTime date;
  final String type;
  final String organization;
  final String status;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    required this.organization,
    required this.status,
  });
}