// lib/screens/student/student_notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/common/loading_widget.dart';

// ─────────────────────────────────────────────────────────────
// Custom Colors - UNIFORM (Colors.orange)
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
}

// ── Notification model ────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String type; // 'event' | 'announcement' | 'org' | 'schedule' | 'booth'

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    required this.type,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'announcement',
    );
  }
}

// ── Notifications Screen ──────────────────────────────────────
class StudentNotificationsScreen extends StatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  State<StudentNotificationsScreen> createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> {
  ({IconData icon, Color bg, Color fg}) _typeStyle(String type) {
    switch (type) {
      case 'event':
        return (
          icon: Icons.calendar_today_rounded,
          bg: Colors.orange.withOpacity(0.1),
          fg: Colors.orange,
        );
      case 'org':
        return (
          icon: Icons.check_circle_rounded,
          bg: Colors.orange.withOpacity(0.1),
          fg: Colors.orange,
        );
      case 'schedule':
        return (
          icon: Icons.access_time_rounded,
          bg: Colors.orange.withOpacity(0.1),
          fg: Colors.orange,
        );
      case 'booth':
        return (
          icon: Icons.cancel_rounded,
          bg: Colors.orange.withOpacity(0.1),
          fg: Colors.orange,
        );
      default: // 'announcement'
        return (
          icon: Icons.campaign_rounded,
          bg: Colors.orange.withOpacity(0.1),
          fg: Colors.orange,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  Future<void> _markAsRead(String notifId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({'isRead': true});
  }

  Future<void> _markAllAsRead(List<AppNotification> notifs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in notifs.where((n) => !n.isRead)) {
      final ref = FirebaseFirestore.instance.collection('notifications').doc(n.id);
      batch.update(ref, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: uid == null
                ? null
                : FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
            builder: (context, snap) {
              final hasUnread = snap.hasData && snap.data!.docs.isNotEmpty;
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  final notifs = snap.data!.docs
                      .map((d) => AppNotification.fromFirestore(d))
                      .toList();
                  _markAllAsRead(notifs);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                ),
                child: const Text('Mark all read'),
              );
            },
          ),
        ],
      ),
      body: uid == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Not logged in',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: SkeletonLoader(count: 5, height: 72),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Could not load notifications.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _EmptyState();
                }

                final all = snapshot.data!.docs
                    .map((d) => AppNotification.fromFirestore(d))
                    .toList();

                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final yesterdayStart =
                    todayStart.subtract(const Duration(days: 1));

                final today =
                    all.where((n) => n.createdAt.isAfter(todayStart)).toList();
                final yesterday = all
                    .where((n) =>
                        n.createdAt.isAfter(yesterdayStart) &&
                        !n.createdAt.isAfter(todayStart))
                    .toList();
                final earlier = all
                    .where((n) => !n.createdAt.isAfter(yesterdayStart))
                    .toList();

                return ListView(
                  children: [
                    if (today.isNotEmpty) ...[
                      _SectionHeader(label: 'Today'),
                      ...today.map((n) => _NotifTile(
                            notif: n,
                            style: _typeStyle(n.type),
                            timeLabel: _formatTime(n.createdAt),
                            onTap: () => _markAsRead(n.id),
                          )),
                    ],
                    if (yesterday.isNotEmpty) ...[
                      _SectionHeader(label: 'Yesterday'),
                      ...yesterday.map((n) => _NotifTile(
                            notif: n,
                            style: _typeStyle(n.type),
                            timeLabel: _formatTime(n.createdAt),
                            onTap: () => _markAsRead(n.id),
                          )),
                    ],
                    if (earlier.isNotEmpty) ...[
                      _SectionHeader(label: 'Earlier'),
                      ...earlier.map((n) => _NotifTile(
                            notif: n,
                            style: _typeStyle(n.type),
                            timeLabel: _formatTime(n.createdAt),
                            onTap: () => _markAsRead(n.id),
                          )),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final ({IconData icon, Color bg, Color fg}) style;
  final String timeLabel;
  final VoidCallback onTap;

  const _NotifTile({
    required this.notif,
    required this.style,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notif.isRead ? Colors.white : Colors.orange.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(style.icon, color: style.fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          notif.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      if (!notif.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "You're all caught up!",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}