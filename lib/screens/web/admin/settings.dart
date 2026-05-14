import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import 'admin_login.dart';
<<<<<<< HEAD
import '../../../services/activity_logger.dart' as activity_log;

// ============ SIDEBAR ICONS ============
const Map<String, IconData> _sidebarIcons = {
  'Dashboard': Icons.dashboard_outlined,
  'Organization Management': Icons.business_outlined,
  'Student Accounts': Icons.people_outline,
  'Adviser Roles': Icons.school_outlined,
  'Event Proposals': Icons.pending_actions_outlined,
  'College Event Calendar': Icons.calendar_today_outlined,
  'Letter Request': Icons.mail_outline,
  'External Account': Icons.link_outlined,
  'Reports Management': Icons.assessment_outlined,
  'Activity Logs': Icons.history_outlined,
  'Settings': Icons.settings_outlined,
};
=======
>>>>>>> 27957c91067b9941c210707d39962f8d81d9cae1

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  _AdminSettingsState createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile data
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  User? _currentUser;
  String? _profileImageBase64;
  File? _selectedImageFile;

  // Password change
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Notification settings
  bool _emailNotifications = true;
  bool _desktopAlerts = true;
  bool _dailySummary = true;
  bool _urgentAlerts = true;
  bool _eventReminders = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
    _loadSettings();
    _loadProfileImage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _fullNameController.text = _currentUser!.displayName ?? '';
      _emailController.text = _currentUser!.email ?? '';
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        _fullNameController.text = data['fullName'] ?? _fullNameController.text;
        _emailController.text = data['email'] ?? _emailController.text;
      }
    }
    setState(() {});
  }

  Future<void> _loadProfileImage() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser?.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['photoBase64'] != null) {
        setState(() => _profileImageBase64 = data['photoBase64']);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked == null) return;

    setState(() => _selectedImageFile = File(picked.path));
    setState(() => _isLoading = true);

    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64String = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({'photoBase64': base64String}, SetOptions(merge: true));
      setState(() {
        _profileImageBase64 = base64String;
        _selectedImageFile = null;
      });
<<<<<<< HEAD
      await activity_log.ActivityLogger.log(
        action: 'Updated profile picture',
        module: 'Admin Settings',
        severity: 'info',
      );
=======
>>>>>>> 27957c91067b9941c210707d39962f8d81d9cae1
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving picture: $e'), backgroundColor: UpriseColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance
        .collection('user_settings')
        .doc(_currentUser?.uid)
        .get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        setState(() {
          _emailNotifications = data['emailNotifications'] ?? true;
          _desktopAlerts = data['desktopAlerts'] ?? true;
          _dailySummary = data['dailySummary'] ?? true;
          _urgentAlerts = data['urgentAlerts'] ?? true;
          _eventReminders = data['eventReminders'] ?? true;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    await FirebaseFirestore.instance
        .collection('user_settings')
        .doc(_currentUser?.uid)
        .set({
      'emailNotifications': _emailNotifications,
      'desktopAlerts': _desktopAlerts,
      'dailySummary': _dailySummary,
      'urgentAlerts': _urgentAlerts,
      'eventReminders': _eventReminders,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
<<<<<<< HEAD
    await activity_log.ActivityLogger.log(
      action: 'Updated notification preferences',
      module: 'Admin Settings',
      severity: 'info',
    );
=======
>>>>>>> 27957c91067b9941c210707d39962f8d81d9cae1
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty'), backgroundColor: UpriseColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_currentUser != null) {
        await _currentUser!.updateDisplayName(_fullNameController.text);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .set({
          'fullName': _fullNameController.text,
          'email': _emailController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
<<<<<<< HEAD
        await activity_log.ActivityLogger.log(
          action: 'Updated profile name to ${_fullNameController.text}',
          module: 'Admin Settings',
          severity: 'info',
        );
=======
>>>>>>> 27957c91067b9941c210707d39962f8d81d9cae1
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: UpriseColors.error),
      );
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: UpriseColors.error),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _currentUser!.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
<<<<<<< HEAD
      await activity_log.ActivityLogger.log(
        action: 'Changed account password',
        module: 'Admin Settings',
        severity: 'info',
      );
=======
>>>>>>> 27957c91067b9941c210707d39962f8d81d9cae1
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin System Settings',
                        style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your profile, security, and notification preferences.',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab Bar
          Container(
            color: UpriseColors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Profile'),
                Tab(text: 'Preferences'),
                Tab(text: 'Security'),
                Tab(text: 'Audit Logs'),
              ],
              labelColor: UpriseColors.primaryDark,
              unselectedLabelColor: UpriseColors.darkGray,
              indicatorColor: UpriseColors.primaryDark,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
            ),
          ),
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildPreferencesTab(),
                _buildSecurityTab(),
                _buildAuditLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== PROFILE TAB ==========
  Widget _buildProfileTab() {
    ImageProvider? imageProvider;
    if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) {
      imageProvider = MemoryImage(base64Decode(_profileImageBase64!));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: UpriseColors.lightGray,
                        backgroundImage: imageProvider,
                        child: _profileImageBase64 == null
                            ? Icon(Icons.person, size: 60, color: UpriseColors.darkGray)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: UpriseColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tap the camera icon to change your profile picture',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline, color: UpriseColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: UpriseColors.lightGray,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: UpriseColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: UpriseColors.lightGray,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: UpriseColors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== PREFERENCES TAB ==========
  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UpriseColors.primaryDark, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
            ),
            const SizedBox(height: 16),
            _notificationSwitch(
              title: 'Email Notifications',
              subtitle: 'Receive daily summary of pending approvals',
              value: _emailNotifications,
              onChanged: (v) => setState(() { _emailNotifications = v; _saveSettings(); }),
            ),
            _notificationSwitch(
              title: 'Desktop Alerts',
              subtitle: 'In-browser push notifications for urgent alerts',
              value: _desktopAlerts,
              onChanged: (v) => setState(() { _desktopAlerts = v; _saveSettings(); }),
            ),
            const Divider(),
            Text(
              'Advanced Notifications',
              style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: UpriseColors.charcoal),
            ),
            const SizedBox(height: 8),
            _notificationSwitch(
              title: 'Daily Summary',
              subtitle: 'Get a daily digest of all system activities',
              value: _dailySummary,
              onChanged: (v) => setState(() { _dailySummary = v; _saveSettings(); }),
            ),
            _notificationSwitch(
              title: 'Urgent Alerts',
              subtitle: 'Receive immediate notifications for critical issues',
              value: _urgentAlerts,
              onChanged: (v) => setState(() { _urgentAlerts = v; _saveSettings(); }),
            ),
            _notificationSwitch(
              title: 'Event Reminders',
              subtitle: 'Get reminded about upcoming events and deadlines',
              value: _eventReminders,
              onChanged: (v) => setState(() { _eventReminders = v; _saveSettings(); }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: UpriseColors.primaryDark,
    );
  }

  // ========== SECURITY TAB ==========
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Password',
                  style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                ),
                const SizedBox(height: 8),
                Text(
                  'Regularly updating your password increases account security.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: UpriseColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: UpriseColors.lightGray,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline, color: UpriseColors.primaryDark),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: UpriseColors.lightGray,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _changePassword,
                  icon: const Icon(Icons.update),
                  label: const Text('Update Password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: UpriseColors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Two-Factor Authentication',
                  style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add an extra layer of security to your account.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Enable 2FA', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Receive a verification code via email on each login', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: false,
                  onChanged: (v) {},
                  activeThumbColor: UpriseColors.primaryDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== AUDIT LOGS TAB ==========
  Widget _buildAuditLogsTab() {
    final email = _currentUser?.email ?? '';
    if (email.isEmpty) {
      return const Center(child: Text('Unable to load logs: user not found'));
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('activity_logs')
          .where('user', isEqualTo: email)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: UpriseColors.error),
                const SizedBox(height: 12),
                Text('Error loading logs: ${snapshot.error}',
                    style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
              ],
            ),
          );
        }
        final logs = snapshot.data!.docs;
        if (logs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 48, color: UpriseColors.mediumGray),
                  const SizedBox(height: 16),
                  Text('No recent activity found.',
                      style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                  const SizedBox(height: 8),
                  Text('Actions you perform will appear here.',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final data = logs[index].data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp;
            final dateTime = timestamp.toDate();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: UpriseColors.primaryDark.withOpacity(0.1),
                child: Icon(Icons.history, color: UpriseColors.primaryDark, size: 18),
              ),
              title: Text(data['action'] ?? 'Action',
                  style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
              subtitle: Text(
                '${data['module'] ?? 'System'} • ${DateFormat('MMM dd, yyyy hh:mm a').format(dateTime)}',
                style: GoogleFonts.beVietnamPro(fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (data['severity'] == 'error' || data['severity'] == 'critical')
                      ? UpriseColors.error.withOpacity(0.1)
                      : UpriseColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  data['severity']?.toUpperCase() ?? 'INFO',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: (data['severity'] == 'error' || data['severity'] == 'critical')
                        ? UpriseColors.error
                        : UpriseColors.success,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

