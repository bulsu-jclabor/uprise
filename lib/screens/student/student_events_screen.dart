// lib/screens/student/student_events_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/event_model.dart';
import 'student_certificates_screen.dart' show CertificatesContent;

// ─── CUSTOM COLORS ─────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
}

// ─── EVENT IMAGE WIDGET ────────────────────────────────────────
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
    if (imageUrl.isEmpty) return _buildFallbackImage();
    if (_isBase64Image(imageUrl)) return _buildBase64Image();
    if (_isValidImageUrl(imageUrl)) return _buildNetworkImage();
    return _buildFallbackImage();
  }

  bool _isBase64Image(String url) =>
      url.startsWith('data:image') ||
      (url.isNotEmpty && !url.startsWith('http') && !url.startsWith('assets'));

  bool _isValidImageUrl(String url) =>
      url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('assets/');

  Widget _buildBase64Image() {
    try {
      String base64String = imageUrl;
      if (imageUrl.contains(',')) base64String = imageUrl.split(',').last;
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
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
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
            Tab(text: 'Certificates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildUpcomingTab(),
          const CertificatesContent(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
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
              FutureBuilder<Set<String>>(
                future: _getRegisteredEventIds(),
                builder: (context, regSnap) {
                  final regIds = regSnap.data ?? {};
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('events')
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
          child: FutureBuilder<Set<String>>(
            future: _getRegisteredEventIds(),
            builder: (context, regSnap) {
              final regIds = regSnap.data ?? {};
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
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

  Widget _buildUpcomingTab() {
    return FutureBuilder<Set<String>>(
      future: _getRegisteredEventIds(),
      builder: (context, regSnap) {
        final regIds = regSnap.data ?? {};
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('events')
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(event.date),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                  Text(
                    DateFormat('dd').format(event.date),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
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

// ─── UPCOMING EVENT CARD (with registration status) ────────────
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
              imageUrl: event.bannerUrl ?? '',
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

// ─── EVENT DETAIL SCREEN ──────────────────────────────────────
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
  bool _isRegistered = false; // added
  Map<String, dynamic>? _formDef;
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, String?> _singleChoice = {};
  final Map<String, Set<String>> _multiChoice = {};

  @override
  void initState() {
    super.initState();
    _loadRegistrationForm();
    _checkRegistrationStatus();
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
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
    if (widget.event.slotsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Event is full! No slots available.'),
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
        final slots = evDoc.data()!['slotsLeft'] as int? ?? 0;
        if (slots <= 0) throw Exception('No slots available for this event');
        tx.update(evRef, {'slotsLeft': slots - 1});
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

  Widget _buildDynamicField(Map<String, dynamic> field) {
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
              setState(() => _fieldControllers[id]!.text =
                  DateFormat('MMM dd, yyyy').format(picked));
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
                    onChanged: (v) => setState(() => _singleChoice[id] = v),
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
          onChanged: (v) => setState(() => _singleChoice[id] = v),
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
                    onChanged: (v) => setState(() {
                      _multiChoice.putIfAbsent(id, () => {});
                      if (v == true) {
                        _multiChoice[id]!.add(o);
                      } else {
                        _multiChoice[id]!.remove(o);
                      }
                    }),
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

  Widget _buildRegistrationFormSection() {
    if (_formDef == null) return const SizedBox.shrink();
    final fields = (_formDef!['fields'] as List).cast<Map<String, dynamic>>();
    final title = (_formDef!['title'] ?? 'Registration Form').toString();
    final desc = (_formDef!['description'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                desc,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 14),
          ...fields.map(_buildDynamicField),
        ],
      ),
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
              imageUrl: widget.event.bannerUrl ?? '',
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
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: '${widget.event.slotsLeft} / ${widget.event.capacity} slots remaining',
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
                  const SizedBox(height: 30),

                  // Dynamic registration form
                  if (!widget.isPastEvent && !_isRegistered && _loadingForm)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (!widget.isPastEvent && !_isRegistered && !_loadingForm)
                    _buildRegistrationFormSection(),

                  // Register / status button
                  if (!widget.isPastEvent && !_isRegistered)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading || _loadingForm ? null : _registerForEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              widget.event.slotsLeft > 0 ? AppColors.primaryDark : Colors.grey,
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
                            : Text(
                                widget.event.slotsLeft > 0
                                    ? 'Register Now (${widget.event.slotsLeft} slots left)'
                                    : 'Event Full',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                  if (_isRegistered && !widget.isPastEvent)
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