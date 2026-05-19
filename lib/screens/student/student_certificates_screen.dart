import 'package:flutter/material.dart';

class StudentCertificatesScreen extends StatefulWidget {
  const StudentCertificatesScreen({super.key});

  @override
  State<StudentCertificatesScreen> createState() =>
      _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState
    extends State<StudentCertificatesScreen> {

  String selectedFilter = 'All';

  final List<String> filters = [
    'All',
    'Academic',
    'Workshops',
    'Events',
  ];

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
        : certificates
            .where(
              (c) => c['category'] == selectedFilter,
            )
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text(
          'Certificate',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),

        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        iconTheme: const IconThemeData(
          color: Colors.black,
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ),

            child: ElevatedButton(
              onPressed: () {},

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,

                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8),
                ),
              ),

              child: const Text(
                'Upload Certificate',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [

          // DROPDOWN FILTER
          Padding(
            padding: const EdgeInsets.all(16),

            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),

              decoration: BoxDecoration(
                color: Colors.grey.shade100,

                borderRadius:
                    BorderRadius.circular(12),

                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),

              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedFilter,

                  isExpanded: true,

                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                  ),

                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),

                  items: filters.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,

                      child: Text(value),
                    );
                  }).toList(),

                  onChanged: (value) {
                    setState(() {
                      selectedFilter = value!;
                    });
                  },
                ),
              ),
            ),
          ),

          // CERTIFICATE LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),

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

  Widget _buildCertificateCard(
    Map<String, String> cert,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(14),

        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // IMAGE
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(
              top: Radius.circular(14),
            ),

            child: Image.asset(
              cert['image']!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,

              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  height: 180,
                  color: Colors.grey.shade200,

                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),

          // DETAILS
          Padding(
            padding: const EdgeInsets.all(14),

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

              children: [

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        cert['title']!,

                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        cert['date']!,

                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.orange
                              .withOpacity(0.12),

                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),

                        child: Text(
                          cert['category']!,

                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight:
                                FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),

                  onPressed: () {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          '${cert['title']} downloaded',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}