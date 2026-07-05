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
            Tab(text: 'Certificates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CalendarTab(registeredEventIdsStream: _registeredEventIdsStream),
          UpcomingTab(registeredEventIdsStream: _registeredEventIdsStream),
          RegisteredEventsTab(registeredEventIdsStream: _registeredEventIdsStream),
          CertificatesTab(registeredEventIdsStream: _registeredEventIdsStream),
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
    super.build(context); // required for AutomaticKeepAlive
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
//  TAB 3: REGISTERED EVENTS
// ═══════════════════════════════════════════════════════════════
/// Shows every event the student has successfully registered for
/// (backed by the `registrations` collection), with a status derived
/// from the event's date/time: Upcoming, Ongoing, or Completed.
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

  /// Combines an EventModel's date with an optional "h:mm AM/PM" time
  /// string into a concrete DateTime. Falls back to midnight of the
  /// event date if the time can't be parsed.
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
                  'You haven\'t registered for any events yet',
                  style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        // Firestore whereIn supports up to 30 values; chunk if needed.
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

            // Sort: ongoing/upcoming first (soonest first), completed last (most recent first)
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GestureDetector(
                    onTap: () => _openDetail(event, status == _RegStatus.completed),
                    child: Container(
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
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.title,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  event.orgName,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(event.formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(event.formattedTime,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(event.location,
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
//  TAB 4: CERTIFICATES
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  TAB 4: CERTIFICATES (read‑only, no locked cards)
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  TAB 4: CERTIFICATES (with student upload feature)
// ═══════════════════════════════════════════════════════════════
class CertificatesTab extends StatefulWidget {
  final Stream<Set<String>> registeredEventIdsStream;
  const CertificatesTab({required this.registeredEventIdsStream, super.key});

  @override
  State<CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<CertificatesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _certFilter = 'All';
  List<String> _certFilters = ['All'];
  List<Map<String, dynamic>> _allCertificates = [];
  bool _certLoading = true;
  bool _orgFiltersLoading = true;
  String? _certError;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchCertificates();
    _fetchOrganizationFilters();
  }

  // ── Certificate helpers (read‑only) ──────────────────────────
  Future<void> _fetchCertificates() async {
    setState(() {
      _certLoading = true;
      _certError = null;
    });
    try {
      final query = _currentUid != null
          ? FirebaseFirestore.instance
              .collection('certificates')
              .where('recipientUid', isEqualTo: _currentUid)
          : FirebaseFirestore.instance.collection('certificates');
      final snapshot = await query.get();

      var docs = snapshot.docs;
      docs = docs
          .where((doc) => (doc.data()['status'] ?? '') != 'draft')
          .toList();

      docs.sort((a, b) {
        final aTs = a.data()['issuedAt'];
        final bTs = b.data()['issuedAt'];
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return (bTs as Timestamp).compareTo(aTs as Timestamp);
      });

      setState(() {
        _allCertificates = docs.map(_docToMap).toList();
        _certLoading = false;
      });
    } catch (e) {
      setState(() {
        _certError = e.toString();
        _certLoading = false;
      });
    }
  }

  Future<void> _fetchOrganizationFilters() async {
    setState(() => _orgFiltersLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .where('status', isEqualTo: 'active')
          .get();
      final names = snap.docs
          .map((d) => (d.data()['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      names.sort();
      setState(() {
        _certFilters = ['All', ...names];
        _orgFiltersLoading = false;
      });
    } catch (_) {
      setState(() {
        _certFilters = ['All'];
        _orgFiltersLoading = false;
      });
    }
  }

  Map<String, dynamic> _docToMap(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'title': d['eventName'] ?? 'Untitled Certificate',
      'date': _formatCertDate(d['issuedAt']),
      'category': d['type'] ?? d['templateType'] ?? 'General',
      'organization': d['organization'] ?? '',
      'signatories': d['signatories'] ?? '',
      'status': d['status'] ?? 'draft',
      'recipients': d['recipients'] ?? 0,
      'templateType': d['templateType'] ?? '',
      'imageUrl': d['imageUrl'] ?? '',
      'isUploaded': d['isUploaded'] ?? false,
      'verificationCode': d['verificationCode'] ?? '',
      'autoGenerated': d['autoGenerated'] ?? false,
      'eventId': d['eventId'] ?? '',
    };
  }

  String _formatCertDate(dynamic ts) {
    if (ts == null) return 'Just now';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      const m = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${m[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    }
    return ts.toString();
  }

  bool _isBase64Image(String url) =>
      url.startsWith('data:image') || (!url.startsWith('http') && url.isNotEmpty);

  Future<Uint8List?> _getCertImageBytes(String imageUrl) async {
    if (imageUrl.isEmpty) return null;
    try {
      if (_isBase64Image(imageUrl)) {
        final b64 =
            imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        return base64Decode(b64);
      }
      final resp = await http.get(Uri.parse(imageUrl));
      if (resp.statusCode == 200) return resp.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadCertificateAsPdf(Map<String, dynamic> cert) async {
    final imageUrl = cert['imageUrl'] as String? ?? '';
    final title = (cert['title'] ?? 'Certificate').toString();

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Preparing PDF...'),
      backgroundColor: AppColors.primaryDark,
      duration: Duration(seconds: 2),
    ));

    try {
      final imageBytes = await _getCertImageBytes(imageUrl);
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No certificate image available to download.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      final pdfImage = pw.MemoryImage(imageBytes);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final safeName = title
          .trim()
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName =
          '${safeName.isEmpty ? "certificate" : safeName}_${cert['id']}.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await doc.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$title saved as PDF'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.white,
          onPressed: () => OpenFile.open(filePath),
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Widget _buildCertImage(String imageUrl, {double height = 180}) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    if (_isBase64Image(imageUrl)) {
      try {
        final b64 =
            imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
        final bytes = base64Decode(b64);
        return Image.memory(bytes,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } catch (_) {
        return const SizedBox.shrink();
      }
    }
    return Image.network(imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, p) {
          if (p == null) return child;
          return Container(
              height: height,
              color: AppColors.primaryDark.shade50,
              child: const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryDark)));
        },
        errorBuilder: (_, __, ___) => const SizedBox.shrink());
  }

  Widget _certPlaceholderBanner(
      bool isDraft, bool isUploaded, Map<String, dynamic> cert) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUploaded
              ? [Colors.blue.shade200, Colors.blue.shade500]
              : [
                  AppColors.primaryDark.shade200,
                  AppColors.primaryDark.shade500
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Icon(
            isUploaded
                ? Icons.upload_file_rounded
                : Icons.workspace_premium,
            size: 70,
            color: Colors.white24),
        if (isDraft)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('DRAFT',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
          ),
        if ((cert['organization'] as String).isNotEmpty &&
            cert['organization'] != 'Others')
          Positioned(
            bottom: 10,
            left: 14,
            child: Text(cert['organization'],
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
      ]),
    );
  }

  void _showOrgFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Filter by Organization',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    ...List.generate(_certFilters.length, (i) {
                      final f = _certFilters[i];
                      final sel = _certFilter == f;
                      return InkWell(
                        onTap: () {
                          setSheetState(() {});
                          setState(() => _certFilter = f);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                sel
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: sel
                                    ? AppColors.primaryDark
                                    : Colors.grey.shade400,
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(f,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: sel
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: sel
                                            ? AppColors.primaryDark
                                            : Colors.black87)),
                              ),
                              if (sel)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryDark,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Certificate card – used for every certificate (no locked state).
  Widget _buildCertificateCard(Map<String, dynamic> cert) {
    final isDraft = cert['status'] == 'draft';
    final isUploaded = cert['isUploaded'] == true;
    final imageUrl = cert['imageUrl'] as String;
    final vCode = cert['verificationCode'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? _buildCertImage(imageUrl)
                : _certPlaceholderBanner(isDraft, isUploaded, cert),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cert['title'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      if (cert['category'] != 'Others') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.primaryDark.shade50,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(cert['category'],
                              style: TextStyle(
                                  color: AppColors.primaryDark.shade700,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(cert['date'],
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                      if (isUploaded) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('Uploaded by you',
                              style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ],
                  ),
                ),
                // Download button
                GestureDetector(
                  onTap: () => _downloadCertificateAsPdf(cert),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.download_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          if (vCode.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            GestureDetector(
              onTap: () => _showVerifyDialog(cert),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  QrImageView(
                      data: vCode,
                      version: QrVersions.auto,
                      size: 44,
                      backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Verify Certificate',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800)),
                        const SizedBox(height: 2),
                        Text('Code: $vCode',
                            style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 1.1,
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w600)),
                      ])),
                  Icon(Icons.open_in_new_rounded,
                      size: 16, color: Colors.grey.shade400),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Verification dialog ──
  void _showVerifyDialog(Map<String, dynamic> cert) {
    final code = cert['verificationCode'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const Icon(Icons.verified_rounded,
                color: Color(0xFF059669), size: 36),
            const SizedBox(height: 10),
            const Text('Certificate Verification',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 4),
            Text(cert['title'],
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Center(
                child: QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white)),
            const SizedBox(height: 16),
            Text('Verification Code',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Code copied to clipboard'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(code,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: Color(0xFFB45309))),
                      const SizedBox(width: 10),
                      const Icon(Icons.copy_rounded,
                          size: 16, color: Color(0xFFB45309)),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Share this QR or code to verify authenticity.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UPLOAD FEATURE (student adds their own certificate)
  // ═══════════════════════════════════════════════════════════════
  Future<void> _showUploadDialog() async {
    final eventNameCtrl = TextEditingController();
    File? pickedFile;
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> pickImage(ImageSource src) async {
            final picked = await ImagePicker()
                .pickImage(source: src, imageQuality: 60, maxWidth: 800);
            if (picked != null) {
              setSheet(() => pickedFile = File(picked.path));
            }
          }

          Future<void> doUpload() async {
            if (pickedFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a certificate image.'),
                backgroundColor: AppColors.primaryDark,
              ));
              return;
            }
            if (eventNameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Certificate name is required.'),
                backgroundColor: AppColors.primaryDark,
              ));
              return;
            }
            setSheet(() => isUploading = true);
            try {
              final bytes = await pickedFile!.readAsBytes();
              final b64Img = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (b64Img.length > 900000) {
                setSheet(() => isUploading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Image is too large. Please pick a smaller image.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 4),
                  ));
                }
                return;
              }

              final docRef = await FirebaseFirestore.instance
                  .collection('certificates')
                  .add({
                'eventName': eventNameCtrl.text.trim(),
                'imageUrl': b64Img,
                'issuedAt': FieldValue.serverTimestamp(),
                'recipientUid': _currentUid,
                'isUploaded': true,
                'status': 'issued',
              });

              final now = DateTime.now();
              const months = [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
              final newCert = {
                'id': docRef.id,
                'title': eventNameCtrl.text.trim(),
                'date':
                    '${months[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}',
                'category': 'General',
                'organization': '',
                'signatories': '',
                'status': 'issued',
                'recipients': 1,
                'templateType': '',
                'imageUrl': b64Img,
                'isUploaded': true,
                'verificationCode': '',
              };

              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  _allCertificates.insert(0, newCert);
                  _certFilter = 'All';
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Certificate uploaded successfully!'),
                  backgroundColor: Colors.green,
                ));
                _fetchCertificates(); // refresh from server
              }
            } catch (e) {
              setSheet(() => isUploading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Upload failed: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 6),
                ));
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                maxWidth: 480,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Upload Certificate',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(
                                  'Add the image and name of your certificate.',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                size: 18, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: ctx,
                        builder: (c) => SafeArea(
                            child: Wrap(children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library_rounded),
                            title: const Text('Choose from Gallery'),
                            onTap: () {
                              Navigator.pop(c);
                              pickImage(ImageSource.gallery);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt_rounded),
                            title: const Text('Take a Photo'),
                            onTap: () {
                              Navigator.pop(c);
                              pickImage(ImageSource.camera);
                            },
                          ),
                        ])),
                      ),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primaryDark.shade200,
                              width: 1.5),
                        ),
                        child: pickedFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.file(pickedFile!,
                                          fit: BoxFit.cover),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: const Text('Tap to change',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11)),
                                        ),
                                      ),
                                    ]),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.cloud_upload_rounded,
                                        size: 44,
                                        color:
                                            AppColors.primaryDark.shade400),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload image',
                                        style: TextStyle(
                                            color: AppColors
                                                .primaryDark.shade400,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'Keep image under 700KB for best results',
                                        style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 11)),
                                  ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _certSectionLabel('Certificate Details'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: eventNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Certificate Name *',
                        hintText: 'e.g. Codecraft',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primaryDark, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isUploading ? null : doUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          disabledBackgroundColor:
                              AppColors.primaryDark.shade200,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isUploading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5)),
                                    SizedBox(width: 12),
                                    Text('Uploading...',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                  ])
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(Icons.cloud_upload_rounded,
                                        color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text('Upload Certificate',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _certSectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark.shade700,
                letterSpacing: 0.4)),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _certFilter == 'All'
        ? _allCertificates
        : _allCertificates
            .where((c) => c['organization'] == _certFilter)
            .toList();

    return Stack(
      children: [
        Column(children: [
          // Filter header row (no evaluation banner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _certFilter == 'All' ? 'All Certificates' : _certFilter,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _showOrgFilterSheet,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _certFilter != 'All'
                          ? AppColors.primaryDark
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _certFilter != 'All'
                            ? AppColors.primaryDark
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: _certFilter != 'All'
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: _certLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryDark))
                : _certError != null
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 12),
                            Text('Failed to load certificates',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(_certError!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchCertificates,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark),
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ]))
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.workspace_premium_outlined,
                                      size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No Certificates Yet',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Your participation certificates will appear here after:\n\n'
                                    '• Your organization sends an evaluation request.\n'
                                    '• You complete the event evaluation.\n'
                                    '• Your organization uploads your certificate.\n\n'
                                    'Once available, you can preview and download your certificates from this page.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                        height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppColors.primaryDark,
                            onRefresh: _fetchCertificates,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 4,
                                  bottom: 80), // space for FAB
                              itemCount: filtered.length,
                              itemBuilder: (_, i) =>
                                  _buildCertificateCard(filtered[i]),
                            ),
                          ),
          ),
        ]),
        // ── FAB for uploading a new certificate ──
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'cert_upload_fab_tab',
            onPressed: _showUploadDialog,
            backgroundColor: AppColors.primaryDark,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
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

  // ── Feedback / rating state ──
  int _rating = 0;
  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _feedbackSubmitted = false;
  bool _checkingFeedback = true;
  bool _submittingFeedback = false;

  /// True only once the event's end time has actually passed.
  /// Falls back to widget.isPastEvent if no usable end time is found,
  /// so this never makes feedback show up EARLIER than before —
  /// only fixes cases where it was showing up too early (e.g. right
  /// after midnight on the event date, before the event even started).
  bool get _isEventReallyOver {
    try {
      final event = widget.event;
      // Try to read an endTime-like field via dynamic access.
      // EventModel stores date as a DateTime at midnight, and a
      // separate "endTime" string like "10:00 AM".
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

  /// Combines a date (year/month/day) with a time string like
  /// "10:00 AM" or "14:30" into a single DateTime. Returns null if
  /// the time string can't be parsed.
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

  // ── Feedback helpers ──
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

                  // Past event: show star-rating feedback form instead of a static label
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