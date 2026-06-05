import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'student_event_details_screen.dart';

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
  });

  factory EventData.fromFirestore(DocumentSnapshot doc,
      {bool isRegistered = false}) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = d['date'];
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now();

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
    );
  }
}

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class StudentEventsScreen extends StatefulWidget {
  const StudentEventsScreen({super.key});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _filterIndex = 0;
  static const _filterLabels = ['All', 'Today', 'This Week'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _openDetail(EventData event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          onRegistered: () => setState(() {}),
        ),
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
          'Upcoming Event',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFE53935),
            unselectedLabelColor: Colors.black45,
            indicatorColor: const Color(0xFFE53935),
            tabs: const [
              Tab(text: 'All Events'),
              Tab(text: 'My Events'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── ALL EVENTS TAB ──
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
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFE53935)));
                  }
                  final events = snapshot.data!.docs.map((doc) {
                    final isReg = registeredIds.contains(doc.id);
                    return EventData.fromFirestore(doc, isRegistered: isReg);
                  }).toList();
                  return _EventListTab(
                    events: events,
                    filterIndex: _filterIndex,
                    filterLabels: _filterLabels,
                    onFilterChanged: (i) =>
                        setState(() => _filterIndex = i),
                    onEventTap: _openDetail,
                  );
                },
              );
            },
          ),

          // ── MY EVENTS TAB ──
          _MyEventsTabFetcher(onEventTap: _openDetail),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MY EVENTS FETCHER (queries registrations → fetches events)
// ─────────────────────────────────────────────
class _MyEventsTabFetcher extends StatelessWidget {
  final ValueChanged<EventData> onEventTap;
  const _MyEventsTabFetcher({required this.onEventTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .orderBy('registeredAt', descending: true)
          .snapshots(),
      builder: (context, regSnap) {
        if (regSnap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)));
        }

        if (!regSnap.hasData || regSnap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text(
                  'No registered events yet',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Events you register for will appear here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Get all eventIds from registrations
        final eventIds = regSnap.data!.docs
            .map((d) => d['eventId'] as String)
            .toList();

        return FutureBuilder<List<EventData>>(
          future: _fetchEventsByIds(eventIds),
          builder: (context, eventSnap) {
            if (eventSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFE53935)));
            }

            final myEvents = eventSnap.data ?? [];

            if (myEvents.isEmpty) {
              return const Center(
                  child: Text('No registered events yet'));
            }

            return _MyEventsTab(
                events: myEvents, onEventTap: onEventTap);
          },
        );
      },
    );
  }

  Future<List<EventData>> _fetchEventsByIds(
      List<String> eventIds) async {
    if (eventIds.isEmpty) return [];

    // Firestore whereIn supports max 10 items — chunk if needed
    final chunks = <List<String>>[];
    for (var i = 0; i < eventIds.length; i += 10) {
      chunks.add(eventIds.sublist(
          i, i + 10 > eventIds.length ? eventIds.length : i + 10));
    }

    final results = <EventData>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        results.add(EventData.fromFirestore(doc, isRegistered: true));
      }
    }
    return results;
  }
}

// ─────────────────────────────────────────────
//  ALL EVENTS TAB
// ─────────────────────────────────────────────
class _EventListTab extends StatelessWidget {
  final List<EventData> events;
  final int filterIndex;
  final List<String> filterLabels;
  final ValueChanged<int> onFilterChanged;
  final ValueChanged<EventData> onEventTap;

  const _EventListTab({
    required this.events,
    required this.filterIndex,
    required this.filterLabels,
    required this.onFilterChanged,
    required this.onEventTap,
  });

  List<EventData> _applyFilter(List<EventData> events, int filterIndex) {
    if (filterIndex == 0) return events;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((e) {
      try {
        final parsed = DateFormat('MMM dd, yyyy').parse(e.date);
        if (filterIndex == 1) {
          return parsed.year == today.year &&
              parsed.month == today.month &&
              parsed.day == today.day;
        } else {
          final endOfWeek = today.add(const Duration(days: 7));
          return parsed.isAfter(today.subtract(const Duration(days: 1))) &&
              parsed.isBefore(endOfWeek);
        }
      } catch (_) {
        return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilter(events, filterIndex);
    final featured = filtered.isNotEmpty ? filtered.first : null;
    final rest =
        filtered.length > 1 ? filtered.sublist(1) : <EventData>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Row(
            children: List.generate(
              filterLabels.length,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onFilterChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: filterIndex == i
                          ? const Color(0xFFE53935)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      filterLabels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: filterIndex == i
                            ? Colors.white
                            : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (featured != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _FeaturedEventCard(
                event: featured, onTap: () => onEventTap(featured)),
          ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text('No events found',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ...rest.map(
          (e) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _CompactEventCard(event: e, onTap: () => onEventTap(e)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  MY EVENTS TAB UI
// ─────────────────────────────────────────────
class _MyEventsTab extends StatelessWidget {
  final List<EventData> events;
  final ValueChanged<EventData> onEventTap;

  const _MyEventsTab({required this.events, required this.onEventTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: events
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    _MyEventCard(event: e, onTap: () => onEventTap(e)),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  FEATURED EVENT CARD
// ─────────────────────────────────────────────
class _FeaturedEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;

  const _FeaturedEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.network(
              event.bannerUrl,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 210,
                color: Colors.grey[800],
                child: const Icon(Icons.image,
                    size: 60, color: Colors.white38),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xCC000000)],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryBadge(category: event.category),
                    const SizedBox(height: 6),
                    Text(event.title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    Text(event.subtitle,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(event.date,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70)),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(event.location,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SlotsBar(
                              slots: event.slots,
                              slotsLeft: event.slotsLeft),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('View Details',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
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
//  COMPACT EVENT CARD
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
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Image.network(
              event.bannerUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[800],
                child:
                    const Icon(Icons.image, color: Colors.white38),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xDD000000), Color(0x55000000)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CategoryBadge(category: event.category),
                  const SizedBox(height: 4),
                  Text(event.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(event.date,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white60)),
                    ],
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
//  MY EVENT CARD
// ─────────────────────────────────────────────
class _MyEventCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;

  const _MyEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    color: Colors.grey[300],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle_outline,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Registered',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(event.logoUrl),
                    backgroundColor: Colors.grey[200],
                    onBackgroundImageError: (_, __) {},
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87)),
                        Text('${event.date}  •  ${event.time}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.black38, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SLOTS BAR
// ─────────────────────────────────────────────
class _SlotsBar extends StatelessWidget {
  final int slots;
  final int slotsLeft;
  const _SlotsBar({required this.slots, required this.slotsLeft});

  @override
  Widget build(BuildContext context) {
    final taken = slots - slotsLeft;
    final fraction = slots == 0 ? 0.0 : taken / slots;
    final isFull = slotsLeft <= 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$slotsLeft slots left',
          style: TextStyle(
            fontSize: 10,
            color:
                isFull ? const Color(0xFFFF7043) : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              isFull ? const Color(0xFFFF7043) : Colors.greenAccent,
            ),
          ),
        ),
      ],
    );
  }
}