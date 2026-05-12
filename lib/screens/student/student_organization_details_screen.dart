import 'package:flutter/material.dart';

class StudentOrganizationsDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> org;
  const StudentOrganizationsDetailsScreen({super.key, required this.org});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(org['name'] as String)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About section
            const Text(
              'ABOUT',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              org['about'] as String,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Adviser
            Text(
              'Adviser: ${org['adviser']}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            // Officers
            const Text(
              'Executive Officers',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children: (org['officers'] as List)
                  .map((officer) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(officer['name']),
                        subtitle: Text(officer['role']),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Events
            const Text(
              'Upcoming Events',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if ((org['events'] as List).isEmpty)
              const Text(
                'No upcoming events',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            else
              Column(
                children: (org['events'] as List)
                    .map((event) => ListTile(
                          leading: const Icon(Icons.event, color: Colors.orange),
                          title: Text(event['title']),
                          subtitle: Text(
                              '${event['date']} • ${event['time']} • ${event['location']}'),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
