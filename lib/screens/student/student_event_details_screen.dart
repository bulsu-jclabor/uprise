import 'package:flutter/material.dart';
import 'student_events_screen.dart';

// ─────────────────────────────────────────────────────────────
//  EVENT DETAIL SCREEN
// ─────────────────────────────────────────────────────────────
class EventDetailScreen extends StatelessWidget {
  final EventData event;
  final VoidCallback onRegistered;

  const EventDetailScreen({
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
              // ── Hero App Bar ──
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
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: Colors.black),
                    ),
                  ),
                ),
                title: const Text(
                  'Upcoming Event',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                centerTitle: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        event.bannerUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.image,
                              size: 60, color: Colors.white38),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x44000000), Color(0xBB000000)],
                            stops: [0.0, 1.0],
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
                                letterSpacing: 0.5,
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

              // ── Body Content ──
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Organizer Row ──
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(event.logoUrl),
                              backgroundColor: Colors.grey[200],
                              onBackgroundImageError: (_, __) {},
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.organizer,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  event.organizerSub,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              event.id,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFAAAAAA),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 16),

                        // ── Info tiles ──
                        _InfoTile(
                          icon: Icons.calendar_today_outlined,
                          iconColor: const Color(0xFFE53935),
                          label: 'Date & Time',
                          value: '${event.date}  •  ${event.time}',
                        ),
                        const SizedBox(height: 10),
                        _InfoTile(
                          icon: Icons.people_outline,
                          iconColor: const Color(0xFF1565C0),
                          label: 'Slots Available',
                          value: '${event.slotsLeft} of ${event.slots} remaining',
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 16),

                        // ── About section ──
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
                        Text(
                          event.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.65,
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        const SizedBox(height: 16),

                        // ── Location section ──
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

                        // Bottom padding for sticky button
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Sticky bottom action bar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    // Slots summary
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
                        : _RegisterButton(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventRegistrationScreen(
                                    event: event,
                                    onRegistered: onRegistered,
                                  ),
                                ),
                              );
                            },
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
//  EVENT REGISTRATION SCREEN
// ─────────────────────────────────────────────────────────────
class EventRegistrationScreen extends StatefulWidget {
  final EventData event;
  final VoidCallback onRegistered;

  const EventRegistrationScreen({
    super.key,
    required this.event,
    required this.onRegistered,
  });

  @override
  State<EventRegistrationScreen> createState() =>
      _EventRegistrationScreenState();
}

class _EventRegistrationScreenState extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _courseCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
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
        centerTitle: false,
        title: const Text(
          'Event Registration',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      body: _submitted ? _SuccessView(event: widget.event) : _FormView(
        event: widget.event,
        formKey: _formKey,
        firstNameCtrl: _firstNameCtrl,
        lastNameCtrl: _lastNameCtrl,
        studentIdCtrl: _studentIdCtrl,
        courseCtrl: _courseCtrl,
        emailCtrl: _emailCtrl,
        isLoading: _isLoading,
        onSubmit: _submit,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FORM VIEW
// ─────────────────────────────────────────────────────────────
class _FormView extends StatelessWidget {
  final EventData event;
  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController studentIdCtrl;
  final TextEditingController courseCtrl;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormView({
    required this.event,
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.studentIdCtrl,
    required this.courseCtrl,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event summary card ──
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
                      event.bannerUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${event.slotsLeft} slots remaining',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: event.slotsLeft <= 10
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

            // ── Registration form header ──
            const Text(
              'EVENT REGISTRATION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please fill in your student information accurately.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  // First + Last name row
                  Row(
                    children: [
                      Expanded(
                        child: _FormField(
                          label: 'First Name',
                          controller: firstNameCtrl,
                          hint: 'Juan',
                          validator: (v) =>
                              v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormField(
                          label: 'Last Name',
                          controller: lastNameCtrl,
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

                  _FormField(
                    label: 'Student Number',
                    controller: studentIdCtrl,
                    hint: 'e.g. 2021-00123',
                    keyboardType: TextInputType.text,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  _FormField(
                    label: 'Course / Program',
                    controller: courseCtrl,
                    hint: 'e.g. BSIT, BSCS, BLIS',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  _FormField(
                    label: 'School Email',
                    controller: emailCtrl,
                    hint: 'juandelacruz@g.bulsu.edu.ph',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Submit button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Registration',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Text(
                'By registering, you confirm your attendance commitment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SUCCESS VIEW
// ─────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final EventData event;
  const _SuccessView({required this.event});

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
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You are now registered for ${event.title}. See you on ${event.date}!',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Pop back to events list (2 screens back)
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back to Events',
                  style: TextStyle(
                    fontSize: 15,
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

// ─────────────────────────────────────────────────────────────
//  REUSABLE FORM FIELD
// ─────────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFE53935), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE53935), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE53935), width: 1.5),
            ),
            errorStyle: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  INFO TILE
// ─────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LOCATION CARD
// ─────────────────────────────────────────────────────────────
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
      child: Column(
        children: [
          // Map placeholder
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 120,
              color: const Color(0xFFE8EAF6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Grid lines
                  CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _MapGridPainter(),
                  ),
                  // Pin
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on,
                            size: 20, color: Colors.white),
                      ),
                      Container(
                        width: 2,
                        height: 10,
                        color: const Color(0xFFE53935),
                      ),
                      Container(
                        width: 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Address row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Color(0xFFE53935)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MAP GRID PAINTER (decorative)
// ─────────────────────────────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBBEE8)
      ..strokeWidth = 0.8;

    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Roads
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5),
        roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.4, 0),
        Offset(size.width * 0.4, size.height),
        roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
//  REGISTER BUTTON
// ─────────────────────────────────────────────────────────────
class _RegisterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE53935).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  REGISTERED CHIP
// ─────────────────────────────────────────────────────────────
class _RegisteredChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          Text(
            'Registered',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CATEGORY BADGE (shared)
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category.toUpperCase(),
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