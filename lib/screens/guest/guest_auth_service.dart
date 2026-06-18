// lib/screens/guest/guest_auth_service.dart
//
// Shared guest authentication state.
//
// GuestMode:
//   visitor       — browsing without an account
//   authenticated — approved guest who has logged in
//
// GuestAuthService:
//   - persists the authenticated session via SharedPreferences
//   - provides a singleton notifier so any widget can rebuild when the
//     auth state changes
//

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
//  MODE ENUM
// ─────────────────────────────────────────────────────────────
enum GuestMode {
  visitor,
  authenticated,
}

// ─────────────────────────────────────────────────────────────
//  SESSION KEYS
// ─────────────────────────────────────────────────────────────
const _kGuestDocId   = 'guest_auth_doc_id';
const _kGuestEmail   = 'guest_auth_email';
const _kGuestName    = 'guest_auth_name';
const _kGuestMode    = 'guest_auth_mode'; // 'visitor' | 'authenticated'

// ─────────────────────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────────────────────
class GuestAuthService extends ChangeNotifier {
  // Singleton
  static final GuestAuthService _instance = GuestAuthService._();
  factory GuestAuthService() => _instance;
  GuestAuthService._();

  // Current state
  GuestMode   _mode     = GuestMode.visitor;
  String?     _docId;
  String?     _email;
  String?     _fullName;
  bool        _loaded   = false;

  GuestMode   get mode     => _mode;
  String?     get docId    => _docId;
  String?     get email    => _email;
  String?     get fullName => _fullName;
  bool        get isAuthenticated => _mode == GuestMode.authenticated;
  bool        get loaded   => _loaded;

  // ── Load from SharedPreferences ──────────────────────────
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kGuestMode) ?? 'visitor';
    _mode     = modeStr == 'authenticated'
        ? GuestMode.authenticated : GuestMode.visitor;
    _docId    = prefs.getString(_kGuestDocId);
    _email    = prefs.getString(_kGuestEmail);
    _fullName = prefs.getString(_kGuestName);
    _loaded   = true;
    notifyListeners();
  }

  // ── Save authenticated session ───────────────────────────
  static Future<void> saveSession({
    required String docId,
    required String email,
    required String fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kGuestDocId,  docId);
    await prefs.setString(_kGuestEmail,  email);
    await prefs.setString(_kGuestName,   fullName);
    await prefs.setString(_kGuestMode,   'authenticated');

    final svc = GuestAuthService();
    svc._mode     = GuestMode.authenticated;
    svc._docId    = docId;
    svc._email    = email;
    svc._fullName = fullName;
    svc.notifyListeners();
  }

  // ── Clear session (logout) ───────────────────────────────
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGuestDocId);
    await prefs.remove(_kGuestEmail);
    await prefs.remove(_kGuestName);
    await prefs.setString(_kGuestMode, 'visitor');

    final svc = GuestAuthService();
    svc._mode     = GuestMode.visitor;
    svc._docId    = null;
    svc._email    = null;
    svc._fullName = null;
    svc.notifyListeners();
  }
}