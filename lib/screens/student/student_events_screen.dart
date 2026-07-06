// lib/screens/student/student_events_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:uprise/models/event_model.dart';
import '../../widgets/student/event_image.dart';
import '../../widgets/student/app_colors.dart';
import 'student_feedback_screen.dart';
import 'student_certificates_screen.dart';
import 'package:image_picker/image_picker.dart';

// ─── MAIN SCREEN ──────────────────────────────────────────────
class StudentEventsScreen extends StatefulWidget {
  final int initialTabIndex;
  const StudentEventsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Stream of registered event IDs (shared across tabs)
  late final Stream<Set<String>> _registeredEventIdsStream = () {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream<Set<String>>.value(<String>{});
    return FirebaseFirestore.instance
        .collection('registrations')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d['eventId'] as String).toSet());
  }();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCertificates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const StudentCertificatesScreen(),
      ),
    );
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openCertificates,
            icon: Icon(
              Icons.workspace_premium,
              color: AppColors.primaryDark,
              size: 28,
            ),
            tooltip: 'Certificates',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryDark,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: Colors.black45,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Registered'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CalendarTab(registeredEventIdsStream: _registeredEventIdsStream),
          UpcomingTab(registeredEventIdsStream: _registeredEventIdsStream),
          RegisteredEventsTab(registeredEventIdsStream: _registeredEventIdsStream),
          ArchivedEventsTab(registeredEventIdsStream: _registeredEventIdsStream),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 1: CALENDAR
// ═══════════════════════════════════════════════════════════════
class CalendarTab extends StatefulWidget {
  final Stream<Set<String>> registeredEventIdsStream;
  const CalendarTab({required this.registeredEventIdsStream, super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();

  void _previousMonth() => setState(() {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
      });
  void _nextMonth() => setState(() {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
      });

  void _openDetail(EventModel event) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            onDateSelected: (date) => setState(() => _selectedDate = date),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Events for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              const Spacer(),
              StreamBuilder<Set<String>>(
                stream: widget.registeredEventIdsStream,
                builder: (context, regSnap) {
                  final regIds = regSnap.data ?? {};
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
                        .where('status', isEqualTo: 'approved')
                        .orderBy('date')
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final count = snap.data!.docs
                          .map((d) => EventModel.fromFirestore(d))
                          .where((e) =>
                              e.date.year == _selectedDate.year &&
                              e.date.month == _selectedDate.month &&
                              e.date.day == _selectedDate.day)
                          .length;
                      return Text(
                        '$count events',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
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
          child: StreamBuilder<Set<String>>(
            stream: widget.registeredEventIdsStream,
            builder: (context, regSnap) {
              final regIds = regSnap.data ?? {};
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .where('status', isEqualTo: 'approved')
                    .orderBy('date')
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryDark),
                    );
                  }
                  final todayEvents = snap.data!.docs
                      .map((d) => EventModel.fromFirestore(d))
                      .where((e) =>
                          e.date.year == _selectedDate.year &&
                          e.date.month == _selectedDate.month &&
                          e.date.day == _selectedDate.day)
                      .toList();

                  if (todayEvents.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No events for this day',
                            style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: todayEvents.length,
                    itemBuilder: (context, index) {
                      final event = todayEvents[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CompactEventCard(
                          event: event,
                          onTap: () => _openDetail(event),
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
}

// ═══════════════════════════════════════════════════════════════
//  TAB 2: UPCOMING
// ═══════════════════════════════════════════════════════════════
class UpcomingTab extends StatefulWidget {
  final Stream<Set<String>> registeredEventIdsStream;
  const UpcomingTab({required this.registeredEventIdsStream, super.key});

  @override
  State<UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<UpcomingTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _openDetail(EventModel event) {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<Set<String>>(
      stream: widget.registeredEventIdsStream,
      builder: (context, regSnap) {
        final regIds = regSnap.data ?? {};
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
              .where('status', isEqualTo: 'approved')
              .orderBy('date')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryDark),
              );
            }

            final allEvents = snap.data!.docs
                .map((d) => EventModel.fromFirestore(d))
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
                      style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
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
                final isRegistered = regIds.contains(event.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UpcomingEventCard(
                    event: event,
                    isRegistered: isRegistered,
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
}

// ═══════════════════════════════════════════════════════════════
//  TAB 3: REGISTERED EVENTS (with Archive - icon only)
// ═══════════════════════════════════════════════════════════════
class RegisteredEventsTab extends StatefulWidget {
  final Stream<Set<String>> registeredEventIdsStream;
  const RegisteredEventsTab({required this.registeredEventIdsStream, super.key});

  @override
  State<RegisteredEventsTab> createState() => _RegisteredEventsTabState();
}

enum _RegStatus { upcoming, ongoing, completed }

class _RegisteredEventsTabState extends State<RegisteredEventsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Stream<QuerySnapshot>? _registrationsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _registrationsStream = FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .snapshots();
    }
  }

  DateTime? _combineDateAndTime(DateTime date, String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final cleaned = timeStr.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(cleaned);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  _RegStatus _statusFor(EventModel event) {
    final now = DateTime.now();
    final dynamic raw = event;
    String? startTimeStr;
    String? endTimeStr;
    try {
      startTimeStr = raw.startTime as String?;
    } catch (_) {}
    try {
      endTimeStr = raw.endTime as String?;
    } catch (_) {}

    final start = _combineDateAndTime(event.date, startTimeStr) ?? event.date;
    final end = _combineDateAndTime(event.date, endTimeStr) ??
        DateTime(event.date.year, event.date.month, event.date.day, 23, 59);

    if (now.isBefore(start)) return _RegStatus.upcoming;
    if (now.isAfter(end)) return _RegStatus.completed;
    return _RegStatus.ongoing;
  }

  ({String label, Color color}) _statusStyle(_RegStatus status) {
    switch (status) {
      case _RegStatus.upcoming:
        return (label: 'UPCOMING', color: const Color(0xFF2563EB));
      case _RegStatus.ongoing:
        return (label: 'ONGOING', color: const Color(0xFF059669));
      case _RegStatus.completed:
        return (label: 'COMPLETED', color: Colors.grey.shade600);
    }
  }

  void _openDetail(EventModel event, bool isPast) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          onRegistered: () => setState(() {}),
          isPastEvent: isPast,
        ),
      ),
    );
  }

  Future<void> _archiveEvent(EventModel event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Event'),
        content: Text(
          'Are you sure you want to archive "${event.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docId = '${user.uid}_${event.id}';
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(docId)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${event.title}" archived'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_registrationsStream == null) {
      return const Center(
        child: Text('Please log in to see your registered events.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _registrationsStream,
      builder: (context, regSnap) {
        if (regSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
        }
        if (regSnap.hasError) {
          return Center(
            child: Text('Failed to load registrations',
                style: TextStyle(color: Colors.grey.shade600)),
          );
        }

        final eventIds = (regSnap.data?.docs ?? [])
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isArchived'] != true;
            })
            .map((d) => (d.data() as Map<String, dynamic>)['eventId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        if (eventIds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No registered events',
                  style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Register for an event to see it here',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final chunks = <List<String>>[];
        for (var i = 0; i < eventIds.length; i += 30) {
          chunks.add(eventIds.sublist(i, i + 30 > eventIds.length ? eventIds.length : i + 30));
        }

        return FutureBuilder<List<QuerySnapshot>>(
          future: Future.wait(chunks.map((chunk) => FirebaseFirestore.instance
              .collection('events')
              .where(FieldPath.documentId, whereIn: chunk)
              .get())),
          builder: (context, evSnap) {
            if (evSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
            }
            if (evSnap.hasError || !evSnap.hasData) {
              return Center(
                child: Text('Failed to load events',
                    style: TextStyle(color: Colors.grey.shade600)),
              );
            }

            final events = evSnap.data!
                .expand((snap) => snap.docs)
                .map((d) => EventModel.fromFirestore(d))
                .toList();

            events.sort((a, b) {
              final sa = _statusFor(a);
              final sb = _statusFor(b);
              if (sa != sb) {
                const order = {
                  _RegStatus.ongoing: 0,
                  _RegStatus.upcoming: 1,
                  _RegStatus.completed: 2,
                };
                return order[sa]!.compareTo(order[sb]!);
              }
              return sa == _RegStatus.completed
                  ? b.date.compareTo(a.date)
                  : a.date.compareTo(b.date);
            });

            if (events.isEmpty) {
              return const Center(
                child: Text('No registered events found',
                    style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final status = _statusFor(event);
                final style = _statusStyle(status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          EventImage(
                            imageUrl: event.imageUrl,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            showLoadingIndicator: true,
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: style.color,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                style.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.orgName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  event.formattedDate,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(width: 14),
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.formattedTime,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // ── Buttons Row (View Details + Archive Icon) ──
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _openDetail(event, status == _RegStatus.completed),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryDark,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Archive Button (icon only)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _archiveEvent(event),
                                    icon: Icon(
                                      Icons.archive_rounded,
                                      size: 22,
                                      color: Colors.grey.shade700,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Archive',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  TAB 4: ARCHIVED EVENTS (with Restore - icon only)
// ═══════════════════════════════════════════════════════════════
class ArchivedEventsTab extends StatefulWidget {
  final Stream<Set<String>> registeredEventIdsStream;
  const ArchivedEventsTab({required this.registeredEventIdsStream, super.key});

  @override
  State<ArchivedEventsTab> createState() => _ArchivedEventsTabState();
}

class _ArchivedEventsTabState extends State<ArchivedEventsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Stream<QuerySnapshot>? _registrationsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _registrationsStream = FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .where('isArchived', isEqualTo: true)
          .snapshots();
    }
  }

  void _openDetail(EventModel event) {
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

  Future<void> _unarchiveEvent(String eventId, String title) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Event'),
        content: Text('Restore "$title" to your registered events?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final docId = '${user.uid}_$eventId';
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(docId)
          .update({
        'isArchived': false,
        'archivedAt': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_registrationsStream == null) {
      return const Center(
        child: Text('Please log in to see your archived events.',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _registrationsStream,
      builder: (context, regSnap) {
        if (regSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
        }
        if (regSnap.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to load archived events',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please create the required index or try again.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }

        final eventIds = (regSnap.data?.docs ?? [])
            .map((d) => (d.data() as Map<String, dynamic>)['eventId'] as String?)
            .whereType<String>()
            .toSet()
            .toList();

        if (eventIds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'No archived events',
                  style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8),
                Text(
                  'Archived events will appear here',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final chunks = <List<String>>[];
        for (var i = 0; i < eventIds.length; i += 30) {
          chunks.add(eventIds.sublist(i, i + 30 > eventIds.length ? eventIds.length : i + 30));
        }

        return FutureBuilder<List<QuerySnapshot>>(
          future: Future.wait(chunks.map((chunk) => FirebaseFirestore.instance
              .collection('events')
              .where(FieldPath.documentId, whereIn: chunk)
              .get())),
          builder: (context, evSnap) {
            if (evSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
            }
            if (evSnap.hasError || !evSnap.hasData) {
              return Center(
                child: Text('Failed to load events',
                    style: TextStyle(color: Colors.grey.shade600)),
              );
            }

            final eventsWithDates = <Map<String, dynamic>>[];
            
            for (final doc in regSnap.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final eventId = data['eventId'] as String;
              final archivedAt = data['archivedAt'] as Timestamp?;
              
              final eventDoc = evSnap.data!
                  .expand((snap) => snap.docs)
                  .where((d) => d.id == eventId)
                  .firstOrNull;
                  
              if (eventDoc != null) {
                final event = EventModel.fromFirestore(eventDoc);
                eventsWithDates.add({
                  'event': event,
                  'archivedAt': archivedAt,
                });
              }
            }

            eventsWithDates.sort((a, b) {
              final aDate = a['archivedAt'] as Timestamp?;
              final bDate = b['archivedAt'] as Timestamp?;
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

            if (eventsWithDates.isEmpty) {
              return const Center(
                child: Text('No archived events found',
                    style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: eventsWithDates.length,
              itemBuilder: (context, index) {
                final item = eventsWithDates[index];
                final event = item['event'] as EventModel;
                final archivedAt = item['archivedAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          EventImage(
                            imageUrl: event.imageUrl,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            showLoadingIndicator: true,
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade800.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ARCHIVED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.orgName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  event.formattedDate,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(width: 14),
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.formattedTime,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event.location,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (archivedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Archived: ${DateFormat('MMM dd, yyyy h:mm a').format(archivedAt.toDate())}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // ── Buttons Row (View Details + Restore Icon) ──
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _openDetail(event),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade400,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'View Details',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Restore Button (icon only)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _unarchiveEvent(event.id, event.title),
                                    icon: Icon(
                                      Icons.restore_from_trash_rounded,
                                      size: 22,
                                      color: Colors.green.shade700,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Restore',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── CALENDAR GRID ─────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const _CalendarGrid({required this.selectedDate, required this.onDateSelected});

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;

    final eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: eventsStream,
      builder: (context, snap) {
        Set<String> eventDates = {};
        if (snap.hasData) {
          final events = snap.data!.docs
              .map((d) => EventModel.fromFirestore(d))
              .where((e) =>
                  e.date.year == selectedDate.year &&
                  e.date.month == selectedDate.month)
              .toList();

          eventDates = events
              .map((e) =>
                  '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}')
              .toSet();
        }

        List<Widget> dayWidgets = [];
        const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
        for (var day in weekdays) {
          dayWidgets.add(Center(
            child: Text(
              day,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
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

          final dateKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
          final hasEvent = eventDates.contains(dateKey);

          Color indicatorColor;
          if (hasEvent && isToday) {
            indicatorColor = Colors.green;
          } else if (hasEvent) {
            indicatorColor = AppColors.primaryDark;
          } else {
            indicatorColor = Colors.transparent;
          }

          dayWidgets.add(
            GestureDetector(
              onTap: () => onDateSelected(currentDate),
              child: Container(
                margin: const EdgeInsets.all(2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
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
                            fontSize: 13,
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
                    if (hasEvent)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: indicatorColor,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          );
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.1,
          children: dayWidgets,
        );
      },
    );
  }
}

// ─── COMPACT EVENT CARD ────────────────────────────────────────
class _CompactEventCard extends StatelessWidget {
  final EventModel event;
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
                  imageUrl: event.imageUrl,
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          event.formattedTime,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UPCOMING EVENT CARD ──────────────────────────────────────
class _UpcomingEventCard extends StatelessWidget {
  final EventModel event;
  final bool isRegistered;
  final VoidCallback onTap;

  const _UpcomingEventCard({
    required this.event,
    required this.isRegistered,
    required this.onTap,
  });

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
              imageUrl: event.imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              showLoadingIndicator: true,
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
                      if (isRegistered)
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        event.formattedDate,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.formattedTime,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
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
                        backgroundColor: isRegistered ? Colors.green : AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      child: Text(
                        isRegistered ? 'Registered ✓' : 'View Details',
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

// ─── CATEGORY BADGE ─────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.toUpperCase(),
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

// ─── EVENT DETAIL SCREEN ────────────────────────────────────────
class EventDetailScreen extends StatefulWidget {
  final EventModel event;
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
  bool _loadingForm = true;
  bool _isRegistered = false;
  Map<String, dynamic>? _formDef;
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, String?> _singleChoice = {};
  final Map<String, Set<String>> _multiChoice = {};

  int _rating = 0;
  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _feedbackSubmitted = false;
  bool _checkingFeedback = true;
  bool _submittingFeedback = false;

  bool get _isEventReallyOver {
    try {
      final event = widget.event;
      final dynamic raw = event;
      String? endTimeStr;
      try {
        endTimeStr = raw.endTime as String?;
      } catch (_) {
        endTimeStr = null;
      }

      if (endTimeStr == null || endTimeStr.trim().isEmpty) {
        return widget.isPastEvent;
      }

      final parsedEnd = _combineDateAndTimeString(event.date, endTimeStr);
      if (parsedEnd == null) return widget.isPastEvent;

      return DateTime.now().isAfter(parsedEnd);
    } catch (_) {
      return widget.isPastEvent;
    }
  }

  DateTime? _combineDateAndTimeString(DateTime date, String timeStr) {
    final cleaned = timeStr.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(cleaned);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final meridiem = match.group(3);

    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  @override
  void initState() {
    super.initState();
    _loadRegistrationForm();
    _checkRegistrationStatus();
    if (_isEventReallyOver) {
      _checkFeedbackStatus();
    } else {
      _checkingFeedback = false;
    }
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkRegistrationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('registrations')
        .where('userId', isEqualTo: user.uid)
        .where('eventId', isEqualTo: widget.event.id)
        .get();
    if (mounted) {
      setState(() => _isRegistered = snap.docs.isNotEmpty);
    }
  }

  Future<void> _checkFeedbackStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _checkingFeedback = false);
      return;
    }
    try {
      final docId = '${user.uid}_${widget.event.id}';
      final doc = await FirebaseFirestore.instance
          .collection('feedback')
          .doc(docId)
          .get();
      if (mounted) {
        setState(() {
          if (doc.exists) {
            final d = doc.data()!;
            _feedbackSubmitted = true;
            _rating = (d['rating'] ?? 0) as int;
            _feedbackCtrl.text = (d['comment'] ?? '').toString();
          }
          _checkingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _checkingFeedback = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not load feedback status: $e'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a star rating'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please login to submit feedback'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _submittingFeedback = true);
    try {
      final docId = '${user.uid}_${widget.event.id}';
      await FirebaseFirestore.instance.collection('feedback').doc(docId).set({
        'userId': user.uid,
        'eventId': widget.event.id,
        'eventTitle': widget.event.title,
        'rating': _rating,
        'comment': _feedbackCtrl.text.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _feedbackSubmitted = true;
          _submittingFeedback = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Thanks for your feedback!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submittingFeedback = false);
        final msg = e.toString().toLowerCase().contains('permission')
            ? 'Failed to submit: missing Firestore permission for "feedback" collection. Check your security rules.'
            : 'Failed to submit feedback: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  Widget _buildStarSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = starIndex <= _rating;
        return GestureDetector(
          onTap: _feedbackSubmitted
              ? null
              : () => setState(() => _rating = starIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              size: 36,
              color: filled ? const Color(0xFFFBBF24) : Colors.grey.shade400,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFeedbackSection() {
    if (_checkingFeedback) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _feedbackSubmitted ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _feedbackSubmitted ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _feedbackSubmitted ? Icons.check_circle_rounded : Icons.rate_review_rounded,
                color: _feedbackSubmitted ? Colors.green : AppColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _feedbackSubmitted ? 'Feedback Submitted' : 'Rate this event',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _feedbackSubmitted ? Colors.green.shade700 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStarSelector(),
          const SizedBox(height: 14),
          TextField(
            controller: _feedbackCtrl,
            readOnly: _feedbackSubmitted,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your thoughts about this event (optional)',
              hintStyle: const TextStyle(fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
              ),
            ),
          ),
          if (!_feedbackSubmitted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submittingFeedback ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _submittingFeedback
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadRegistrationForm() async {
    final proposalId = widget.event.createdFromProposalId ?? '';
    if (proposalId.isEmpty) {
      if (mounted) setState(() => _loadingForm = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('registration_forms')
          .doc(proposalId)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        final fields = (d['fields'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (d['isPublished'] == true && fields.isNotEmpty) {
          for (final f in fields) {
            final id = f['id'] as String;
            final type = (f['type'] ?? 'short_text') as String;
            if (type == 'multiple_choice' || type == 'dropdown') {
              _singleChoice[id] = null;
            } else if (type == 'checkboxes') {
              _multiChoice[id] = {};
            } else {
              _fieldControllers[id] = TextEditingController();
            }
          }
          _formDef = {...d, 'fields': fields};
        }
      }
    } catch (_) {
      // fall through
    }
    if (mounted) setState(() => _loadingForm = false);
  }

  String? _validateDynamicFields() {
    if (_formDef == null) return null;
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    for (final f in fields) {
      if (f['required'] != true) continue;
      final id = f['id'] as String;
      final type = (f['type'] ?? 'short_text') as String;
      final label = (f['label'] ?? 'This question').toString();
      if (type == 'multiple_choice' || type == 'dropdown') {
        if (_singleChoice[id] == null) return 'Please answer: $label';
      } else if (type == 'checkboxes') {
        if ((_multiChoice[id] ?? {}).isEmpty) return 'Please answer: $label';
      } else {
        if ((_fieldControllers[id]?.text ?? '').trim().isEmpty) {
          return 'Please answer: $label';
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _collectFormResponses() {
    if (_formDef == null) return {};
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    final out = <String, dynamic>{};
    for (final f in fields) {
      final id = f['id'] as String;
      final type = (f['type'] ?? 'short_text') as String;
      final label = f['label'] ?? '';
      if (type == 'multiple_choice' || type == 'dropdown') {
        out[id] = {'label': label, 'value': _singleChoice[id]};
      } else if (type == 'checkboxes') {
        out[id] = {'label': label, 'value': (_multiChoice[id] ?? {}).toList()};
      } else {
        out[id] = {'label': label, 'value': _fieldControllers[id]?.text.trim() ?? ''};
      }
    }
    return out;
  }

  Future<void> _registerForEvent() async {
    if (widget.isPastEvent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot register for past events'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final formError = _validateDynamicFields();
    if (formError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(formError),
        backgroundColor: Colors.red,
      ));
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
      final formResponses = _collectFormResponses();
      final regRef = FirebaseFirestore.instance
          .collection('registrations')
          .doc('${user.uid}_${widget.event.id}');
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final regDoc = await tx.get(regRef);
        if (regDoc.exists) throw Exception('You are already registered for this event');
        final evRef = FirebaseFirestore.instance.collection('events').doc(widget.event.id);
        final evDoc = await tx.get(evRef);
        if (!evDoc.exists) throw Exception('Event not found');
        tx.set(regRef, {
          'userId': user.uid,
          'eventId': widget.event.id,
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
          if (formResponses.isNotEmpty) 'formResponses': formResponses,
        });
      });
      setState(() => _isRegistered = true);
      widget.onRegistered();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Successfully registered for event!'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
        ),
      );

  Widget _buildDynamicField(Map<String, dynamic> field, {VoidCallback? onStateChanged}) {
    final id = field['id'] as String;
    final type = (field['type'] ?? 'short_text') as String;
    final label = (field['label'] ?? '').toString();
    final desc = (field['description'] ?? '').toString();
    final required = field['required'] == true;
    final options = (field['options'] as List?)?.map((o) => o.toString()).toList() ?? [];

    Widget input;
    switch (type) {
      case 'paragraph':
        input = TextField(
          controller: _fieldControllers[id],
          maxLines: 4,
          decoration: _fieldDecoration('Your answer'),
        );
        break;
      case 'email':
        input = TextField(
          controller: _fieldControllers[id],
          keyboardType: TextInputType.emailAddress,
          decoration: _fieldDecoration('someone@email.com'),
        );
        break;
      case 'number':
        input = TextField(
          controller: _fieldControllers[id],
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration('0'),
        );
        break;
      case 'date':
        input = TextField(
          controller: _fieldControllers[id],
          readOnly: true,
          decoration: _fieldDecoration('Select date').copyWith(
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              _fieldControllers[id]!.text = DateFormat('MMM dd, yyyy').format(picked);
              if (onStateChanged != null) onStateChanged();
            }
          },
        );
        break;
      case 'multiple_choice':
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options
              .map((o) => RadioListTile<String>(
                    value: o,
                    groupValue: _singleChoice[id],
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      _singleChoice[id] = v;
                      if (onStateChanged != null) {
                        onStateChanged();
                      } else {
                        setState(() {});
                      }
                    },
                  ))
              .toList(),
        );
        break;
      case 'dropdown':
        input = DropdownButtonFormField<String>(
          initialValue: _singleChoice[id],
          decoration: _fieldDecoration('Select an option'),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: (v) {
            _singleChoice[id] = v;
            if (onStateChanged != null) {
              onStateChanged();
            } else {
              setState(() {});
            }
          },
        );
        break;
      case 'checkboxes':
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options
              .map((o) => CheckboxListTile(
                    value: _multiChoice[id]?.contains(o) ?? false,
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      _multiChoice.putIfAbsent(id, () => {});
                      if (v == true) {
                        _multiChoice[id]!.add(o);
                      } else {
                        _multiChoice[id]!.remove(o);
                      }
                      if (onStateChanged != null) {
                        onStateChanged();
                      } else {
                        setState(() {});
                      }
                    },
                  ))
              .toList(),
        );
        break;
      default:
        input = TextField(
          controller: _fieldControllers[id],
          decoration: _fieldDecoration('Your answer'),
        );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
                ),
            ]),
          ),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                desc,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          else
            const SizedBox(height: 6),
          input,
        ],
      ),
    );
  }

  List<Widget> _buildDialogFields(VoidCallback setDialogState) {
    if (_formDef == null) return [];
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    final title = (_formDef!['title'] ?? 'Registration Form').toString();
    final desc = (_formDef!['description'] ?? '').toString();

    return [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (desc.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            desc,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
      const SizedBox(height: 16),
      ...fields.map((f) => _buildDynamicField(f, onStateChanged: setDialogState)),
    ];
  }

  void _showRegistrationDialog() {
    if (_formDef == null) {
      _registerForEvent();
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.primaryDark),
                  const SizedBox(width: 10),
                  const Text('Register for Event'),
                ],
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: 450,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildDialogFields(() => setDialogState(() {})),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final formError = _validateDynamicFields();
                          if (formError != null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(formError),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          await _registerForEvent();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Registration'),
                ),
              ],
            );
          },
        );
      },
    );
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
        title: const Text('Event Details', style: TextStyle(color: Colors.black87)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventImage(
              imageUrl: widget.event.imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              showLoadingIndicator: true,
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hosted by ${widget.event.orgName}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: widget.event.formattedDate,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    text: widget.event.formattedTime,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: widget.event.location,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.event.description,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 10),

                  if (!_isEventReallyOver && !_isRegistered) ...[
                    if (_loadingForm)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _showRegistrationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Register Now',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],

                  if (_isRegistered && !_isEventReallyOver)
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

                  if (_isEventReallyOver) _buildFeedbackSection(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── INFO ROW ──────────────────────────────────────────────────
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