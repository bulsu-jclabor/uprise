// lib/screens/admin/settings.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminSettings extends StatefulWidget {
  @override
  _AdminSettingsState createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  int _selectedTab = 0; // 0: Admin Profile, 1: System Preferences, 2: Security Settings, 3: Audit Logs
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Notification settings
  bool _emailNotifications = true;
  bool _desktopAlerts = true;
  bool _dailySummary = true;
  bool _urgentAlerts = true;
  bool _eventReminders = true;
  
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
    _loadSettings();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _fullNameController.text = _currentUser!.displayName ?? '';
      _emailController.text = _currentUser!.email ?? '';
    }
    // Also fetch from Firestore if additional fields exist
    final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser?.uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        _fullNameController.text = data['fullName'] ?? _fullNameController.text;
        _emailController.text = data['email'] ?? _emailController.text;
      }
    }
    setState(() {});
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settings saved')));
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUser != null && _fullNameController.text.isNotEmpty) {
        await _currentUser!.updateDisplayName(_fullNameController.text);
        // Also update Firestore
        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
          'fullName': _fullNameController.text,
          'email': _emailController.text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match'), backgroundColor: UpriseColors.error));
      return;
    }
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: UpriseColors.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _currentUser!.updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password changed')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final tabs = ['Admin Profile', 'System Preferences', 'Security Settings', 'Audit Logs'];
    final icons = [Icons.person_outline, Icons.settings_outlined, Icons.security_outlined, Icons.history_outlined];
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(right: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 30),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Admin System Settings',
                style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          ),
          SizedBox(height: 20),
          Divider(),
          ...List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            return ListTile(
              leading: Icon(icons[index], color: isSelected ? UpriseColors.primaryDark : UpriseColors.darkGray, size: 22),
              title: Text(tabs[index], style: GoogleFonts.beVietnamPro(
                fontSize: 14,
                color: isSelected ? UpriseColors.primaryDark : UpriseColors.charcoal,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              )),
              selected: isSelected,
              selectedTileColor: UpriseColors.primaryDark.withOpacity(0.05),
              onTap: () => setState(() => _selectedTab = index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0: return _buildProfileTab();
      case 1: return _buildPreferencesTab();
      case 2: return _buildSecurityTab();
      case 3: return _buildAuditLogsTab();
      default: return Container();
    }
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Profile', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 8),
          Text('Configure your administrative preferences and account security.',
              style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
          SizedBox(height: 32),
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
                Text('Personal Information', style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  enabled: false,
                  decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateProfile,
                        icon: Icon(Icons.save),
                        label: Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Security Settings', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 8),
          Text('Manage your password and account security.',
              style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
          SizedBox(height: 32),
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
                Text('Change Password', style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Regularly updating your password increases account security.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                SizedBox(height: 20),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_outline)),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Confirm New Password', prefixIcon: Icon(Icons.lock_outline)),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _changePassword,
                        icon: Icon(Icons.update),
                        label: Text('Update Password'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
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
                Text('Two‑Factor Authentication', style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Add an extra layer of security to your account.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Enable 2FA', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Receive a verification code via email on each login', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: false,
                  onChanged: (v) {},
                  activeColor: UpriseColors.primaryDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Preferences', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 8),
          Text('Customize your notification and alert preferences.',
              style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
          SizedBox(height: 32),
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
                Text('NOTIFICATION SETTINGS', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5)),
                SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Email Notifications', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Receive daily summary of pending approvals', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: _emailNotifications,
                  onChanged: (v) => setState(() { _emailNotifications = v; _saveSettings(); }),
                  activeColor: UpriseColors.primaryDark,
                ),
                SwitchListTile(
                  title: Text('Desktop Alerts', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('In-browser push notifications for urgent alerts', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: _desktopAlerts,
                  onChanged: (v) => setState(() { _desktopAlerts = v; _saveSettings(); }),
                  activeColor: UpriseColors.primaryDark,
                ),
                Divider(),
                Text('ADVANCED NOTIFICATIONS', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5)),
                SizedBox(height: 8),
                SwitchListTile(
                  title: Text('Daily Summary', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Get a daily digest of all system activities', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: _dailySummary,
                  onChanged: (v) => setState(() { _dailySummary = v; _saveSettings(); }),
                  activeColor: UpriseColors.primaryDark,
                ),
                SwitchListTile(
                  title: Text('Urgent Alerts', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Receive immediate notifications for critical issues', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: _urgentAlerts,
                  onChanged: (v) => setState(() { _urgentAlerts = v; _saveSettings(); }),
                  activeColor: UpriseColors.primaryDark,
                ),
                SwitchListTile(
                  title: Text('Event Reminders', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                  subtitle: Text('Get reminded about upcoming events and deadlines', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                  value: _eventReminders,
                  onChanged: (v) => setState(() { _eventReminders = v; _saveSettings(); }),
                  activeColor: UpriseColors.primaryDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsTab() {
  return SingleChildScrollView(
    padding: EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Audit Logs', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
        SizedBox(height: 8),
        Text('View your recent account activity and login history.',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
        SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activity_logs')
                .where('user', isEqualTo: _currentUser?.displayName ?? '')
                .orderBy('timestamp', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final logs = snapshot.data!.docs;
              if (logs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No recent activity', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray))),
                );
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp;
                  final dateTime = timestamp.toDate(); // <-- FIX HERE
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: UpriseColors.primaryDark.withOpacity(0.1),
                      child: Icon(Icons.history, color: UpriseColors.primaryDark, size: 18),
                    ),
                    title: Text(data['action'] ?? 'Action', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                    subtitle: Text('${data['module'] ?? 'System'} • ${DateFormat('MMM dd, yyyy hh:mm a').format(dateTime)}'), // <-- FIX HERE
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (data['severity'] == 'error' || data['severity'] == 'critical')
                            ? UpriseColors.error.withOpacity(0.1)
                            : UpriseColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(data['severity']?.toUpperCase() ?? 'INFO',
                          style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600,
                              color: (data['severity'] == 'error' || data['severity'] == 'critical') ? UpriseColors.error : UpriseColors.success)),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    ),
  );
}
}