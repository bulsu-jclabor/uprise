import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';

// ============ ACTIVITY LOGGER ============
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details': details,
    });
  }
}

class EventCalendar extends StatefulWidget {
  const EventCalendar({super.key});

  @override
  _EventCalendarState createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  DateTime _currentMonth = DateTime.now();
  String _statusFilter = 'All';

  Color _statusColor(String status) {
    switch (status) {
      case 'approved': return UpriseColors.success;
      case 'pending':  return UpriseColors.warning;
      case 'rejected': return UpriseColors.error;
      case 'archived': return UpriseColors.darkGray;
      default: return UpriseColors.primaryDark;
    }
  }

  void _goToToday() {
    setState(() => _currentMonth = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(),
        backgroundColor: UpriseColors.primaryDark,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Event',
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER ----------
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: UpriseColors.white,
                border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'College Event Calendar',
                          style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage and schedule events for CICT student organizations.',
                          style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _goToToday,
                    icon: const Icon(Icons.today, size: 18),
                    label: const Text('Today'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UpriseColors.primaryDark,
                      side: BorderSide(color: UpriseColors.mediumGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // ---------- STATS CARDS (real‑time) ----------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
                if (snapshot.hasData) {
                  total = snapshot.data!.docs.length;
                  for (var doc in snapshot.data!.docs) {
                    final status = doc['status'] ?? 'pending';
                    switch (status) {
                      case 'pending': pending++; break;
                      case 'approved': approved++; break;
                      case 'rejected': rejected++; break;
                      case 'archived': archived++; break;
                    }
                  }
                }
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      _statCard('TOTAL EVENTS', '$total', UpriseColors.primaryDark),
                      const SizedBox(width: 16),
                      _statCard('PENDING', '$pending', UpriseColors.warning),
                      const SizedBox(width: 16),
                      _statCard('APPROVED', '$approved', UpriseColors.success),
                      const SizedBox(width: 16),
                      _statCard('REJECTED', '$rejected', UpriseColors.error),
                      const SizedBox(width: 16),
                      _statCard('ARCHIVED', '$archived', UpriseColors.darkGray),
                    ],
                  ),
                );
              },
            ),

            // ---------- TOOLBAR ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
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
                  const Spacer(),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: UpriseColors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: UpriseColors.primaryDark, width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        items: ['All', 'Pending', 'Approved', 'Rejected', 'Archived']
                            .map((f) => DropdownMenuItem(
                                  value: f,
                                  child: Row(
                                    children: [
                                      Icon(_statusIcon(f), size: 16, color: _statusColor(f.toLowerCase())),
                                      const SizedBox(width: 8),
                                      Text(f, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _statusFilter = value!),
                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                        icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _exportEventsToCSV,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: UpriseColors.primaryDark,
                      side: BorderSide(color: UpriseColors.mediumGray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ---------- CALENDAR GRID ----------
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').orderBy('date').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: UpriseColors.error)));
                }

                List<Event> allEvents = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Event(
                    id: doc.id,
                    title: data['title'] ?? 'Untitled',
                    date: (data['date'] as Timestamp).toDate(),
                    time: data['time'] != null ? (data['time'] as String) : 'TBD',
                    type: data['type'] ?? 'In Person',
                    organization: data['orgName'] ?? 'Unknown',
                    status: data['status'] ?? 'pending',
                  );
                }).toList();

                List<Event> filteredEvents = allEvents;
                if (_statusFilter != 'All') {
                  filteredEvents = allEvents.where((e) => e.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
                }

                return _buildCalendarGrid(filteredEvents);
              },
            ),

            const SizedBox(height: 16),

            // ---------- LEGEND ----------
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: UpriseColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UpriseColors.primaryDark, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem('Approved', UpriseColors.success),
                  const SizedBox(width: 16),
                  _legendItem('Pending', UpriseColors.warning),
                  const SizedBox(width: 16),
                  _legendItem('Rejected', UpriseColors.error),
                  const SizedBox(width: 16),
                  _legendItem('Archived', UpriseColors.darkGray),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.primaryDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending': return Icons.pending_actions;
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'Archived': return Icons.archive;
      default: return Icons.list;
    }
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
      ],
    );
  }

  Widget _buildCalendarGrid(List<Event> events) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    Map<int, List<Event>> eventsByDay = {};
    for (var event in events) {
      if (event.date.year == _currentMonth.year && event.date.month == _currentMonth.month) {
        eventsByDay.putIfAbsent(event.date.day, () => []).add(event);
      }
    }

    List<Widget> cells = [];
    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    for (var day in weekdays) {
      cells.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(day, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        ),
      );
    }

    for (int i = 0; i < startingWeekday; i++) {
      cells.add(_buildDayCell(null, null));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final dayEvents = eventsByDay[day] ?? [];
      cells.add(_buildDayCell(day, dayEvents));
    }

    int remaining = 42 - cells.length;
    for (int i = 0; i < remaining; i++) {
      cells.add(_buildDayCell(null, null));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.primaryDark, width: 1),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 0.9,
        padding: const EdgeInsets.all(8),
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(int? day, List<Event>? events) {
    if (day == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: UpriseColors.primaryDark.withOpacity(0.3), width: 1),
        ),
      );
    }

    bool isToday = day == DateTime.now().day &&
        _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    final sortedEvents = List<Event>.from(events!);
    sortedEvents.sort((a, b) => a.time.compareTo(b.time));
    final displayEvents = sortedEvents.take(3).toList();
    final hasMore = sortedEvents.length > 3;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: UpriseColors.primaryDark.withOpacity(0.3), width: 1),
        color: isToday ? UpriseColors.primaryDark.withOpacity(0.05) : null,
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day.toString(),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday ? UpriseColors.primaryDark : UpriseColors.charcoal,
                ),
              ),
              if (sortedEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _statusColor(sortedEvents.first.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sortedEvents.length.toString(),
                    style: GoogleFonts.beVietnamPro(fontSize: 9, fontWeight: FontWeight.w600, color: _statusColor(sortedEvents.first.status)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...displayEvents.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.time != 'TBD' ? _formatTime(event.time) : 'TBD',
                      style: GoogleFonts.beVietnamPro(fontSize: 9, color: UpriseColors.darkGray),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      event.title.length > 14 ? '${event.title.substring(0, 14)}...' : event.title,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 10,
                        color: _statusColor(event.status),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+${sortedEvents.length - 3} more',
                style: GoogleFonts.beVietnamPro(fontSize: 9, color: UpriseColors.darkGray),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:${minute.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return time;
    }
  }

  // Placeholder: implement actual event creation form if needed.
  Future<void> _showAddEventDialog() async {
    // TODO: Implement a proper add event dialog.
    // When you do, add:
    // await ActivityLogger.log(
    //   action: 'Created event: $eventTitle',
    //   module: 'Event Calendar',
    //   severity: 'info',
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Event feature – implement a form dialog similar to Event Proposals')),
    );
  }

  Future<void> _exportEventsToCSV() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('events').get();
      final lines = <String>['Title,Organization,Date,Time,Type,Status'];
      for (var doc in snap.docs) {
        final d = doc.data();
        final date = (d['date'] as Timestamp).toDate();
        lines.add([
          d['title'] ?? '',
          d['orgName'] ?? '',
          DateFormat('yyyy-MM-dd').format(date),
          d['time'] ?? '',
          d['type'] ?? '',
          d['status'] ?? '',
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/events_export.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Events Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error),
      );
    }
  }
}

class Event {
  final String id;
  final String title;
  final DateTime date;
  final String time;
  final String type;
  final String organization;
  final String status;

  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.type,
    required this.organization,
    required this.status,
  });
}
