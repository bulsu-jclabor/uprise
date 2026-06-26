// lib/widgets/shared/app_support.dart
//
// Shared "make settings real" helpers used by both the student and guest
// settings screens: a working support/feedback mailto, a way to jump to
// the device's actual notification settings for this app, the real app
// version (from pubspec, not a hardcoded string), and a factual Privacy
// & Security screen describing what this app actually collects/stores.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';

const String kSupportEmailPrimary = 'cictuprise@gmail.com';
const String kSupportEmailSecondary = 'cictuprise@outlook.com';

Future<void> launchSupportEmail(
  BuildContext context, {
  required String subject,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmailPrimary,
    query: 'cc=$kSupportEmailSecondary&subject=${Uri.encodeComponent(subject)}',
  );
  final launched = await launchUrl(uri);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No email app found on this device')),
    );
  }
}

Future<void> openNotificationSettings(BuildContext context) async {
  try {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open notification settings')),
      );
    }
  }
}

Future<String> getAppVersionLabel() async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}+${info.buildNumber}';
}

class PrivacySecurityScreen extends StatelessWidget {
  final bool isGuest;
  const PrivacySecurityScreen({super.key, this.isGuest = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black87,
        title: const Text('Privacy & Security',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('What we collect', [
            'Your name and email address, used to sign in and identify you.',
            if (!isGuest)
              'Your course, year level, and student ID, used for attendance and certificate records.',
            'Event registrations, attendance records, and certificates earned through UPRISE.',
            'Answers you submit on event registration forms.',
            if (isGuest) 'Your classification (e.g. BulSUan or outsider) for event eligibility.',
          ]),
          _section('How it\'s stored', [
            'All data is stored in Firebase (Firestore database and Firebase Authentication), operated for BulSU CICT.',
            'Profile photos and signatures are stored as part of your account record and are only shown to you, the organization running an event you registered for, and CICT admins.',
          ]),
          _section('Who can see it', [
            'Admins and the organization hosting an event you registered for can see your registration, attendance, and certificate data for that event.',
            'Other students and guests cannot see your personal data.',
          ]),
          _section('Your controls', [
            'You can update your password at any time from Settings.',
            'To request data correction or deletion, contact CICT UPRISE support (see Help & Support in Settings).',
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(
                      child: Text(p,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
