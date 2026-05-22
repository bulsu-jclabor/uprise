import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/web/org/org_event_proposals.dart' show OrgColors; // reuse colors

class ApprovedEventsCalendar extends StatefulWidget {
  final String? orgId; // null => show all approved events
  const ApprovedEventsCalendar({Key? key, this.orgId}) : super(key: key);

  @override
  State<ApprovedEventsCalendar> createState() => _ApprovedEventsCalendarState();
}

class _ApprovedEventsCalendarState extends State<ApprovedEventsCalendar> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Stream<QuerySnapshot> get _approvedStream {
    final col = FirebaseFirestore.instance.collection('event_proposals');
    if (widget.orgId != null) {
      return col.where('orgId', isEqualTo: widget.orgId).where('status', isEqualTo: 'approved').snapshots();
    }
    return col.where('status', isEqualTo: 'approved').snapshots();
  }

  Map<String, Color> categoryColors = {
    'Academic': Colors.indigo,
    'Technical': Colors.teal,
    'Cultural': Colors.orange,
    'Sports': Colors.green,
  };

  void _prevMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));
  }

  void _nextMonth() {
    setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startWeekday = firstOfMonth.weekday; // 1=Mon .. 7=Sun
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);

    final gridDays = <DateTime>[];
    final leading = startWeekday - 1; // make Monday start
    for (int i = 0; i < leading; i++) {
      gridDays.add(firstOfMonth.subtract(Duration(days: leading - i)));
    }
    for (int i = 0; i < daysInMonth; i++) gridDays.add(DateTime(_focusedMonth.year, _focusedMonth.month, i + 1));
    while (gridDays.length % 7 != 0) gridDays.add(gridDays.last.add(const Duration(days: 1)));

    return StreamBuilder<QuerySnapshot>(
      stream: _approvedStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        // map date string yyyy-mm-dd -> list
        final Map<String, List<QueryDocumentSnapshot>> eventsByDay = {};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final dateField = data['date'];
          DateTime? dt;
          if (dateField is Timestamp) dt = dateField.toDate();
          else if (dateField is DateTime) dt = dateField;
          if (dt == null) continue;
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          eventsByDay.putIfAbsent(key, () => []).add(d);
        }

        return Column(children: [
          Row(children: [
            IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(
                  '${_monthName(_focusedMonth.month)} ${_focusedMonth.year}',
                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 8),
          Row(children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) => Expanded(child: Center(child: Text(d, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700))))).toList()),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.3),
              itemCount: gridDays.length,
              itemBuilder: (context, idx) {
                final day = gridDays[idx];
                final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                final dayEvents = eventsByDay[key] ?? [];
                final isCurrentMonth = day.month == _focusedMonth.month;
                final isToday = DateUtils.isSameDay(day, DateTime.now());

                return Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isToday ? OrgColors.lightGray : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isCurrentMonth ? OrgColors.primaryLight : Colors.transparent),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${day.day}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrentMonth ? OrgColors.charcoal : OrgColors.darkGray)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: dayEvents.take(4).map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['title'] ?? 'Event';
                          final category = data['category'] ?? '';
                          final color = categoryColors[category] ?? Colors.blueGrey;
                          return GestureDetector(
                            onTap: () => _showEventDetails(context, data),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(title, style: GoogleFonts.beVietnamPro(fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
                            ),
                          );
                        }).toList()),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  String _monthName(int m) {
    const names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return names[m-1];
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? 'Event'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Category: ${data['category'] ?? '—'}'),
          const SizedBox(height: 6),
          Text('Date: ${data['date'] is Timestamp ? (data['date'] as Timestamp).toDate().toLocal().toString().split(' ').first : data['date']?.toString() ?? '—'}'),
          const SizedBox(height: 6),
          Text('Time: ${data['time'] ?? '—'}'),
          const SizedBox(height: 6),
          Text('Location: ${data['location'] ?? '—'}'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}
