import 'package:flutter/material.dart';
import 'student_event_details_screen.dart';

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────
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
  final String category; // 'tech', 'hackathon', 'seminar', etc.
  final bool isRegistered;
  final int slots;
  final int slotsLeft;

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
  });

  EventData copyWith({bool? isRegistered}) => EventData(
        id: id,
        title: title,
        subtitle: subtitle,
        organizer: organizer,
        organizerSub: organizerSub,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        date: date,
        time: time,
        location: location,
        description: description,
        category: category,
        isRegistered: isRegistered ?? this.isRegistered,
        slots: slots,
        slotsLeft: slotsLeft,
      );
}

// ─────────────────────────────────────────────────────────────
//  SAMPLE DATA
// ─────────────────────────────────────────────────────────────
final List<EventData> allEvents = [
  EventData(
    id: 'EVT-2025-001',
    title: 'TechTalk',
    subtitle: 'SHAPING THE FUTURE OF TECHNOLOGY',
    organizer: 'CICT Student Council',
    organizerSub: 'ORGANIZATION',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Bulacan_State_University_logo.png/120px-Bulacan_State_University_logo.png',
    bannerUrl:
        'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&q=70',
    date: 'Nov 10, 2025',
    time: '9:00 AM – 5:00 PM',
    location: 'Multi-Purpose Hall, BulSU – CICT',
    description:
        'Join us for TechTalk 2025 — a full-day technology symposium featuring industry leaders, live demos, and workshops. This year\'s theme "Shaping the Future of Technology" focuses on AI, cloud computing, and cybersecurity.\n\nSpeakers include senior engineers from top tech companies in the Philippines. Attendees will gain insights into emerging technologies and career opportunities in the IT sector.\n\nCertificates of attendance will be issued to all registered participants. Lunch and snacks are provided.',
    category: 'seminar',
    isRegistered: false,
    slots: 200,
    slotsLeft: 47,
  ),
  EventData(
    id: 'EVT-2025-002',
    title: 'HACKATHON 2025',
    subtitle: 'INNOVATE. BUILD. COMPETE.',
    organizer: 'FRX CREW',
    organizerSub: 'ORGANIZATION',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/Logo.svg/120px-Logo.svg.png',
    bannerUrl:
        'https://images.unsplash.com/photo-1504384308090-c894fdcc538d?w=800&q=70',
    date: 'Nov 15–16, 2025',
    time: '8:00 AM – 6:00 PM',
    location: 'CS Laboratory, CICT Building',
    description:
        'The official CICT Hackathon 2025 challenges student teams to build innovative software solutions in 24 hours. Open to all CICT students — form a team of 3–5 and register before slots run out.\n\nThemes will be announced on the day of the event. Cash prizes, trophies, and internship offers await the top 3 teams. Free meals for all participants throughout the event.',
    category: 'competition',
    isRegistered: false,
    slots: 120,
    slotsLeft: 22,
  ),
  EventData(
    id: 'EVT-2025-003',
    title: 'DEEP TECH HACKERS DAY',
    subtitle: 'HACK THE FUTURE',
    organizer: 'IS³ Society',
    organizerSub: 'ORGANIZATION',
    logoUrl:
        'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Bulacan_State_University_logo.png/120px-Bulacan_State_University_logo.png',
    bannerUrl:
        'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&q=70',
    date: 'Nov 20, 2025',
    time: '1:00 PM – 7:00 PM',
    location: 'Networking Lab, CICT 3F',
    description:
        'Deep Tech Hackers Day is an afternoon of hands-on cybersecurity workshops, ethical hacking challenges, and live CTF (Capture the Flag) rounds. All skill levels are welcome.\n\nLearn penetration testing basics, network security, and real-world vulnerability analysis from certified security professionals. Bring your own laptop.',
    category: 'workshop',
    isRegistered: true,
    slots: 80,
    slotsLeft: 5,
  ),
];

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN (stateful – manages registration state)
// ─────────────────────────────────────────────────────────────
class StudentEventsScreen extends StatefulWidget {
  const StudentEventsScreen({super.key});

  @override
  State<StudentEventsScreen> createState() => _StudentEventsScreenState();
}

class _StudentEventsScreenState extends State<StudentEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<EventData> _events;
  int _filterIndex = 0; // 0=All, 1=Today, 2=This Week

  static const _filterLabels = ['All', 'Today', 'This Week'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _events = List.from(allEvents);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<EventData> get _filteredAll => _events;
  List<EventData> get _myEvents =>
      _events.where((e) => e.isRegistered).toList();

  void _onRegistered(String eventId) {
    setState(() {
      _events = _events.map((e) {
        if (e.id == eventId) return e.copyWith(isRegistered: true);
        return e;
      }).toList();
    });
  }

  void _openDetail(BuildContext context, EventData event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          event: event,
          onRegistered: () => _onRegistered(event.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
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
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
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
          _EventListTab(
            events: _filteredAll,
            filterIndex: _filterIndex,
            filterLabels: _filterLabels,
            onFilterChanged: (i) => setState(() => _filterIndex = i),
            onEventTap: (e) => _openDetail(context, e),
          ),
          _MyEventsTab(
            events: _myEvents,
            onEventTap: (e) => _openDetail(context, e),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ALL EVENTS TAB
// ─────────────────────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final featured = events.isNotEmpty ? events.first : null;
    final rest = events.length > 1 ? events.sublist(1) : <EventData>[];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // ── Filter chips ──
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

        // ── Featured Event Card ──
        if (featured != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _FeaturedEventCard(
                event: featured, onTap: () => onEventTap(featured)),
          ),

        // ── Secondary cards ──
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

// ─────────────────────────────────────────────────────────────
//  MY EVENTS TAB
// ─────────────────────────────────────────────────────────────
class _MyEventsTab extends StatelessWidget {
  final List<EventData> events;
  final ValueChanged<EventData> onEventTap;

  const _MyEventsTab({required this.events, required this.onEventTap});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No registered events yet',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse All Events and register to see them here.',
              style: TextStyle(fontSize: 12, color: Colors.black38),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: events
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MyEventCard(event: e, onTap: () => onEventTap(e)),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FEATURED EVENT CARD (large hero)
// ─────────────────────────────────────────────────────────────
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
            // Banner
            Image.network(
              event.bannerUrl,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 210,
                color: Colors.grey[800],
                child: const Icon(Icons.image, size: 60, color: Colors.white38),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
            ),
            // Content overlay
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
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      event.subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          event.date,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SlotsBar(
                              slots: event.slots, slotsLeft: event.slotsLeft),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

// ─────────────────────────────────────────────────────────────
//  COMPACT EVENT CARD (smaller list cards)
// ─────────────────────────────────────────────────────────────
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
                child: const Icon(Icons.image, color: Colors.white38),
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
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: Colors.white60),
                      const SizedBox(width: 4),
                      Text(
                        event.date,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white60),
                      ),
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

// ─────────────────────────────────────────────────────────────
//  MY EVENT CARD (with registration status)
// ─────────────────────────────────────────────────────────────
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                        Text(
                          'Registered',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${event.date}  •  ${event.time}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  Color get _color {
    switch (category) {
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

class _SlotsBar extends StatelessWidget {
  final int slots;
  final int slotsLeft;
  const _SlotsBar({required this.slots, required this.slotsLeft});

  @override
  Widget build(BuildContext context) {
    final taken = slots - slotsLeft;
    final fraction = taken / slots;
    final isFull = slotsLeft <= 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$slotsLeft slots left',
          style: TextStyle(
            fontSize: 10,
            color: isFull ? const Color(0xFFFF7043) : Colors.white70,
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
              isFull ? const Color(0xFFFF7043) : const Color(0xFF69F0AE),
            ),
          ),
        ),
      ],
    );
  }
}