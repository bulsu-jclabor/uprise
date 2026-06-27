import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uprise/models/event_model.dart';

class EventProvider extends ChangeNotifier {
  List<EventModel> _registeredEvents = [];
  EventModel? _earliestEvent;
  bool _isLoading = false;

  List<EventModel> get registeredEvents => _registeredEvents;
  EventModel? get earliestEvent => _earliestEvent;
  bool get isLoading => _isLoading;

  // Load ALL registered events ng student
  Future<void> loadRegisteredEvents() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // STEP 1: Kunin ang lahat ng registrations ng student
      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (registrationsSnapshot.docs.isEmpty) {
        _registeredEvents = [];
        _earliestEvent = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // STEP 2: Kunin ang lahat ng event IDs
      final List<String> eventIds = registrationsSnapshot.docs
          .map((doc) => doc['eventId'] as String)
          .toList();

      // STEP 3: Kunin ang lahat ng events gamit ang event IDs
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where(FieldPath.documentId, whereIn: eventIds)
          .get();

      if (eventsSnapshot.docs.isEmpty) {
        _registeredEvents = [];
        _earliestEvent = null;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // STEP 4: I-convert sa EventModel gamit ang existing fromFirestore
      final now = DateTime.now();
      final List<EventModel> events = [];

      for (var doc in eventsSnapshot.docs) {
        final event = EventModel.fromFirestore(doc);
        
        // ⭐ GAMITIN ANG fullDateTime PARA SA COMPARISON ⭐
        // Only include upcoming events
        if (event.fullDateTime.isAfter(now)) {
          events.add(event);
        }
      }

      // STEP 5: I-sort by fullDateTime (earliest first)
      events.sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));

      // STEP 6: I-save ang lahat ng events
      _registeredEvents = events;

      // STEP 7: Kunin ang PINAKAMAUNA (earliest)
      _earliestEvent = events.isNotEmpty ? events.first : null;

      _isLoading = false;
      notifyListeners();
      
      print('📊 Total registered events: ${events.length}');
      if (_earliestEvent != null) {
        print('📅 Earliest event: ${_earliestEvent!.title}');
        print('📅 Event date: ${_earliestEvent!.fullDateTime}');
        print('📅 Start time: ${_earliestEvent!.startTime}');
      } else {
        print('📅 No upcoming events');
      }

    } catch (e) {
      print('❌ Error loading registered events: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh after registration
  Future<void> refreshRegisteredEvents() async {
    await loadRegisteredEvents();
  }
}