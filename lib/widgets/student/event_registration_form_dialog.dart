// lib/widgets/student/event_registration_form_dialog.dart
// Renders the org's custom Form Builder registration form (registration_forms/{proposalId})
// for a student to fill out and submit when registering for an event linked from an announcement.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DynamicRegistrationDialog extends StatefulWidget {
  final String proposalId;
  final String eventId;
  final String eventTitle;

  const DynamicRegistrationDialog({
    super.key,
    required this.proposalId,
    required this.eventId,
    required this.eventTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String proposalId,
    required String eventId,
    required String eventTitle,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DynamicRegistrationDialog(
        proposalId: proposalId,
        eventId: eventId,
        eventTitle: eventTitle,
      ),
    );
  }

  @override
  State<DynamicRegistrationDialog> createState() => _DynamicRegistrationDialogState();
}

class _DynamicRegistrationDialogState extends State<DynamicRegistrationDialog> {
  static const Color _primary = Color(0xFFBE4700);

  bool _loading = true;
  bool _submitting = false;
  bool _alreadyRegistered = false;
  String? _error;
  String _formTitle = 'Registration Form';
  String _formDescription = '';
  List<Map<String, dynamic>> _fields = [];

  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final existing = await FirebaseFirestore.instance
            .collection('registrations')
            .doc('${user.uid}_${widget.eventId}')
            .get();
        if (existing.exists) _alreadyRegistered = true;
      }

      final formDoc = await FirebaseFirestore.instance
          .collection('registration_forms')
          .doc(widget.proposalId)
          .get();

      if (formDoc.exists) {
        final d = formDoc.data()!;
        _formTitle = (d['title'] as String?)?.trim().isNotEmpty == true
            ? d['title']
            : 'Registration Form';
        _formDescription = d['description'] as String? ?? '';
        final raw = d['fields'];
        if (raw is List) {
          _fields = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } else {
        _error = 'Registration form is not available for this event.';
      }
    } catch (e) {
      _error = 'Failed to load form: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to register')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      String fullName = '';
      String email = user.email ?? '';
      try {
        final stu = await FirebaseFirestore.instance
            .collection('students')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        if (stu.docs.isNotEmpty) {
          final d = stu.docs.first.data();
          fullName = d['fullName'] ?? '';
          email = d['email'] ?? email;
        }
      } catch (_) {}

      final regRef = FirebaseFirestore.instance
          .collection('registrations')
          .doc('${user.uid}_${widget.eventId}');
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final regSnap = await tx.get(regRef);
        if (regSnap.exists) {
          throw Exception('You are already registered for this event.');
        }
        final eventSnap = await tx.get(eventRef);
        if (!eventSnap.exists) throw Exception('Event not found.');
        final slotsLeft = (eventSnap.data()?['slotsLeft'] ?? 0) as int;
        if (slotsLeft <= 0) throw Exception('No slots available.');

        tx.update(eventRef, {'slotsLeft': slotsLeft - 1});
        tx.set(regRef, {
          'userId': user.uid,
          'eventId': widget.eventId,
          'fullName': fullName,
          'email': email,
          'formId': widget.proposalId,
          'formAnswers': _answers,
          'registeredAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Successfully registered for ${widget.eventTitle}!'),
          backgroundColor: _primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  Widget _buildField(Map<String, dynamic> f) {
    final id = f['id'] as String? ?? '';
    final type = f['type'] as String? ?? 'short_text';
    final label = f['label'] as String? ?? '';
    final description = f['description'] as String? ?? '';
    final required = f['required'] == true;
    final options = (f['options'] as List?)?.map((e) => e.toString()).toList() ?? [];

    Widget input;
    switch (type) {
      case 'paragraph':
        final ctrl = _textControllers.putIfAbsent(id, () => TextEditingController());
        input = TextFormField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          validator: (v) =>
              required && (v == null || v.trim().isEmpty) ? 'This field is required' : null,
          onChanged: (v) => _answers[id] = v,
        );
        break;
      case 'email':
        final ctrl = _textControllers.putIfAbsent(id, () => TextEditingController());
        input = TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) return 'This field is required';
            if (v != null && v.isNotEmpty && !v.contains('@')) return 'Enter a valid email';
            return null;
          },
          onChanged: (v) => _answers[id] = v,
        );
        break;
      case 'number':
        final ctrl = _textControllers.putIfAbsent(id, () => TextEditingController());
        input = TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          validator: (v) =>
              required && (v == null || v.trim().isEmpty) ? 'This field is required' : null,
          onChanged: (v) => _answers[id] = v,
        );
        break;
      case 'date':
        input = StatefulBuilder(builder: (ctx, setLocal) {
          final selected = _answers[id] as String?;
          return FormField<String>(
            initialValue: selected,
            validator: (_) =>
                required && (selected == null || selected.isEmpty) ? 'Please select a date' : null,
            builder: (state) => InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  final formatted = picked.toIso8601String().split('T').first;
                  setState(() => _answers[id] = formatted);
                  state.didChange(formatted);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  errorText: state.errorText,
                ),
                child: Text(selected ?? 'Select date',
                    style: TextStyle(color: selected == null ? Colors.grey[600] : Colors.black87)),
              ),
            ),
          );
        });
        break;
      case 'dropdown':
        input = DropdownButtonFormField<String>(
          value: _answers[id] as String?,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _answers[id] = v),
          validator: (v) => required && (v == null || v.isEmpty) ? 'Please select an option' : null,
        );
        break;
      case 'multiple_choice':
        input = FormField<String>(
          initialValue: _answers[id] as String?,
          validator: (v) => required && (v == null || v.isEmpty) ? 'Please select an option' : null,
          builder: (state) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...options.map((o) => RadioListTile<String>(
                    value: o,
                    groupValue: _answers[id] as String?,
                    title: Text(o, style: const TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) {
                      setState(() => _answers[id] = v);
                      state.didChange(v);
                    },
                  )),
              if (state.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(state.errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                ),
            ],
          ),
        );
        break;
      case 'checkboxes':
        input = FormField<List<String>>(
          initialValue: (_answers[id] as List?)?.cast<String>() ?? <String>[],
          validator: (v) =>
              required && (v == null || v.isEmpty) ? 'Please select at least one option' : null,
          builder: (state) {
            final selected = (_answers[id] as List?)?.cast<String>() ?? <String>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...options.map((o) => CheckboxListTile(
                      value: selected.contains(o),
                      title: Text(o, style: const TextStyle(fontSize: 13)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) {
                        final list = List<String>.from(selected);
                        if (v == true) {
                          list.add(o);
                        } else {
                          list.remove(o);
                        }
                        setState(() => _answers[id] = list);
                        state.didChange(list);
                      },
                    )),
                if (state.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(state.errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ),
              ],
            );
          },
        );
        break;
      default: // short_text
        final ctrl = _textControllers.putIfAbsent(id, () => TextEditingController());
        input = TextFormField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
          validator: (v) =>
              required && (v == null || v.trim().isEmpty) ? 'This field is required' : null,
          onChanged: (v) => _answers[id] = v,
        );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              children: required
                  ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                  : [],
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            )
          else
            const SizedBox(height: 6),
          input,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(_formTitle,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _error != null
                          ? Text(_error!, style: const TextStyle(color: Colors.red))
                          : _alreadyRegistered
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text('You are already registered for this event.',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (_formDescription.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: Text(_formDescription,
                                              style:
                                                  const TextStyle(fontSize: 13, color: Colors.black54)),
                                        ),
                                      ..._fields.map(_buildField),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  if (_error == null && !_alreadyRegistered)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _primary, foregroundColor: Colors.white),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Submit Registration'),
                        ),
                      ]),
                    ),
                ],
              ),
      ),
    );
  }
}
