import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────
class EventData {
  final String id;
  final String title;
  final String subtitle;
  final String organizer;
  final String organizerSub;
  final String logoUrl;
  final String bannerUrl;
  final String date;
  final String time;
  final String location;
  final String description;
  final String category;
  final bool isRegistered;
  final int slots;
  final int slotsLeft;
  final bool isPublic;
  final bool isPast;
  final DateTime rawDate;

  const EventData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.organizer,
    required this.organizerSub,
    required this.logoUrl,
    required this.bannerUrl,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
    required this.category,
    this.isRegistered = false,
    required this.slots,
    required this.slotsLeft,
    this.isPublic = true,
    required this.isPast,
    required this.rawDate,
  });

  factory EventData.fromFirestore(DocumentSnapshot doc,
      {bool isRegistered = false}) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = d['date'];
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now();

    final now = DateTime.now();
    final isPast = dateTime.isBefore(now);

    return EventData(
      id: doc.id,
      title: d['title'] ?? '',
      subtitle: d['subtitle'] ?? '',
      organizer: d['orgName'] ?? '',
      organizerSub: 'ORGANIZATION',
      logoUrl: d['logoUrl'] ?? '',
      bannerUrl: d['bannerUrl'] ?? '',
      date: DateFormat('MMM dd, yyyy').format(dateTime),
      time: '${d['startTime'] ?? ''} – ${d['endTime'] ?? ''}',
      location: d['location'] ?? '',
      description: d['description'] ?? '',
      category: d['category'] ?? 'Other',
      isRegistered: isRegistered,
      slots: d['capacity'] ?? 0,
      slotsLeft: d['slotsLeft'] ?? d['capacity'] ?? 0,
      isPublic: d['isPublic'] ?? true,
      isPast: isPast,
      rawDate: dateTime,
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN (CALENDAR + EVENTS)
// ─────────────────────────────────────────────
class StudentEventsScreen extends StatefulWidget {
  const StudentEventsScreen({super.key});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Remove the unused field or use it - we'll keep it for potential future use
  // int _selectedTabIndex = 0; // REMOVED - not needed when using TabBar

  DateTime _selectedDate = DateTime.now();
  Future<List<Map<String, dynamic>>>? _attendedEventsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _attendedEventsFuture = _loadAttendedEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Calendar navigation
  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  void _openDetail(EventData event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          onRegistered: () => setState(() {}),
          isPastEvent: event.isPast,
        ),
      ),
    );
  }

  // Events the student attended (present/late), with whether they've already
  // submitted their evaluation for it. Evaluation is required for every
  // attended event, regardless of whether the org issues a certificate for it.
  Future<List<Map<String, dynamic>>> _loadAttendedEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final attSnap = await FirebaseFirestore.instance
        .collectionGroup('attendances')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final feedbackSnap = await FirebaseFirestore.instance
        .collection('event_feedback')
        .where('userId', isEqualTo: user.uid)
        .get();
    final ratedEventIds = feedbackSnap.docs
        .map((d) => d.data()['eventId']?.toString())
        .whereType<String>()
        .toSet();

    final results = <Map<String, dynamic>>[];
    for (final doc in attSnap.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status != 'present' && status != 'late') continue;
      final eventRef = doc.reference.parent.parent;
      if (eventRef == null) continue;
      final eventDoc = await eventRef.get();
      if (!eventDoc.exists) continue;
      final ed = eventDoc.data() as Map<String, dynamic>;
      results.add({
        'eventId': eventRef.id,
        'eventName': ed['title'] ?? 'Event',
        'organization': ed['orgName'] ?? '',
        'orgId': ed['orgId'] ?? '',
        'rated': ratedEventIds.contains(eventRef.id),
      });
    }
    results.sort((a, b) => (a['rated'] as bool ? 1 : 0).compareTo(b['rated'] as bool ? 1 : 0));
    return results;
  }

  void _refreshFeedbackTab() {
    setState(() => _attendedEventsFuture = _loadAttendedEvents());
  }

  Future<void> _showEventFeedbackDialog(Map<String, dynamic> ev) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            if (selectedRating == 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a star rating.'),
                backgroundColor: Color(0xFFE53935),
              ));
              return;
            }
            setSheet(() => submitting = true);
            try {
              await FirebaseFirestore.instance.collection('event_feedback').add({
                'eventId': ev['eventId'],
                'eventName': ev['eventName'],
                'organization': ev['organization'],
                'orgId': ev['orgId'],
                'rating': selectedRating,
                'comment': commentCtrl.text.trim(),
                'userId': user.uid,
                'submittedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                _refreshFeedbackTab();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Evaluation submitted. Thank you!'),
                  backgroundColor: Colors.green,
                ));
              }
            } catch (e) {
              setSheet(() => submitting = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to submit: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Evaluate Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(ev['eventName'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setSheet(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: star <= selectedRating ? const Color(0xFFE53935) : Colors.grey.shade400,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts about this event (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Evaluation', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Fetch registered event IDs of current user
  Future<Set<String>> _getRegisteredEventIds() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final snap = await FirebaseFirestore.instance
        .collection('registrations')
        .where('userId', isEqualTo: user.uid)
        .get();
    return snap.docs.map((d) => d['eventId'] as String).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calendar',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFE53935),
          labelColor: const Color(0xFFE53935),
          unselectedLabelColor: Colors.black45,
          tabs: const [
            Tab(text: 'All CICT Events'),
            Tab(text: 'Event'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: All CICT Events (Calendar + Events)
          _buildCalendarAndEventsTab(),
          
          // Tab 1: Event Tab (Upcoming Events List)
          _buildEventTab(),
          
          // Tab 2: Feedback Tab
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  // TAB 0: All CICT Events (Calendar + Events for selected date)
  Widget _buildCalendarAndEventsTab() {
    return Column(
      children: [
        // Calendar Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        // Calendar Grid
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _CalendarGrid(
            selectedDate: _selectedDate,
            onDateSelected: (date) {
              setState(() {
                _selectedDate = date;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        // Events for Today Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Events for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              FutureBuilder<Set<String>>(
                future: _getRegisteredEventIds(),
                builder: (context, regSnap) {
                  final registeredIds = regSnap.data ?? {};
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .orderBy('date')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }
                      final todayEvents = snapshot.data!.docs
                          .map((doc) => EventData.fromFirestore(
                              doc, isRegistered: registeredIds.contains(doc.id)))
                          .where((e) =>
                              e.rawDate.year == _selectedDate.year &&
                              e.rawDate.month == _selectedDate.month &&
                              e.rawDate.day == _selectedDate.day)
                          .toList();
                      return Text(
                        '${todayEvents.length} Events',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Events List
        Expanded(
          child: FutureBuilder<Set<String>>(
            future: _getRegisteredEventIds(),
            builder: (context, regSnap) {
              final registeredIds = regSnap.data ?? {};
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('date')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFE53935)));
                  }
                  final todayEvents = snapshot.data!.docs
                      .map((doc) => EventData.fromFirestore(doc,
                          isRegistered: registeredIds.contains(doc.id)))
                      .where((e) =>
                          e.rawDate.year == _selectedDate.year &&
                          e.rawDate.month == _selectedDate.month &&
                          e.rawDate.day == _selectedDate.day)
                      .toList();

                  if (todayEvents.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No events for this day',
                            style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: todayEvents.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _CompactEventCard(
                          event: todayEvents[index],
                          onTap: () => _openDetail(todayEvents[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // TAB 1: Event Tab (Upcoming Events List)
  Widget _buildEventTab() {
    return FutureBuilder<Set<String>>(
      future: _getRegisteredEventIds(),
      builder: (context, regSnap) {
        final registeredIds = regSnap.data ?? {};
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .orderBy('date')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE53935)));
            }
            
            final allEvents = snapshot.data!.docs
                .map((doc) => EventData.fromFirestore(doc,
                    isRegistered: registeredIds.contains(doc.id)))
                .where((e) => !e.isPast) // Only show upcoming events
                .toList();

            if (allEvents.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_available, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No upcoming events',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allEvents.length,
              itemBuilder: (context, index) {
                final event = allEvents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UpcomingEventCard(
                    event: event,
                    onTap: () => _openDetail(event),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // TAB 2: Feedback Tab — events the student attended, awaiting evaluation
  Widget _buildFeedbackTab() {
    return RefreshIndicator(
      color: const Color(0xFFE53935),
      onRefresh: () async => _refreshFeedbackTab(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _attendedEventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.feedback_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Center(
                  child: Text('No events to evaluate yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
                SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Once you attend an event, it will show up here for you to evaluate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final ev = events[i];
              final rated = ev['rated'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ev['eventName'] ?? 'Event',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                      if ((ev['organization'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(ev['organization'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 12),
                  rated
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Submitted',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                        )
                      : ElevatedButton(
                          onPressed: () => _showEventFeedbackDialog(ev),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Evaluate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CALENDAR GRID
// ─────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarGrid({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;

    List<Widget> dayWidgets = [];
    
    // Add weekday headers
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    for (var day in weekdays) {
      dayWidgets.add(Center(
        child: Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ));
    }
    
    // Add empty spaces for days before the first day of month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

    // Add days of the month
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(selectedDate.year, selectedDate.month, day);
      final isSelected = currentDate.year == selectedDate.year &&
          currentDate.month == selectedDate.month &&
          currentDate.day == selectedDate.day;
      final isToday = currentDate.year == DateTime.now().year &&
          currentDate.month == DateTime.now().month &&
          currentDate.day == DateTime.now().day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => onDateSelected(currentDate),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? const Color(0xFFE53935)
                  : isToday
                      ? Colors.grey.shade200
                      : Colors.transparent,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? const Color(0xFFE53935)
                          : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      children: dayWidgets,
    );
  }
}

// ─────────────────────────────────────────────
//  COMPACT EVENT CARD (for Calendar Tab)
// ─────────────────────────────────────────────
class _CompactEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;

  const _CompactEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), // Fixed: replaced withOpacity
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.1), // Fixed: replaced withOpacity
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(event.rawDate),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE53935),
                    ),
                  ),
                  Text(
                    DateFormat('dd').format(event.rawDate),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          event.time,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  UPCOMING EVENT CARD (for Event Tab)
// ─────────────────────────────────────────────
class _UpcomingEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;

  const _UpcomingEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), // Fixed: replaced withOpacity
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  event.bannerUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _CategoryBadge(category: event.category),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        event.date,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        event.time,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: event.isRegistered
                            ? Colors.green
                            : const Color(0xFFE53935),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        event.isRegistered ? 'Registered ✓' : 'View Details',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CATEGORY BADGE
// ─────────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  Color get _color {
    switch (category.toLowerCase()) {
      case 'competition':
        return const Color(0xFFFF6F00);
      case 'workshop':
        return const Color(0xFF1565C0);
      case 'seminar':
        return const Color(0xFF6A1B9A);
      default:
        return const Color(0xFF37474F);
    }
  }

  String get _label => category.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  EVENT DETAIL SCREEN
// ─────────────────────────────────────────────
class EventDetailScreen extends StatefulWidget {
  final EventData event;
  final VoidCallback onRegistered;
  final bool isPastEvent;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.onRegistered,
    required this.isPastEvent,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = false;

  Future<void> _registerForEvent() async {
    if (widget.isPastEvent) return;
    if (widget.event.slotsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event is full!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to register')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final registrationRef = FirebaseFirestore.instance
          .collection('registrations')
          .doc('${user.uid}_${widget.event.id}');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final registrationDoc = await transaction.get(registrationRef);
        if (registrationDoc.exists) {
          throw Exception('Already registered');
        }

        final eventRef =
            FirebaseFirestore.instance.collection('events').doc(widget.event.id);
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final currentSlotsLeft = eventDoc.data()?['slotsLeft'] ?? 0;
        if (currentSlotsLeft <= 0) {
          throw Exception('No slots available');
        }

        transaction.update(eventRef, {'slotsLeft': currentSlotsLeft - 1});
        transaction.set(registrationRef, {
          'userId': user.uid,
          'eventId': widget.event.id,
          'registeredAt': FieldValue.serverTimestamp(),
        });
      });

      widget.onRegistered();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Successfully registered for event!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(color: Colors.black87),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              widget.event.bannerUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 60, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(category: widget.event.category),
                  const SizedBox(height: 12),
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.event.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: widget.event.date,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    text: widget.event.time,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: widget.event.location,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: '${widget.event.slotsLeft} / ${widget.event.slots} slots remaining',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (!widget.isPastEvent && !widget.event.isRegistered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerForEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Register Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  if (widget.event.isRegistered && !widget.isPastEvent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          '✓ You are registered',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  if (widget.isPastEvent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Past Event',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}