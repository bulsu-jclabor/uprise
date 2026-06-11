import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';  
import '../auth/role_router.dart';
import '../student/student_login.dart';
import '../../models/profile_model.dart';




// ─────────────────────────────────────────────────────────────
// Shared constants
// ─────────────────────────────────────────────────────────────
const kOrange = Color(0xFFFF6B00);
const kOrangeLight = Color(0xFFFFEDD5);
const kBg = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────
// ProfileModel — single source of truth
// ─────────────────────────────────────────────────────────────
class ProfileModel extends ChangeNotifier {
  String fullName = '';
  String studentId = '';
  String email = '';
  String mobile = '';
  String address = '';
  String photoUrl = '';
  // ── ID card fields ──
  String middleName = '';
  String dateOfBirth = '';
  String dateOfIssue = '';
  String sex = '';
  String maritalStatus = '';
  String placeOfBirth = '';
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
  fullName = data['fullName'] ?? '';
  studentId = data['studentId'] ?? '';
  mobile = data['mobile'] ?? '';
  address = data['address'] ?? '';
  photoUrl = data['photoUrl'] ?? '';
  middleName = data['middleName'] ?? '';
  dateOfBirth = data['dateOfBirth'] ?? '';
  dateOfIssue = data['dateOfIssue'] ?? '';
  sex = data['sex'] ?? '';
  maritalStatus = data['maritalStatus'] ?? '';
  placeOfBirth = data['placeOfBirth'] ?? '';
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
    required String fullName,
    required String email,
    required String mobile,
    required String address,
    String? photoUrl,
    String? middleName,
    String? dateOfBirth,
    String? dateOfIssue,
    String? sex,
    String? maritalStatus,
    String? placeOfBirth,
  }) async {
    this.fullName = fullName;
    this.email = email;
    this.mobile = mobile;
    this.address = address;
    if (photoUrl != null) this.photoUrl = photoUrl;
    if (middleName != null) this.middleName = middleName;
    if (dateOfBirth != null) this.dateOfBirth = dateOfBirth;
    if (dateOfIssue != null) this.dateOfIssue = dateOfIssue;
    if (sex != null) this.sex = sex;
    if (maritalStatus != null) this.maritalStatus = maritalStatus;
    if (placeOfBirth != null) this.placeOfBirth = placeOfBirth;

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
      'fullName': fullName,
      'studentId': studentId,
      'email': email,
      'mobile': mobile,
      'address': address,
      'photoUrl': this.photoUrl,
      'middleName': this.middleName,
      'dateOfBirth': this.dateOfBirth,
      'dateOfIssue': this.dateOfIssue,
      'sex': this.sex,
      'maritalStatus': this.maritalStatus,
      'placeOfBirth': this.placeOfBirth,
    }, SetOptions(merge: true));
  }
}
    notifyListeners();
  }
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
                                  ? Image.network(
                                      _profile.photoUrl,
                                      fit: BoxFit.cover,
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
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                  color: kOrange, shape: BoxShape.circle),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 14),
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
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditProfileScreen(profile: _profile),
                                ),
                              ),
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
                              colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
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

                // ── Events Registered (DYNAMIC FROM FIRESTORE) ──
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
                              // Navigate to My Events tab
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('View all events - Coming Soon'),
                                  duration: Duration(seconds: 2),
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
                  child: TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const StudentLogin()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
// Personal Identity Screen
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
            _IdCard1(profile: profile),
            const SizedBox(height: 16),
            _IdCard2(profile: profile),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showDownloadPreview(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Download ID',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Download Preview Bottom Sheet ──
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
          Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: _IdCard2(profile: profile),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: _IdCard1(profile: profile),
              ),
            ],
          ),
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
    );
  }
}

// ── ID Card 1: Personal Info ──
class _IdCard1 extends StatelessWidget {
  final ProfileModel profile;
  const _IdCard1({required this.profile});

  @override
  Widget build(BuildContext context) {
    final nameParts = profile.fullName.trim().split(' ');
    final lastName =
        nameParts.length > 1 ? nameParts.last.toUpperCase() : '';
    final firstName = nameParts.first.toUpperCase();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                    color: kOrange, shape: BoxShape.circle),
                child: const Icon(Icons.local_fire_department,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 6),
              const Text('UPRISE',
                  style: TextStyle(
                      color: kOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          Text(profile.studentId,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CHANGED: use profile.photoUrl instead of hardcoded URL ──
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: profile.photoUrl.isNotEmpty
                    ? Image.network(
                        profile.photoUrl,
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C8A0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person,
                              size: 40, color: Colors.white),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5C8A0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person,
                            size: 40, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IdFieldWidget(label: 'LAST NAME', value: lastName),
                    const SizedBox(height: 10),
                    _IdFieldWidget(label: 'GIVEN NAMES', value: firstName),
                    const SizedBox(height: 10),
                    _IdFieldWidget(
                        label: 'MIDDLE NAME',
                        value: profile.middleName.isNotEmpty
                            ? profile.middleName.toUpperCase()
                            : '—'),
                    const SizedBox(height: 10),
                    _IdFieldWidget(
                        label: 'DATE OF BIRTH',
                        value: profile.dateOfBirth.isNotEmpty
                            ? profile.dateOfBirth.toUpperCase()
                            : '—'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── ID Card 2: Additional Info + QR ──
class _IdCard2 extends StatelessWidget {
  final ProfileModel profile;
  const _IdCard2({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IdFieldWidget(
                        label: 'DATE OF ISSUE',
                        value: profile.dateOfIssue.isNotEmpty
                            ? profile.dateOfIssue.toUpperCase()
                            : '—'),
                    const SizedBox(height: 12),
                    _IdFieldWidget(
                        label: 'SEX',
                        value: profile.sex.isNotEmpty
                            ? profile.sex.toUpperCase()
                            : '—'),
                    const SizedBox(height: 12),
                    _IdFieldWidget(
                        label: 'MARITAL STATUS',
                        value: profile.maritalStatus.isNotEmpty
                            ? profile.maritalStatus.toUpperCase()
                            : '—'),
                    const SizedBox(height: 12),
                    _IdFieldWidget(
                        label: 'PLACE OF BIRTH',
                        value: profile.placeOfBirth.isNotEmpty
                            ? profile.placeOfBirth.toUpperCase()
                            : '—'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              QrImageView(
                data: profile.studentId.isNotEmpty
                    ? profile.studentId
                    : 'N/A',
                version: QrVersions.auto,
                size: 120,
                backgroundColor: Colors.white,
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  border: Border.all(color: kOrange, width: 2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.local_fire_department,
                  color: kOrange, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Edit Profile Screen
// ─────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  final ProfileModel profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _dateOfBirthCtrl;
  late final TextEditingController _dateOfIssueCtrl;
  late final TextEditingController _sexCtrl;
  late final TextEditingController _maritalStatusCtrl;
  late final TextEditingController _placeOfBirthCtrl;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl =
        TextEditingController(text: widget.profile.fullName);
    _emailCtrl =
        TextEditingController(text: widget.profile.email);
    _mobileCtrl =
        TextEditingController(text: widget.profile.mobile);
    _addressCtrl =
        TextEditingController(text: widget.profile.address);
    _middleNameCtrl =
        TextEditingController(text: widget.profile.middleName);
    _dateOfBirthCtrl =
        TextEditingController(text: widget.profile.dateOfBirth);
    _dateOfIssueCtrl =
        TextEditingController(text: widget.profile.dateOfIssue);
    _sexCtrl =
        TextEditingController(text: widget.profile.sex);
    _maritalStatusCtrl =
        TextEditingController(text: widget.profile.maritalStatus);
    _placeOfBirthCtrl =
        TextEditingController(text: widget.profile.placeOfBirth);
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _middleNameCtrl.dispose();
    _dateOfBirthCtrl.dispose();
    _dateOfIssueCtrl.dispose();
    _sexCtrl.dispose();
    _maritalStatusCtrl.dispose();
    _placeOfBirthCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.profile.update(
      fullName: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      dateOfBirth: _dateOfBirthCtrl.text.trim(),
      dateOfIssue: _dateOfIssueCtrl.text.trim(),
      sex: _sexCtrl.text.trim(),
      maritalStatus: _maritalStatusCtrl.text.trim(),
      placeOfBirth: _placeOfBirthCtrl.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: kOrange,
      ),
    );
    Navigator.pop(context);
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
                                ? Image.network(
                                    widget.profile.photoUrl,
                                    fit: BoxFit.cover,
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
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                                color: kOrange, shape: BoxShape.circle),
                            child: const Icon(Icons.edit,
                                color: Colors.white, size: 13),
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
                    label: 'Full Name',
                    controller: _fullNameCtrl,
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
                    label: 'Middle Name',
                    controller: _middleNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Date of Birth',
                    controller: _dateOfBirthCtrl,
                    icon: Icons.cake_outlined,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Date of Issue',
                    controller: _dateOfIssueCtrl,
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Sex',
                    controller: _sexCtrl,
                    icon: Icons.wc_outlined,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Marital Status',
                    controller: _maritalStatusCtrl,
                    icon: Icons.favorite_border_outlined,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    label: 'Place of Birth',
                    controller: _placeOfBirthCtrl,
                    icon: Icons.location_city_outlined,
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
// Settings Screen — SIMPLER DESIGN
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
                        backgroundImage: widget.profile.photoUrl.isNotEmpty
                            ? NetworkImage(widget.profile.photoUrl)
                            : null,
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
    );
  }
}

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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool show;
  final IconData icon;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.controller,
    required this.show,
    required this.icon,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: Icon(
              show ? Icons.visibility_off_outlined : icon,
              size: 18,
              color: Colors.grey),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        const SizedBox(height: 1),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8));
  }
}

class _ControlPanelItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ControlPanelItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: kOrangeLight,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: kOrange, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}