import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/theme/app_theme.dart';
import '../../../auth_service.dart';

// Import your admin sections
import 'organization_management.dart';
import 'student_accounts.dart';
import 'adviser_roles.dart';
import 'event_proposals.dart';
import 'event_calendar.dart';
import 'letter_request.dart';
import 'external_account.dart';
import 'reports_management.dart';
import 'activity_logs.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotifications();
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();
        setState(() {
          _unreadNotifications = snapshot.docs.length;
          _notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'New Notification',
              'message': data['message'] ?? '',
              'timestamp': data['createdAt'],
              'isRead': data['isRead'] ?? false,
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      _fetchUnreadNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [UpriseColors.primaryDark, UpriseColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 30),
          Text(
            "UPRISE",
            style: GoogleFonts.beVietnamPro(
              color: UpriseColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'CICT Organization Management',
            style: GoogleFonts.beVietnamPro(color: UpriseColors.white.withOpacity(0.7), fontSize: 11),
          ),
          SizedBox(height: 30),
          Divider(color: UpriseColors.white.withOpacity(0.2), thickness: 1),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _titles.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? UpriseColors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _titles[index],
                      style: GoogleFonts.beVietnamPro(
                        color: UpriseColors.white,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: UpriseColors.white.withOpacity(0.2), thickness: 1),
          GestureDetector(
            onTap: () async {
              await _auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.logout, color: UpriseColors.white.withOpacity(0.7), size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: GoogleFonts.beVietnamPro(color: UpriseColors.white.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        children: [
          Text(
            _titles[_selectedIndex],
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w600, color: UpriseColors.charcoal),
          ),
          Spacer(),
          Container(
            width: 260,
            height: 40,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events, students...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                filled: true,
                fillColor: UpriseColors.lightGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          SizedBox(width: 16),
          // Notification Dropdown
          PopupMenuButton<String>(
            offset: Offset(0, 45),
            onOpened: () async => await _fetchUnreadNotifications(),
            onSelected: (value) async {
              if (value.startsWith('notification_')) {
                await _markNotificationAsRead(value.replaceFirst('notification_', ''));
              }
            },
            icon: Stack(
              children: [
                Icon(Icons.notifications_none, color: UpriseColors.darkGray, size: 22),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: UpriseColors.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$_unreadNotifications',
                        style: GoogleFonts.beVietnamPro(color: UpriseColors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('Notifications', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (_notifications.isEmpty)
                PopupMenuItem(
                  enabled: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No new notifications', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 12)),
                    ),
                  ),
                )
              else
                ..._notifications.map((notification) => PopupMenuItem(
                  value: 'notification_${notification['id']}',
                  child: Container(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['title'], style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                        SizedBox(height: 4),
                        Text(notification['message'], style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                        SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(notification['timestamp']),
                          style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray),
                        ),
                      ],
                    ),
                  ),
                )),
              PopupMenuItem(
                value: 'view_all',
                child: Center(
                  child: Text('View All Notifications', style: GoogleFonts.beVietnamPro(color: UpriseColors.accent, fontSize: 12)),
                ),
              ),
            ],
          ),
          SizedBox(width: 8),
          // Profile Popup Menu
          PopupMenuButton<String>(
            offset: Offset(0, 45),
            onSelected: (value) async {
              if (value == 'profile') _showProfileDialog();
              else if (value == 'settings') _showSettingsDialog();
              else if (value == 'logout') {
                await _auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: UpriseColors.lightGray,
                  radius: 18,
                  child: Icon(Icons.person, color: UpriseColors.primaryDark, size: 20),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FirebaseAuth.instance.currentUser?.displayName ?? 'Admin User',
                      style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13, color: UpriseColors.charcoal),
                    ),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? 'admin@cict.edu.ph',
                      style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray, size: 20),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: UpriseColors.darkGray),
                    SizedBox(width: 12),
                    Text('My Profile', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: UpriseColors.darkGray),
                    SizedBox(width: 12),
                    Text('Settings', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: UpriseColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }

  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final nameController = TextEditingController(text: user?.displayName ?? '');
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.person, color: UpriseColors.primaryDark),
                SizedBox(width: 8),
                Text('Admin Profile', style: GoogleFonts.beVietnamPro()),
              ],
            ),
            content: Container(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: UpriseColors.lightGray,
                    child: Icon(Icons.person, size: 50, color: UpriseColors.primaryDark),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: user?.email ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && user != null) {
                    await user.updateDisplayName(nameController.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Profile updated successfully')),
                    );
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsDialog() {
    bool notifications = true;
    bool darkMode = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.settings, color: UpriseColors.primaryDark),
                SizedBox(width: 8),
                Text('Settings', style: GoogleFonts.beVietnamPro()),
              ],
            ),
            content: Container(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text('Push Notifications'),
                    subtitle: Text('Receive notifications about events and updates'),
                    value: notifications,
                    onChanged: (value) {
                      setState(() => notifications = value);
                      _saveSetting('notifications', value);
                    },
                    activeColor: UpriseColors.primaryDark,
                  ),
                  Divider(),
                  SwitchListTile(
                    title: Text('Dark Mode'),
                    subtitle: Text('Switch to dark theme'),
                    value: darkMode,
                    onChanged: (value) {
                      setState(() => darkMode = value);
                      _saveSetting('darkMode', value);
                    },
                    activeColor: UpriseColors.primaryDark,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveSetting(String key, bool value) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(userId)
            .set({key: value}, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error saving setting: $e');
    }
  }

  final List<Widget> _screens = [
    DashboardHome(),
    OrganizationManagement(),
    StudentAccounts(),
    AdviserRoles(),
    EventProposals(),
    EventCalendar(),
    LetterRequest(),
    ExternalAccount(),
    ReportsManagement(),
    ActivityLogs(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Organization Management',
    'Student Accounts',
    'Adviser Roles',
    'Event Proposals',
    'College Event Calendar',
    'Letter Request',
    'External Account',
    'Reports Management',
    'Activity Logs',
  ];
}

// ============ DASHBOARD HOME WITH IMPROVED LOADING & UI ============
class DashboardHome extends StatefulWidget {
  @override
  _DashboardHomeState createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _selectedSemester = '2nd Semester 2024';
  String _selectedMonth = DateTime.now().month.toString();
  bool _chartDataLoaded = false;
  List<double> _cachedChartData = [42, 55, 68, 45, 72, 58]; // sample data for immediate display

  @override
  void initState() {
    super.initState();
    _preloadChartData();
  }

  Future<void> _preloadChartData() async {
    // We'll still fetch from Firestore, but show sample data while loading
    setState(() => _chartDataLoaded = false);
    // Actual fetch happens in the StreamBuilder; we just mark as not loaded initially
    // The StreamBuilder will update when data arrives.
  }

  Stream<QuerySnapshot> get _organizationsStream => FirebaseFirestore.instance
      .collection('organizations')
      .where('status', isEqualTo: 'active')
      .snapshots();
  
  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('status', isEqualTo: 'approved')
      .snapshots();
  
  Stream<QuerySnapshot> get _proposalsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('status', isEqualTo: 'pending')
      .snapshots();
  
  Stream<QuerySnapshot> get _reportsStream => FirebaseFirestore.instance
      .collection('reports')
      .where('status', isEqualTo: 'overdue')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrator Dashboard',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          SizedBox(height: 8),
          Text(
            "Welcome back. Here's what's happening today in the CICT community.",
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
          SizedBox(height: 28),

          // STAT CARDS (using real-time streams)
          Row(
            children: [
              Expanded(child: _buildStatCardStream('Active Organizations', _organizationsStream, UpriseColors.primaryDark, Icons.business)),
              SizedBox(width: 16),
              Expanded(child: _buildStatCardStream('Active Events', _eventsStream, UpriseColors.success, Icons.event)),
              SizedBox(width: 16),
              Expanded(child: _buildStatCardStream('Pending Proposals', _proposalsStream, UpriseColors.warning, Icons.pending_actions)),
              SizedBox(width: 16),
              Expanded(child: _buildStatCardStream('Overdue Reports', _reportsStream, UpriseColors.error, Icons.warning)),
            ],
          ),

          SizedBox(height: 32),

          // Semester Section with LINE CHART (will show sample data while loading)
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSemester,
                          style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w600, color: UpriseColors.charcoal),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Monthly completed events overview',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: UpriseColors.mediumGray),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedSemester,
                        underline: SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 20),
                        items: ['1st Semester 2024', '2nd Semester 2024']
                            .map((sem) => DropdownMenuItem(
                                  value: sem,
                                  child: Text(sem, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedSemester = value!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Month Selector
                Row(
                  children: List.generate(6, (index) {
                    String month = _getMonthAbbr(index + 1);
                    return _MonthButton(
                      month: month,
                      isSelected: _selectedMonth == (index + 1).toString(),
                      onTap: () => setState(() => _selectedMonth = (index + 1).toString()),
                    );
                  }),
                ),
                SizedBox(height: 24),
                // LINE CHART - shows sample data while loading, then updates
                _buildLineChartWithFallback(),
              ],
            ),
          ),

          SizedBox(height: 32),

          // Upcoming Events & Recent Activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUpcomingEvents()),
              SizedBox(width: 24),
              Expanded(child: _buildRecentActivity()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardStream(String title, Stream<QuerySnapshot> stream, Color color, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Text(
                      count.toString(),
                      style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                    ),
                ],
              ),
              SizedBox(height: 12),
              Text(title, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineChartWithFallback() {
    // Use StreamBuilder but with an initial sample data while waiting
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'completed')
          .where('date', isGreaterThanOrEqualTo: DateTime(2024, 1, 1).toIso8601String())
          .where('date', isLessThan: DateTime(2025, 1, 1).toIso8601String())
          .snapshots(),
      builder: (context, snapshot) {
        List<double> monthlyData = List.filled(6, 0.0);
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          // Process real data
          List<double> fullYear = List.filled(12, 0.0);
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dateStr = data['date'];
            if (dateStr != null) {
              try {
                DateTime eventDate = DateTime.parse(dateStr);
                if (eventDate.year == 2024 && eventDate.month <= 6) {
                  fullYear[eventDate.month - 1]++;
                }
              } catch (e) {}
            }
          }
          monthlyData = fullYear.sublist(0, 6);
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          // Show sample data while loading
          monthlyData = [42, 55, 68, 45, 72, 58];
        } else {
          // No data, show zeros but with message
          monthlyData = [0, 0, 0, 0, 0, 0];
        }

        double maxValue = monthlyData.reduce((a, b) => a > b ? a : b);
        if (maxValue == 0) maxValue = 100;

        return Column(
          children: [
            Container(
              height: 220,
              child: CustomPaint(
                painter: LineChartPainter(
                  data: monthlyData,
                  months: ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'],
                  selectedMonth: _selectedMonth,
                  maxValue: maxValue,
                ),
                size: Size(double.infinity, 220),
              ),
            ),
            if (monthlyData.every((v) => v == 0) && snapshot.hasData && snapshot.data!.docs.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No completed events data for this period',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingEvents() {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming CICT Events', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
                TextButton(
                  onPressed: () {},
                  child: Text('View All', style: GoogleFonts.beVietnamPro(color: UpriseColors.accent, fontSize: 12)),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'approved')
                  .where('date', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
                  .orderBy('date')
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today, size: 48, color: UpriseColors.mediumGray),
                          SizedBox(height: 12),
                          Text('No upcoming events', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13)),
                          SizedBox(height: 8),
                          Text('Events will appear here once organizations create them', 
                            style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final events = snapshot.data!.docs;
                return Column(
                  children: events.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _EventCard(
                      date: _formatEventDate(data['date']),
                      title: data['title'] ?? 'Untitled Event',
                      location: data['location'] ?? 'TBA',
                      time: data['time'] ?? 'TBA',
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: UpriseColors.mediumGray),
                          SizedBox(height: 12),
                          Text('No recent activity', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13)),
                          SizedBox(height: 8),
                          Text('Activities will appear here as users interact with the system',
                            style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final activities = snapshot.data!.docs;
                return Column(
                  children: activities.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _ActivityCard(
                      title: data['title'] ?? 'Activity',
                      description: data['description'] ?? '',
                      timestamp: data['createdAt'],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    try {
      DateTime date = DateTime.parse(dateStr);
      const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (e) {
      return 'TBD';
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}

// ============ LINE CHART PAINTER (updated colors) ============
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> months;
  final String selectedMonth;
  final double maxValue;

  LineChartPainter({
    required this.data,
    required this.months,
    required this.selectedMonth,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = UpriseColors.primaryDark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = UpriseColors.primaryDark
      ..style = PaintingStyle.fill;

    final selectedPointPaint = Paint()
      ..color = UpriseColors.accent
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = UpriseColors.mediumGray
      ..strokeWidth = 1;

    double stepX = size.width / (data.length - 1);
    double minY = 20;
    double maxY = size.height - 40;

    for (int i = 0; i <= 4; i++) {
      double y = minY + (maxY - minY) * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      double x = i * stepX;
      double y = maxY - ((data[i] / maxValue) * (maxY - minY));
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    for (int i = 0; i < points.length; i++) {
      bool isSelected = months[i] == selectedMonth;
      canvas.drawCircle(points[i], isSelected ? 6 : 4,
          isSelected ? selectedPointPaint : pointPaint);
      if (isSelected) {
        canvas.drawCircle(points[i], 12,
            Paint()..color = UpriseColors.accent.withOpacity(0.1));
        final span = TextSpan(
          text: '${data[i].toInt()}',
          style: GoogleFonts.beVietnamPro(color: UpriseColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
        );
        final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(points[i].dx - tp.width / 2, points[i].dy - 25));
      }
    }

    for (int i = 0; i < months.length; i++) {
      final span = TextSpan(
        text: months[i],
        style: GoogleFonts.beVietnamPro(
          color: months[i] == selectedMonth ? UpriseColors.accent : UpriseColors.darkGray,
          fontSize: 12,
          fontWeight: months[i] == selectedMonth ? FontWeight.w600 : FontWeight.normal,
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(i * stepX - tp.width / 2, size.height - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============ REUSABLE COMPONENTS ============
class _MonthButton extends StatelessWidget {
  final String month;
  final bool isSelected;
  final VoidCallback onTap;
  const _MonthButton({required this.month, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? UpriseColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? UpriseColors.primaryDark : UpriseColors.mediumGray),
          ),
          child: Text(
            month,
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              color: isSelected ? UpriseColors.white : UpriseColors.darkGray,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String date;
  final String title;
  final String location;
  final String time;
  const _EventCard({required this.date, required this.title, required this.location, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 55,
            child: Column(
              children: [
                Text(
                  date.split(' ')[0],
                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark),
                ),
                Text(
                  date.split(' ')[1],
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 14, color: UpriseColors.charcoal)),
                SizedBox(height: 4),
                Text('$location • $time', style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String description;
  final Timestamp? timestamp;
  const _ActivityCard({required this.title, required this.description, this.timestamp});

  String _getTimeAgo() {
    if (timestamp == null) return 'Just now';
    DateTime date = timestamp!.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: UpriseColors.lightGray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.event_available, color: UpriseColors.primaryDark, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 13, color: UpriseColors.charcoal)),
                if (description.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(description, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
                SizedBox(height: 2),
                Text(_getTimeAgo(), style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}