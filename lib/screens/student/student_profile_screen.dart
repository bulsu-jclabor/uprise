import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../auth/role_router.dart';
import '../student/student_login.dart';
import '../student/student_events_screen.dart';
import '../../models/profile_model.dart';

// ─────────────────────────────────────────────────────────────
// Shared constants - UNIFORM ORANGE
// ─────────────────────────────────────────────────────────────
const kOrange = Colors.orange;
const kOrangeLight = Color(0xFFFFEDD5);
const kBg = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────
// ProfileModel — single source of truth
// ─────────────────────────────────────────────────────────────
class ProfileModel extends ChangeNotifier {
  // ── Name is split into 3 fields. `fullName` below is a derived
  //    getter kept for any other screen in the app that still reads
  //    profile.fullName — it composes the 3 parts automatically. ──
  String firstName = '';
  String middleName = '';
  String lastName = '';

  String get fullName {
    final parts = [firstName, middleName, lastName]
        .where((p) => p.trim().isNotEmpty);
    return parts.join(' ');
  }

  // "Dela Cruz, Juan Miguel" style — handy for ID-card last-name-first display
  String get fullNameLastFirst {
    if (lastName.trim().isEmpty) return fullName;
    final first = [firstName, middleName]
        .where((p) => p.trim().isNotEmpty)
        .join(' ');
    return first.isEmpty ? lastName : '$lastName, $first';
  }

  String studentId = '';
  String email = '';
  String mobile = '';
  String address = '';
  String photoUrl = '';
  // ── ID card fields ──
  String course = '';
  String major = '';
  String yearLevel = '';
  String department = '';
  // ── Organization ──
  String orgId = '';
  String orgName = '';

  ProfileModel() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      email = user.email ?? '';

      final snapshot = await FirebaseFirestore.instance
    .collection('students')
    .where('uid', isEqualTo: user.uid)
    .limit(1)
    .get();

if (snapshot.docs.isNotEmpty) {
  final data = snapshot.docs.first.data();
  firstName = data['firstName'] ?? '';
  middleName = data['middleName'] ?? '';
  lastName = data['lastName'] ?? '';
  studentId = data['studentId'] ?? '';
  mobile = data['mobile'] ?? '';
  address = data['address'] ?? '';
  photoUrl = data['photoUrl'] ?? '';
  course = data['course'] ?? '';
  major = data['major'] ?? '';
  yearLevel = data['yearLevel'] ?? '';
  department = data['department'] ?? '';
  orgId = data['orgId'] ?? '';

  // Resolve org name if orgId is set
  if (orgId.isNotEmpty) {
    final orgSnap = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .get();
    if (orgSnap.exists) {
      orgName = orgSnap.data()?['orgName'] ?? orgSnap.data()?['name'] ?? '';
    }
  }
}

      notifyListeners();
    }
  }

  Future<void> update({
    required String firstName,
    required String middleName,
    required String lastName,
    required String email,
    required String mobile,
    required String address,
    String? photoUrl,
    String? course,
    String? major,
    String? yearLevel,
    String? department,
  }) async {
    this.firstName = firstName;
    this.middleName = middleName;
    this.lastName = lastName;
    this.email = email;
    this.mobile = mobile;
    this.address = address;
    if (photoUrl != null) this.photoUrl = photoUrl;
    if (course != null) this.course = course;
    if (major != null) this.major = major;
    if (yearLevel != null) this.yearLevel = yearLevel;
    if (department != null) this.department = department;

    final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final snapshot = await FirebaseFirestore.instance
      .collection('students')
      .where('uid', isEqualTo: user.uid)
      .limit(1)
      .get();

  if (snapshot.docs.isNotEmpty) {
    final docRef = snapshot.docs.first.reference;
    await docRef.set({
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'studentId': studentId,
      'email': email,
      'mobile': mobile,
      'address': address,
      'photoUrl': this.photoUrl,
      'course': this.course,
      'major': this.major,
      'yearLevel': this.yearLevel,
      'department': this.department,
    }, SetOptions(merge: true));
  }
}
    notifyListeners();
  }

  // ── Update just the photo (used by the camera/edit icon) ──
  // Kept separate from update() so changing the photo doesn't require
  // re-passing every other field. Saves to Firestore immediately and
  // calls notifyListeners() so every screen watching this model
  // (Profile screen + ID card) refreshes automatically.
  Future<void> updatePhotoUrl(String url) async {
    photoUrl = url;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.set(
          {'photoUrl': url},
          SetOptions(merge: true),
        );
      }
    }

    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────
// Shared helper — pick a new photo from the gallery and save it
// directly on the shared ProfileModel. No Firebase Storage (which
// needs a paid Blaze plan) — instead the photo is shrunk and stored
// as a base64 string right inside the student's Firestore document,
// which is free on the normal Firestore tier. Because every screen
// (Profile header + ID card) listens to the same ProfileModel
// instance, calling this from anywhere instantly updates both
// places — no extra wiring needed.
// ─────────────────────────────────────────────────────────────
Future<void> _pickAndUploadPhoto(
    BuildContext context, ProfileModel profile) async {
  XFile? picked;
  try {
    final picker = ImagePicker();
    picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 400, // kept small so the base64 string stays well under
                     // Firestore's 1 MiB per-document limit
    );
  } catch (e) {
    // Picker itself failed (e.g. permission denied)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
    return;
  }
  if (picked == null) return; // user cancelled

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        const Center(child: CircularProgressIndicator(color: kOrange)),
  );

  try {
    // readAsBytes() works the same on mobile, web, and desktop —
    // unlike dart:io's File(), which breaks on Flutter Web.
    final Uint8List bytes = await picked.readAsBytes();

    if (bytes.lengthInBytes > 400 * 1024) {
      throw Exception(
          'That photo is too large. Please pick a smaller image.');
    }

    final String dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    await profile.updatePhotoUrl(dataUrl);

    if (context.mounted) {
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated!'),
          backgroundColor: kOrange,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    }
  }
}

// ── Renders profile.photoUrl whether it's a base64 data: string
//    (new uploads) or a plain network URL (legacy data) ──
class _ProfileImage extends StatelessWidget {
  final String photoUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?) errorBuilder;

  const _ProfileImage({
    required this.photoUrl,
    required this.errorBuilder,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl.startsWith('data:image')) {
      try {
        final bytes = base64Decode(photoUrl.split(',').last);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      } catch (e, st) {
        return errorBuilder(context, e, st);
      }
    }
    return Image.network(
      photoUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
}

// ── Same idea, but as an ImageProvider for widgets like CircleAvatar
//    that take backgroundImage instead of a child Image widget ──
ImageProvider? _profileImageProvider(String photoUrl) {
  if (photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('data:image')) {
    try {
      return MemoryImage(base64Decode(photoUrl.split(',').last));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(photoUrl);
}

// ─────────────────────────────────────────────────────────────
// Student Profile Screen
// ─────────────────────────────────────────────────────────────
class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final ProfileModel _profile = ProfileModel();

  // Helper method to fetch events by IDs
  Future<List<QueryDocumentSnapshot>> _fetchEventsByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];
    
    // Firestore whereIn supports max 10 items
    final chunks = <List<String>>[];
    for (var i = 0; i < eventIds.length; i += 10) {
      chunks.add(eventIds.sublist(
          i, i + 10 > eventIds.length ? eventIds.length : i + 10));
    }
    
    final results = <QueryDocumentSnapshot>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snap.docs);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _profile,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text('Profile',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: kOrange),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SettingsScreen(profile: _profile)),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // ── Header ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF5C8A0),
                              border:
                                  Border.all(color: Colors.white, width: 3),
                            ),
                            child: ClipOval(
                              child: _profile.photoUrl.isNotEmpty
                                  ? _ProfileImage(
                                      photoUrl: _profile.photoUrl,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person,
                                              size: 50,
                                              color: Colors.white),
                                    )
                                  : const Icon(Icons.person,
                                      size: 50, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  _pickAndUploadPhoto(context, _profile),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                    color: kOrange, shape: BoxShape.circle),
                                child: const Icon(Icons.edit,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_profile.fullName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_profile.studentId,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(_profile.email,
                          style: const TextStyle(
                              fontSize: 13, color: kOrange)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditProfileScreen(profile: _profile),
                                  ),
                                );
                                // If a new name was returned, refresh the profile
                                if (result != null && result is String) {
                                  _profile._loadUserData();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                              child: const Text('Edit Profile',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: kOrangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        PersonalIdentityScreen(
                                            profile: _profile)),
                              ),
                              icon: const Text('ID',
                                  style: TextStyle(
                                      color: kOrange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Organization ──
                if (_profile.orgName.isNotEmpty)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Organization',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.orange, Color(0xFFFFA726)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.groups,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ASSIGNED ORGANIZATION',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white70,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _profile.orgName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_profile.orgName.isNotEmpty) const SizedBox(height: 12),

                // ── Contact Information ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Contact Information',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(profile: _profile),
                              ),
                            ),
                            child: const Text('Edit',
                                style:
                                    TextStyle(color: kOrange, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ContactRow(
                          icon: Icons.phone_android_outlined,
                          label: 'MOBILE',
                          value: _profile.mobile),
                      const SizedBox(height: 14),
                      _ContactRow(
                          icon: Icons.location_on_outlined,
                          label: 'CAMPUS ADDRESS',
                          value: _profile.address),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Events Registered ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Events Registered',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const StudentEventsScreen(
                                          initialTabIndex: 1),
                                ),
                              );
                            },
                            child: const Text('See All',
                                style: TextStyle(color: kOrange, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Dynamic events list from Firestore
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('registrations')
                            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                            .snapshots(),
                        builder: (context, regSnapshot) {
                          if (regSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          if (!regSnapshot.hasData || regSnapshot.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No registered events yet',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            );
                          }
                          
                          final registrations = regSnapshot.data!.docs;
                          
                          // Get event IDs from registrations
                          final eventIds = registrations.map((doc) => doc['eventId'] as String).toList();
                          
                          if (eventIds.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No registered events yet',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ),
                            );
                          }
                          
                          return FutureBuilder<List<QueryDocumentSnapshot>>(
                            future: _fetchEventsByIds(eventIds),
                            builder: (context, eventSnapshot) {
                              if (eventSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              
                              final events = eventSnapshot.data ?? [];
                              
                              if (events.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'No registered events yet',
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ),
                                );
                              }
                              
                              // Show only first 3 events
                              final displayEvents = events.take(3).toList();
                              
                              return Column(
                                children: displayEvents.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final doc = entry.value;
                                  final eventData = doc.data() as Map<String, dynamic>;
                                  
                                  // Determine if event is upcoming or past
                                  final eventDate = eventData['date'] is Timestamp
                                      ? (eventData['date'] as Timestamp).toDate()
                                      : DateTime.tryParse(eventData['date']?.toString() ?? '');
                                  final isUpcoming = eventDate != null && eventDate.isAfter(DateTime.now());
                                  final badgeText = isUpcoming ? 'UPCOMING' : 'PAST';
                                  final badgeColor = isUpcoming ? const Color(0xFF2196F3) : Colors.grey;
                                  
                                  // Format date display
                                  String displayDate = '';
                                  if (eventDate != null) {
                                    if (isUpcoming && eventDate.difference(DateTime.now()).inDays == 1) {
                                      displayDate = 'Tomorrow • ${eventData['startTime'] ?? '9:00 AM'}';
                                    } else {
                                      displayDate = '${DateFormat('MMM d, yyyy').format(eventDate)} • ${eventData['startTime'] ?? '9:00 AM'}';
                                    }
                                  }
                                  
                                  return Column(
                                    children: [
                                      _EventCard(
                                        title: eventData['title'] ?? 'Untitled Event',
                                        subtitle: displayDate,
                                        badge: badgeText,
                                        badgeColor: badgeColor,
                                        imageUrl: eventData['bannerUrl'] ?? '',
                                      ),
                                      if (index < displayEvents.length - 1) const Divider(height: 1),
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── RED LOG OUT BUTTON ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const StudentLogin()),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.logout, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Personal Identity Screen — shows the ID card's front and back
// stacked together (no flip/tap needed)
// ─────────────────────────────────────────────────────────────
class PersonalIdentityScreen extends StatelessWidget {
  final ProfileModel profile;
  const PersonalIdentityScreen({super.key, required this.profile});

  void _showDownloadPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IdDownloadPreviewSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder makes this screen listen to the shared ProfileModel,
    // so if the photo or any ID field changes (e.g. while this screen is
    // still on the navigation stack), the ID card updates immediately —
    // no need to re-open the screen to see the latest data.
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Personal Identity',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 18)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(height: 2, color: kOrange),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _IdCardLabel(text: 'FRONT'),
                const SizedBox(height: 8),
                _IdCard1(profile: profile),
                const SizedBox(height: 20),
                _IdCardLabel(text: 'BACK'),
                const SizedBox(height: 8),
                _IdCard2(profile: profile),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDownloadPreview(context),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    label: const Text('Download ID',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Small "FRONT" / "BACK" eyebrow label used above each card
class _IdCardLabel extends StatelessWidget {
  final String text;
  const _IdCardLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ── Download Preview Bottom Sheet — shows front & back stacked ──
class _IdDownloadPreviewSheet extends StatelessWidget {
  final ProfileModel profile;
  const _IdDownloadPreviewSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8E8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2)),
            ),
            _IdCardLabel(text: 'FRONT'),
            const SizedBox(height: 8),
            _IdCard1(profile: profile),
            const SizedBox(height: 20),
            _IdCardLabel(text: 'BACK'),
            const SizedBox(height: 8),
            _IdCard2(profile: profile),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ID downloaded successfully!'),
                      backgroundColor: kOrange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Download',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FRONT of ID: orange header banner, photo, last/first/middle name,
//    student number, major/program ──
class _IdCard1 extends StatelessWidget {
  final ProfileModel profile;
  const _IdCard1({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Orange header band ──
          Container(
            color: kOrange,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _HeaderBadge(
                  assetPath: 'assets/images/bsu_logo.png',
                  icon: Icons.school,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('BULACAN STATE UNIVERSITY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.4)),
                      SizedBox(height: 2),
                      Text('OFFICIAL STUDENT IDENTIFICATION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                              fontSize: 8,
                              letterSpacing: 0.6)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _HeaderBadge(
                  assetPath: 'assets/images/logo.png',
                  icon: Icons.local_fire_department,
                ),
              ],
            ),
          ),

          // ── Photo + name fields, each row paired with its
          //    corresponding ID detail (last name/student no.,
          //    first name/program, middle name/major) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: profile.photoUrl.isNotEmpty
                      ? _ProfileImage(
                          photoUrl: profile.photoUrl,
                          width: 84,
                          height: 104,
                          errorBuilder: (_, __, ___) => _PhotoPlaceholder(),
                        )
                      : _PhotoPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'LAST NAME',
                                value: profile.lastName.isNotEmpty
                                    ? profile.lastName.toUpperCase()
                                    : '—'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'STUDENT NO.',
                                value: profile.studentId.isNotEmpty
                                    ? profile.studentId
                                    : '—'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'FIRST NAME',
                                value: profile.firstName.isNotEmpty
                                    ? profile.firstName.toUpperCase()
                                    : '—'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'PROGRAM',
                                value: profile.course.isNotEmpty
                                    ? profile.course.toUpperCase()
                                    : '—'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'MIDDLE NAME',
                                value: profile.middleName.isNotEmpty
                                    ? profile.middleName.toUpperCase()
                                    : '—'),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _IdFieldWidget(
                                label: 'MAJOR',
                                value: profile.major.isNotEmpty
                                    ? profile.major.toUpperCase()
                                    : '—'),
                          ),
                        ],
                      ),
                    ],
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

// ── BACK of ID: year level, college/department, QR code, validity strip ──
class _IdCard2 extends StatelessWidget {
  final ProfileModel profile;
  const _IdCard2({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Orange header band ──
          Container(
            color: kOrange,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: const Text('ACADEMIC INFORMATION',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.6)),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IdFieldWidget(
                          label: 'YEAR LEVEL',
                          value: profile.yearLevel.isNotEmpty
                              ? profile.yearLevel.toUpperCase()
                              : '—'),
                      const SizedBox(height: 16),
                      _IdFieldWidget(
                          label: 'COLLEGE / DEPARTMENT',
                          value: profile.department.isNotEmpty
                              ? profile.department.toUpperCase()
                              : '—'),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: QrImageView(
                    data: profile.studentId.isNotEmpty
                        ? profile.studentId
                        : 'N/A',
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ── Validity strip ──
          Container(
            width: double.infinity,
            color: kOrangeLight,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_outlined, size: 14, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  'VALID FOR A.Y. ${_currentAcademicYear()} · NON-TRANSFERABLE',
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _currentAcademicYear() {
    final now = DateTime.now();
    // Academic year starts around June/August in PH — adjust the cutoff
    // month if your school year starts differently.
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    return '$startYear-${startYear + 1}';
  }
}

// ── Small reusable bits used by the new ID card design ──

class _HeaderBadge extends StatelessWidget {
  final String assetPath;
  final IconData icon;
  const _HeaderBadge({required this.assetPath, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFFF5C8A0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.person, size: 42, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Profile Screen — now split into first / middle / last name
// ─────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Fixed list of majors students can choose from. Add more here
  //    if the program offers additional tracks. ──
  static const List<String> kMajorOptions = [
    'WMAD',
    'DBA',
    'Infrastructure',
  ];

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _courseCtrl;
  late final TextEditingController _yearLevelCtrl;
  late final TextEditingController _departmentCtrl;
  String? _selectedMajor;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl =
        TextEditingController(text: widget.profile.firstName);
    _middleNameCtrl =
        TextEditingController(text: widget.profile.middleName);
    _lastNameCtrl =
        TextEditingController(text: widget.profile.lastName);
    _emailCtrl =
        TextEditingController(text: widget.profile.email);
    _mobileCtrl =
        TextEditingController(text: widget.profile.mobile);
    _addressCtrl =
        TextEditingController(text: widget.profile.address);
    _courseCtrl =
        TextEditingController(text: widget.profile.course);
    _yearLevelCtrl =
        TextEditingController(text: widget.profile.yearLevel);
    _departmentCtrl =
        TextEditingController(text: widget.profile.department);
    // Only pre-select if it matches one of the known options —
    // protects against stale/legacy free-text values in Firestore.
    _selectedMajor = kMajorOptions.contains(widget.profile.major)
        ? widget.profile.major
        : null;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _courseCtrl.dispose();
    _yearLevelCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final newFirst = _firstNameCtrl.text.trim();
    final newMiddle = _middleNameCtrl.text.trim();
    final newLast = _lastNameCtrl.text.trim();

    widget.profile.update(
      firstName: newFirst,
      middleName: newMiddle,
      lastName: newLast,
      email: _emailCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      course: _courseCtrl.text.trim(),
      major: _selectedMajor ?? '',
      yearLevel: _yearLevelCtrl.text.trim(),
      department: _departmentCtrl.text.trim(),
    );

    // Update Firebase Auth display name using the composed full name
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final displayName =
          [newFirst, newMiddle, newLast].where((p) => p.isNotEmpty).join(' ');
      user.updateDisplayName(displayName);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: kOrange,
      ),
    );

    // Return the new full name when popping
    Navigator.pop(context, widget.profile.fullName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header preview (live from model) ──
            AnimatedBuilder(
              animation: widget.profile,
              builder: (_, __) => Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF5C8A0),
                            border:
                                Border.all(color: Colors.white, width: 3),
                          ),
                          child: ClipOval(
                            child: widget.profile.photoUrl.isNotEmpty
                                ? _ProfileImage(
                                    photoUrl: widget.profile.photoUrl,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person,
                                            size: 40, color: Colors.white),
                                  )
                                : const Icon(Icons.person,
                                    size: 40, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickAndUploadPhoto(
                                context, widget.profile),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                  color: kOrange, shape: BoxShape.circle),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.profile.fullName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(widget.profile.studentId,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(widget.profile.email,
                        style:
                            const TextStyle(fontSize: 12, color: kOrange)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Personal Information ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  _EditField(
                    label: 'First Name',
                    controller: _firstNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Middle Name',
                    controller: _middleNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Last Name',
                    controller: _lastNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Student ID',
                    controller: TextEditingController(
                        text: widget.profile.studentId),
                    icon: Icons.badge_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Email Address',
                    controller: _emailCtrl,
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── ID Information ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ID Information',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  _EditField(
                    label: 'Course / Program',
                    controller: _courseCtrl,
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 14),
                  _MajorDropdownField(
                    label: 'Major',
                    icon: Icons.workspace_premium_outlined,
                    value: _selectedMajor,
                    options: kMajorOptions,
                    onChanged: (value) {
                      setState(() => _selectedMajor = value);
                    },
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Year Level',
                    controller: _yearLevelCtrl,
                    icon: Icons.stairs_outlined,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'College / Department',
                    controller: _departmentCtrl,
                    icon: Icons.account_balance_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Contact Information ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Information',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  _EditField(
                    label: 'Mobile Number',
                    controller: _mobileCtrl,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Campus Address',
                    controller: _addressCtrl,
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Update Profile',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
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
// Settings Screen
// ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  final ProfileModel profile;

  const SettingsScreen({
    super.key,
    required this.profile,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPwCtrl = TextEditingController(text: '••••••');
  final _newPwCtrl = TextEditingController(text: '••••••');

  bool _showCurrentPw = false;
  bool _showNewPw = false;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    super.dispose();
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: kOrange),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [

            // ───────────────── Profile Card ─────────────────
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: widget.profile,
                builder: (_, __) {
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: kOrangeLight,
                        backgroundImage:
                            _profileImageProvider(widget.profile.photoUrl),
                        child: widget.profile.photoUrl.isEmpty
                            ? const Icon(Icons.person,
                                size: 42, color: kOrange)
                            : null,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        widget.profile.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        widget.profile.email,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditProfileScreen(
                                  profile: widget.profile,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ───────────────── General Settings ─────────────────
            Container(
              color: Colors.white,
              child: Column(
                children: [

                  _buildTile(
                    icon: Icons.person_outline,
                    title: 'Admin Profile',
                    subtitle: 'Manage your information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            profile: widget.profile,
                          ),
                        ),
                      );
                    },
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  _buildTile(
                    icon: Icons.tune_outlined,
                    title: 'System Preferences',
                    subtitle: 'App settings and behavior',
                    onTap: () {},
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  _buildTile(
                    icon: Icons.shield_outlined,
                    title: 'Security Settings',
                    subtitle: 'Privacy and protection',
                    onTap: () {},
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  _buildTile(
                    icon: Icons.history_outlined,
                    title: 'Audit Logs',
                    subtitle: 'Recent activities',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ───────────────── Password Section ─────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  const Text(
                    'Change Password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _EditField(
                    label: 'Current Password',
                    controller: _currentPwCtrl,
                    icon: Icons.lock_outline,
                    isPassword: true,
                    showPassword: _showCurrentPw,
                    onTogglePassword: () {
                      setState(() {
                        _showCurrentPw =
                            !_showCurrentPw;
                      });
                    },
                  ),

                  const SizedBox(height: 14),

                  _EditField(
                    label: 'New Password',
                    controller: _newPwCtrl,
                    icon: Icons.lock_reset_outlined,
                    isPassword: true,
                    showPassword: _showNewPw,
                    onTogglePassword: () {
                      setState(() {
                        _showNewPw = !_showNewPw;
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Credentials updated!',
                            ),
                            backgroundColor: kOrange,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Update Credentials',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
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
// Reusable small widgets
// ─────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool readOnly;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onTogglePassword;

  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.showPassword = false,
    this.onTogglePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          obscureText: isPassword && !showPassword,
          style: TextStyle(
              fontSize: 14,
              color: readOnly ? Colors.grey : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: Colors.grey),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor:
                readOnly ? const Color(0xFFF8F8F8) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kOrange),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dropdown field for picking the student's major, styled to match
//    _EditField above (same label style, icon, border, focus color) ──
class _MajorDropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _MajorDropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: Colors.grey),
            hintText: 'Select major',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kOrange),
            ),
          ),
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _IdFieldWidget extends StatelessWidget {
  final String label;
  final String value;
  const _IdFieldWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final String imageUrl;

  const _EventCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            color: Colors.grey[300],
            child: const Icon(Icons.event, color: Colors.grey),
          ),
        ),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badge,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor)),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }
}