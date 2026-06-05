import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_events_screen.dart';

// ─────────────────────────────────────────────────────────────
//  EVENT DETAIL SCREEN
// ─────────────────────────────────────────────────────────────
class EventDetailScreen extends StatefulWidget {
  final EventData event;
  final VoidCallback onRegistered;
  final bool isPastEvent;

  const EventDetailScreen({
    super.key,
    required this.event,
    required this.onRegistered,
    this.isPastEvent = false,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late bool _isRegistered;
  late int _slotsLeft;

  @override
  void initState() {
    super.initState();
    _isRegistered = widget.event.isRegistered;
    _slotsLeft = widget.event.slotsLeft;
  }

  void _onRegistered() {
    setState(() {
      _isRegistered = true;
      _slotsLeft = (_slotsLeft - 1).clamp(0, widget.event.slots);
    });
    widget.onRegistered();
    
    // Bumalik sa events screen para makita ang updated My Events tab
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context); // Isara ang registration screen
        Navigator.pop(context); // Isara ang details screen
      }
    });
  }

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
                  'Event Details',
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
                        widget.event.bannerUrl,
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
                            _CategoryBadge(category: widget.event.category),
                            const SizedBox(height: 6),
                            Text(
                              widget.event.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              widget.event.subtitle,
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
                              backgroundImage:
                                  NetworkImage(widget.event.logoUrl),
                              backgroundColor: Colors.grey[200],
                              onBackgroundImageError: (_, __) {},
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.event.organizer,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  widget.event.organizerSub,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              widget.event.id,
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
                          value:
                              '${widget.event.date}  •  ${widget.event.time}',
                        ),
                        const SizedBox(height: 10),
                        _InfoTile(
                          icon: Icons.people_outline,
                          iconColor: const Color(0xFF1565C0),
                          label: 'Slots Available',
                          value:
                              '$_slotsLeft of ${widget.event.slots} remaining',
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
                          widget.event.description,
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
                        _LocationCard(location: widget.event.location),

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isPastEvent
                                ? 'Event Already Passed'
                                : (_slotsLeft <= 10
                                    ? 'Almost Full!'
                                    : '$_slotsLeft slots left'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.isPastEvent
                                  ? Colors.grey
                                  : (_slotsLeft <= 10
                                      ? const Color(0xFFE53935)
                                      : Colors.black87),
                            ),
                          ),
                          Text(
                            widget.event.date,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.isPastEvent)
                      _PastEventChip()
                    else if (_isRegistered)
                      _RegisteredChip()
                    else if (_slotsLeft <= 0)
                      _FullChip()
                    else
                      _RegisterButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EventRegistrationScreen(
                                event: widget.event,
                                onRegistered: _onRegistered,
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

class _EventRegistrationScreenState
    extends State<EventRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;
  String? _errorMessage;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      final db = FirebaseFirestore.instance;
      final eventRef = db.collection('events').doc(widget.event.id);

      // ── 1. Check if already registered (prevent duplicates) ──
      final existingReg = await db
          .collection('registrations')
          .where('eventId', isEqualTo: widget.event.id)
          .where('userId', isEqualTo: user.uid)
          .get();

      if (existingReg.docs.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'You are already registered for this event.';
        });
        return;
      }

      // ── 2. Check slots inside a transaction ──
      await db.runTransaction((transaction) async {
        final eventSnap = await transaction.get(eventRef);
        final data = eventSnap.data() as Map<String, dynamic>? ?? {};

        final capacity = (data['capacity'] ?? 0) as int;
        final currentSlots = data.containsKey('slotsLeft')
            ? (data['slotsLeft'] as int)
            : capacity;

        if (currentSlots <= 0) {
          throw Exception('No slots available');
        }

        // ── 3. Save registration document ──
        final regRef = db.collection('registrations').doc();
        transaction.set(regRef, {
          'eventId': widget.event.id,
          'eventTitle': widget.event.title,
          'userId': user.uid,
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'studentId': _studentIdCtrl.text.trim(),
          'course': _courseCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'registeredAt': FieldValue.serverTimestamp(),
          'status': 'registered',
        });

        // ── 4. Minus slots ──
        transaction.update(eventRef, {
          'slotsLeft': currentSlots - 1,
        });
      });

      // ── 5. Success ──
      widget.onRegistered();
      setState(() {
        _isLoading = false;
        _submitted = true;
      });
    } on FirebaseException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Something went wrong. Try again.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
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
      body: _submitted
          ? _SuccessView(event: widget.event)
          : _FormView(
              event: widget.event,
              formKey: _formKey,
              firstNameCtrl: _firstNameCtrl,
              lastNameCtrl: _lastNameCtrl,
              studentIdCtrl: _studentIdCtrl,
              courseCtrl: _courseCtrl,
              emailCtrl: _emailCtrl,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
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
  final String? errorMessage;
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
    required this.errorMessage,
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
                              fontSize: 12, color: Colors.grey),
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

            // ── Error message ──
            if (errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE53935)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE53935), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
                  'Back to Event',
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
              borderSide:
                  const BorderSide(color: Color(0xFFE53935), width: 1.5),
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
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 120,
              color: const Color(0xFFE8EAF6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _MapGridPainter(),
                  ),
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
                      Container(width: 2, height: 10,
                          color: const Color(0xFFE53935)),
                      Container(
                        width: 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE53935).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  MAP GRID PAINTER
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
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(size.width * 0.4, 0),
        Offset(size.width * 0.4, size.height), roadPaint);
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
              fontWeight: FontWeight.w700),
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
          Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
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

// ─────────────────────────────────────────────────────────────
//  FULL CHIP (when no slots left)
// ─────────────────────────────────────────────────────────────
class _FullChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, size: 16, color: Color(0xFFE65100)),
          SizedBox(width: 6),
          Text('Event Full',
              style: TextStyle(
                  color: Color(0xFFE65100),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PAST EVENT CHIP (cannot register)
// ─────────────────────────────────────────────────────────────
class _PastEventChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[400]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            'Event Ended',
            style: TextStyle(
              color: Colors.grey[600],
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
//  CATEGORY BADGE
// ─────────────────────────────────────────────────────────────
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