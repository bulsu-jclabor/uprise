// lib/screens/guest/guest_events_screen.dart
//
// GUEST MODE – public events only + self-service registration via email OTP
//
import 'package:flutter/material.dart';
import '../student/student_events_screen.dart' show EventData, allEvents;

// ── Sample public-only events (CICT-only / Members-only events excluded) ──
final List<EventData> _publicEvents = allEvents.where((e) => e.isPublic).toList();

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class GuestEventsScreen extends StatefulWidget {
  const GuestEventsScreen({super.key});

  @override
  State<GuestEventsScreen> createState() => _GuestEventsScreenState();
}

class _GuestEventsScreenState extends State<GuestEventsScreen> {
  late List<EventData> _events;

  @override
  void initState() {
    super.initState();
    _events = List.from(_publicEvents);
  }

  void _onRegistered(String id) {
    setState(() {
      _events = _events.map((e) {
        if (e.id == id) return e.copyWith(isRegistered: true);
        return e;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final featured = _events.isNotEmpty ? _events.first : null;
    final rest = _events.length > 1 ? _events.sublist(1) : <EventData>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Public Events',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF81C784)),
            ),
            child: const Text(
              'Open to All',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _events.isEmpty
          ? const _EmptyEvents()
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // ── "CICT-only" notice ──
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC02)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: Color(0xFFF57F17)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some events are exclusive to CICT students. Sign in to see all events.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6D4C00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Featured
                if (featured != null)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: _GuestFeaturedCard(
                      event: featured,
                      onTap: () => _openDetail(featured),
                    ),
                  ),

                // Rest
                ...rest.map(
                  (e) => Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: _GuestCompactCard(
                        event: e, onTap: () => _openDetail(e)),
                  ),
                ),
              ],
            ),
    );
  }

  void _openDetail(EventData event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuestEventDetailScreen(
          event: event,
          onRegistered: () => _onRegistered(event.id),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FEATURED CARD
// ─────────────────────────────────────────────────────────────
class _GuestFeaturedCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;
  const _GuestFeaturedCard({required this.event, required this.onTap});

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
                    const SizedBox(height: 8),
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
//  COMPACT CARD
// ─────────────────────────────────────────────────────────────
class _GuestCompactCard extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;
  const _GuestCompactCard({required this.event, required this.onTap});

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
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[800]),
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
                    ),
                  ),
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

// ─────────────────────────────────────────────────────────────
//  EVENT DETAIL SCREEN (guest)
// ─────────────────────────────────────────────────────────────
class GuestEventDetailScreen extends StatelessWidget {
  final EventData event;
  final VoidCallback onRegistered;

  const GuestEventDetailScreen({
    super.key,
    required this.event,
    required this.onRegistered,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: Colors.black),
                    ),
                  ),
                ),
                title: const Text(
                  'Public Event',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        event.bannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[800]),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x44000000),
                              Color(0xBB000000)
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CategoryBadge(category: event.category),
                            const SizedBox(height: 6),
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              event.subtitle,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Organizer
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                NetworkImage(event.logoUrl),
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.organizer,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87)),
                              Text(event.organizerSub,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
                            ],
                          ),
                          const Spacer(),
                          Text(event.id,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFAAAAAA))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(
                          height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),

                      // Date & slots
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        iconColor: const Color(0xFFE53935),
                        label: 'Date & Time',
                        value:
                            '${event.date}  •  ${event.time}',
                      ),
                      const SizedBox(height: 10),
                      _InfoTile(
                        icon: Icons.people_outline,
                        iconColor: const Color(0xFF1565C0),
                        label: 'Slots Available',
                        value:
                            '${event.slotsLeft} of ${event.slots} remaining',
                      ),

                      const SizedBox(height: 16),
                      const Divider(
                          height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),

                      const Text(
                        'ABOUT THIS EVENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF888888),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(event.description,
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.65)),

                      const SizedBox(height: 20),
                      const Divider(
                          height: 1, color: Color(0xFFEEEEEE)),
                      const SizedBox(height: 16),

                      const Text(
                        'LOCATION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF888888),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _LocationCard(location: event.location),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky register button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.09),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            event.slotsLeft <= 10
                                ? 'Almost Full!'
                                : '${event.slotsLeft} slots left',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: event.slotsLeft <= 10
                                  ? const Color(0xFFE53935)
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            event.date,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    event.isRegistered
                        ? _RegisteredChip()
                        : GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GuestEventRegistrationScreen(
                                  event: event,
                                  onRegistered: onRegistered,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE53935),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Register Now',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GUEST REGISTRATION SCREEN (email + OTP verification)
// ─────────────────────────────────────────────────────────────
class GuestEventRegistrationScreen extends StatefulWidget {
  final EventData event;
  final VoidCallback onRegistered;

  const GuestEventRegistrationScreen({
    super.key,
    required this.event,
    required this.onRegistered,
  });

  @override
  State<GuestEventRegistrationScreen> createState() =>
      _GuestEventRegistrationScreenState();
}

class _GuestEventRegistrationScreenState
    extends State<GuestEventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _submitted = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _schoolCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_emailCtrl.text.trim().isEmpty ||
        !_emailCtrl.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    // TODO: Call your OTP service here
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() {
      _isLoading = false;
      _otpSent = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'OTP sent to ${_emailCtrl.text.trim()}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // TODO: Verify OTP and submit to Firestore
    await Future.delayed(const Duration(milliseconds: 1500));
    widget.onRegistered();
    setState(() {
      _isLoading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Guest Registration',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ),
      ),
      body: _submitted
          ? _GuestSuccessView(event: widget.event)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event summary
                    Container(
                      padding: const EdgeInsets.all(14),
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
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.event.bannerUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                      width: 70,
                                      height: 70,
                                      color: Colors.grey[300]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(widget.event.title,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87)),
                                const SizedBox(height: 2),
                                Text(widget.event.date,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.event.slotsLeft} slots remaining',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: widget.event.slotsLeft <=
                                            10
                                        ? const Color(0xFFE53935)
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Guest badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFCC02)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.person_outline_rounded,
                              size: 16,
                              color: Color(0xFFF57F17)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Guest Registration — verify your identity with a valid email address.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6D4C00)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'PERSONAL INFORMATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _GuestFormField(
                                  label: 'First Name',
                                  controller: _firstNameCtrl,
                                  hint: 'Juan',
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _GuestFormField(
                                  label: 'Last Name',
                                  controller: _lastNameCtrl,
                                  hint: 'Dela Cruz',
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _GuestFormField(
                            label: 'School / Institution',
                            controller: _schoolCtrl,
                            hint: 'e.g. DLSU, PLM, MAPUA',
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'EMAIL VERIFICATION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _GuestFormField(
                                  label: 'Email Address',
                                  controller: _emailCtrl,
                                  hint: 'your@email.com',
                                  keyboardType:
                                      TextInputType.emailAddress,
                                  readOnly: _otpSent,
                                  validator: (v) {
                                    if (v == null ||
                                        v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Invalid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _otpSent)
                                      ? null
                                      : _sendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFE53935),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading && !_otpSent
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _otpSent
                                              ? 'Sent ✓'
                                              : 'Send OTP',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_otpSent) ...[
                            const SizedBox(height: 14),
                            _GuestFormField(
                              label: 'Enter OTP',
                              controller: _otpCtrl,
                              hint: '6-digit code',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (v.trim().length < 4) {
                                  return 'Enter the full OTP';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (!_otpSent || _isLoading)
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor:
                              Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading && _otpSent
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(
                                _otpSent
                                    ? 'Complete Registration'
                                    : 'Send OTP to Continue',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'By registering, you confirm your attendance commitment.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUCCESS VIEW
// ─────────────────────────────────────────────────────────────
class _GuestSuccessView extends StatelessWidget {
  final EventData event;
  const _GuestSuccessView({required this.event});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 44, color: Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Registration Successful!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are registered for ${event.title}. A confirmation and your QR attendance code will be sent to your email.',
              style: const TextStyle(
                  fontSize: 14, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Events',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EMPTY STATE
// ─────────────────────────────────────────────────────────────
class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No public events right now',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Check back soon for upcoming events.',
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────
class _GuestFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _GuestFormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          readOnly: readOnly,
          style: TextStyle(
              fontSize: 14,
              color: readOnly ? Colors.grey : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFBBBBBB)),
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF8F8F8)
                : const Color(0xFFF7F7F7),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFE53935), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFE53935), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFE53935), width: 1.5),
            ),
            errorStyle:
                const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: _color,
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8),
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
    final fraction = (slots - slotsLeft) / slots;
    final isFull = slotsLeft <= 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$slotsLeft slots left',
            style: TextStyle(
                fontSize: 10,
                color: isFull
                    ? const Color(0xFFFF7043)
                    : Colors.white70,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              isFull
                  ? const Color(0xFFFF7043)
                  : const Color(0xFF69F0AE),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon,
      required this.iconColor,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String location;
  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 18, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(location,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisteredChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.check_circle,
              size: 16, color: Color(0xFF2E7D32)),
          SizedBox(width: 6),
          Text('Registered',
              style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
