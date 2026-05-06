// lib/widgets/student/announcements_feed.dart
import 'package:flutter/material.dart';

class AnnouncementsFeed extends StatelessWidget {
  const AnnouncementsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign, color: Color(0xFFFF6B35)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sample Announcement ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is a sample announcement description...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '2 hours ago',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}