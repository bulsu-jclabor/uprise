// lib/screens/guest/guest_announcements_screen.dart
//
// GUEST MODE – public announcements only (read-only, no dismiss)
//
import 'package:flutter/material.dart';
import '../student/student_announcements_screen.dart'
    show AnnouncementData, sampleAnnouncements;

// ─────────────────────────────────────────────────────────────
//  THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFFFF6B00);
const _kPrimaryBg = Color(0xFFFFF3EB);
const _kBg        = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class GuestAnnouncementsScreen extends StatelessWidget {
  const GuestAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'View Only',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: _kBg,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: sampleAnnouncements.length,
        itemBuilder: (context, index) {
          final ann = sampleAnnouncements[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _GuestAnnouncementDetail(announcement: ann),
              ),
            ),
            child: _GuestAnnouncementCard(ann: ann),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ANNOUNCEMENT CARD
// ─────────────────────────────────────────────────────────────
class _GuestAnnouncementCard extends StatelessWidget {
  final AnnouncementData ann;
  const _GuestAnnouncementCard({required this.ann});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner image ──
          Stack(
            children: [
              Image.network(
                ann.imageUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
              if (ann.isPinned)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.push_pin, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Pinned',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // ── Content ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kPrimaryBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ann.tag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Text(
                      ann.id,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ann.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(ann.logoUrl),
                      backgroundColor: Colors.grey[200],
                      onBackgroundImageError: (_, __) {},
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ann.org,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          Text(ann.orgSub,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ann.date,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87)),
                        Text(ann.time,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _EngagementItem(
                        icon: Icons.thumb_up_alt_outlined,
                        count: ann.likes),
                    const SizedBox(width: 18),
                    _EngagementItem(
                        icon: Icons.favorite_border,
                        count: ann.reactions),
                    const SizedBox(width: 18),
                    _EngagementItem(
                        icon: Icons.mode_comment_outlined,
                        count: ann.comments),
                    const Spacer(),
                    _EngagementItem(
                      icon: Icons.share_outlined,
                      count: ann.shares,
                      showCount: false,
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
}

// ─────────────────────────────────────────────────────────────
//  DETAIL SCREEN (read-only)
// ─────────────────────────────────────────────────────────────
class _GuestAnnouncementDetail extends StatelessWidget {
  final AnnouncementData announcement;
  const _GuestAnnouncementDetail({required this.announcement});

  AnnouncementData get ann => announcement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back,
                      size: 20, color: Colors.black87),
                ),
              ),
            ),
            title: const Text(
              'Announcement',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.black87),
            ),
            centerTitle: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    ann.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[300]),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x88000000),
                          Color(0x00000000),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag + ID row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimaryBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ann.tag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Text(ann.id,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFAAAAAA))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ann.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 14),

                  // Organizer
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(ann.logoUrl),
                        backgroundColor: Colors.grey[200],
                        onBackgroundImageError: (_, __) {},
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ann.org,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87)),
                            Text(ann.orgSub,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ann.date,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                          Text(ann.time,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 16),

                  // Body
                  Text(
                    ann.body,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.65),
                  ),

                  const SizedBox(height: 16),

                  // Hashtags
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: ann.hashtags
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ))
                        .toList(),
                  ),

                  // Attachments
                  if (ann.attachments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ATTACHMENTS (${ann.attachments.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF888888),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...ann.attachments.map(
                      (att) => _AttachmentTile(attachment: att),
                    ),
                  ],

                  // ── Guest lock notice ──
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kPrimaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kPrimary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_outline_rounded,
                            size: 16, color: _kPrimary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sign in as a CICT student to dismiss, like, and comment on announcements.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7A3300)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ATTACHMENT TILE
// ─────────────────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final Map<String, String> attachment;
  const _AttachmentTile({required this.attachment});

  IconData get _icon => attachment['type'] == 'pdf'
      ? Icons.picture_as_pdf_outlined
      : attachment['type'] == 'image'
          ? Icons.image_outlined
          : Icons.attach_file;

  Color get _color => attachment['type'] == 'pdf'
      ? _kPrimary
      : attachment['type'] == 'image'
          ? const Color(0xFF1E88E5)
          : Colors.grey;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, size: 20, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attachment['name'] ?? '',
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.download_outlined,
              size: 20, color: Color(0xFF999999)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ENGAGEMENT ITEM
// ─────────────────────────────────────────────────────────────
class _EngagementItem extends StatelessWidget {
  final IconData icon;
  final int      count;
  final bool     showCount;

  const _EngagementItem({
    required this.icon,
    required this.count,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF999999)),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF999999))),
        ],
      ],
    );
  }
}