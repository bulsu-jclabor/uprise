import 'package:flutter/material.dart';

class StudentCertificatesScreen extends StatefulWidget {
  const StudentCertificatesScreen({super.key});

  @override
  State<StudentCertificatesScreen> createState() => _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState extends State<StudentCertificatesScreen> {
  String selectedFilter = 'All';

  final List<Map<String, String>> certificates = [
    {
      'title': 'CICT Symposium 2023',
      'date': 'October 12, 2023',
      'category': 'Academic',
      'image': 'assets/cert1.png',
    },
    {
      'title': 'Dean’s Lister Q1',
      'date': 'September 05, 2023',
      'category': 'Academic',
      'image': 'assets/cert2.png',
    },
    {
      'title': 'UPRISE Hackathon',
      'date': 'July 15, 2023',
      'category': 'Workshops',
      'image': 'assets/cert3.png',
    },
    {
      'title': 'Student Leader Award',
      'date': 'June 02, 2023',
      'category': 'Workshops',
      'image': 'assets/cert4.png',
    },
    {
      'title': 'Workshop on UI/UX',
      'date': 'August 20, 2023',
      'category': 'Events',
      'image': 'assets/cert5.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = selectedFilter == 'All'
        ? certificates
        : certificates.where((c) => c['category'] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Upload Certificate'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterButton('All'),
                const SizedBox(width: 8),
                _buildFilterButton('Academic'),
                const SizedBox(width: 8),
                _buildFilterButton('Workshops'),
                const SizedBox(width: 8),
                _buildFilterButton('Events'),
              ],
            ),
          ),

          // Certificates list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final cert = filtered[index];
                return _buildCertificateCard(cert);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateCard(Map<String, String> cert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Certificate image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(cert['image']!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(cert['date']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.orange),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
