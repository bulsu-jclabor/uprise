// lib/screens/student/student_events_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────
//  CUSTOM COLORS - UNIFORM (ORANGE)
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
}

// ─────────────────────────────────────────────────────────────
//  CUSTOM EVENT IMAGE WIDGET (WITH BASE64 SUPPORT)
// ─────────────────────────────────────────────────────────────
class EventImage extends StatelessWidget {
  final String imageUrl;
  final double? height;
  final double? width;
  final BoxFit fit;
  final bool showLoadingIndicator;

  const EventImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildFallbackImage();
    }

    // Check if it's a base64 image
    if (_isBase64Image(imageUrl)) {
      return _buildBase64Image();
    }

    // Check if it's a valid network URL
    if (_isValidImageUrl(imageUrl)) {
      return _buildNetworkImage();
    }

    return _buildFallbackImage();
  }

  bool _isBase64Image(String url) {
    return url.startsWith('data:image') || 
           (url.isNotEmpty && !url.startsWith('http') && !url.startsWith('assets'));
  }

  bool _isValidImageUrl(String url) {
    return url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('assets/');
  }

  Widget _buildBase64Image() {
    try {
      String base64String = imageUrl;
      if (imageUrl.contains(',')) {
        base64String = imageUrl.split(',').last;
      }
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallbackImage(),
      );
    } catch (_) {
      return _buildFallbackImage();
    }
  }

  Widget _buildNetworkImage() {
    return Image.network(
      imageUrl,
      height: height,
      width: width,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        if (!showLoadingIndicator) return child;
        return Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _buildFallbackImage(),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: height,
      width: width,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: (height ?? 100) * 0.4,
            color: Colors.grey[600],
          ),
          if ((height ?? 0) > 80)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Image not available',
                style: TextStyle(
                  fontSize: (height ?? 100) * 0.08,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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

    String bannerUrl = d['bannerUrl'] as String? ?? '';
    String logoUrl = d['logoUrl'] as String? ?? '';

    return EventData(
      id: doc.id,
      title: d['title'] ?? '',
      subtitle: d['subtitle'] ?? '',
      organizer: d['orgName'] ?? '',
      organizerSub: 'ORGANIZATION',
      logoUrl: logoUrl,
      bannerUrl: bannerUrl,
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
  final int initialTabIndex;

  const StudentEventsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  Future<List<Map<String, dynamic>>>? _attendedEventsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _attendedEventsFuture = _loadAttendedEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                backgroundColor: AppColors.primaryDark,
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
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
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
                          color: star <= selectedRating ? AppColors.primaryDark : Colors.grey.shade400,
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
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: submitting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Events',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryDark,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: Colors.black45,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Feedback'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarAndEventsTab(),
          _buildEventTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  Widget _buildCalendarAndEventsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.primaryDark),
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
                icon: const Icon(Icons.chevron_right, color: AppColors.primaryDark),
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Events for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                style: TextStyle(
                  fontSize: 16,
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
                        '${todayEvents.length} events',
                        style: TextStyle(
                          fontSize: 13,
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
        const SizedBox(height: 8),
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
                            color: AppColors.primaryDark));
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
                        padding: const EdgeInsets.only(bottom: 12),
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
                  child: CircularProgressIndicator(color: AppColors.primaryDark));
            }

            final allEvents = snapshot.data!.docs
                .map((doc) => EventData.fromFirestore(doc,
                    isRegistered: registeredIds.contains(doc.id)))
                .where((e) => !e.isPast)
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

  Widget _buildFeedbackTab() {
    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: () async => _refreshFeedbackTab(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _attendedEventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
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
                            backgroundColor: AppColors.primaryDark,
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

    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }

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
                  ? AppColors.primaryDark
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
                          ? AppColors.primaryDark
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: EventImage(
                  imageUrl: event.bannerUrl,
                  height: 70,
                  width: 70,
                  fit: BoxFit.cover,
                  showLoadingIndicator: false,
                ),
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
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'View',
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventImage(
              imageUrl: event.bannerUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(category: event.category),
                      const Spacer(),
                      if (event.isRegistered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Registered',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      Expanded(
                        child: Text(
                          event.time,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                            : AppColors.primaryDark,
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
        return AppColors.primaryDark;
      case 'workshop':
        return const Color(0xFF1565C0);
      case 'seminar':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey.shade700;
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
//  EVENT DETAIL SCREEN (WITH REGISTRATION FORM)
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
  bool _showRegistrationForm = false;

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final data = userDoc.docs.first.data();
        _fullNameCtrl.text = data['fullName'] ?? '';
        _studentIdCtrl.text = data['studentId'] ?? '';
        _emailCtrl.text = data['email'] ?? user.email ?? '';
        _contactCtrl.text = data['mobile'] ?? '';
      } else {
        _emailCtrl.text = user.email ?? '';
      }
    } catch (_) {}
  }

  Future<void> _registerForEvent() async {
    if (widget.isPastEvent) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to register')),
      );
      return;
    }

    final existingReg = await FirebaseFirestore.instance
        .collection('registrations')
        .where('userId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: widget.event.id)
        .get();

    if (existingReg.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already registered!')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final registrationRef = FirebaseFirestore.instance
          .collection('registrations')
          .doc('${user.uid}_${widget.event.id}');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final regDoc = await transaction.get(registrationRef);
        if (regDoc.exists) {
          throw Exception('Already registered');
        }

        final eventRef = FirebaseFirestore.instance
            .collection('events')
            .doc(widget.event.id);
        final eventDoc = await transaction.get(eventRef);

        if (!eventDoc.exists) {
          throw Exception('Event not found');
        }

        final eventData = eventDoc.data()!;
        final currentSlotsLeft = (eventData['slotsLeft'] ?? 0) as int;

        if (currentSlotsLeft <= 0) {
          throw Exception('No slots available');
        }

        transaction.update(eventRef, {
          'slotsLeft': currentSlotsLeft - 1,
        });

        transaction.set(registrationRef, {
          'userId': user.uid,
          'eventId': widget.event.id,
          'fullName': _fullNameCtrl.text.trim(),
          'studentId': _studentIdCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'contact': _contactCtrl.text.trim(),
          'registeredAt': FieldValue.serverTimestamp(),
        });
      });

      widget.onRegistered();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully registered for event!'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
        setState(() => _showRegistrationForm = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
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
        centerTitle: true,
        actions: [
          if (!widget.isPastEvent && !widget.event.isRegistered)
            TextButton.icon(
              onPressed: () {
                setState(() => _showRegistrationForm = !_showRegistrationForm);
              },
              icon: Icon(
                _showRegistrationForm ? Icons.close : Icons.edit_note,
                color: AppColors.primaryDark,
              ),
              label: Text(
                _showRegistrationForm ? 'Close' : 'Register',
                style: TextStyle(color: AppColors.primaryDark),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventImage(
              imageUrl: widget.event.bannerUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
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

                  // ── REGISTRATION FORM ──
                  if (_showRegistrationForm && !widget.isPastEvent && !widget.event.isRegistered)
                    _buildRegistrationForm(),

                  // ── STATUS BUTTONS ──
                  if (!_showRegistrationForm) ...[
                    if (!widget.isPastEvent && !widget.event.isRegistered)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _showRegistrationForm = true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EVENT REGISTRATION',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Full Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameCtrl,
              decoration: InputDecoration(
                hintText: 'Full Name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Full Name is required' : null,
            ),
            const SizedBox(height: 14),

            const Text(
              'Student Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _studentIdCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. 2023-12345',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Student Number is required' : null,
            ),
            const SizedBox(height: 14),

            const Text(
              'Email Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'john.doe@cict.edu.ph',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) return 'Email is required';
                if (!value!.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            const Text(
              'Contact Number',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '09xx xxx xxxx',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) return 'Contact number is required';
                if (value!.length < 11) return 'Enter a valid contact number';
                return null;
              },
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file, color: AppColors.primaryDark),
                      const SizedBox(width: 8),
                      const Text(
                        'Upload ID (School or Government)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Click to upload or drag and drop',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        const Text(
                          'PNG, JPG or PDF (MAX. 5MB)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerForEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
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
                        'Complete Registration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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