// ignore_for_file: unused_element_parameter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import '../admin/export_util.dart';
import '../admin/export_pdf.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ==================== CATEGORY COLORS (matching admin side) ====================
Map<String, Color> _categoryColors = {
  'Workshop':         const Color(0xFF8B5CF6),  // Violet
  'Seminar':          const Color(0xFF3B82F6),  // Blue
  'Competition':      const Color(0xFFEF4444),  // Red
  'General Assembly': const Color(0xFFF59E0B),  // Orange
  'Social':           const Color(0xFFEC4899),  // Pink
  'Outreach':         const Color(0xFF10B981),  // Green
  'Sports':           const Color(0xFF14B8A6),  // Teal
  'Academic':         const Color(0xFF6366F1),  // Indigo
  'Technical':        const Color(0xFF06B6D4),  // Cyan
  'Cultural':         const Color(0xFFD946EF),  // Fuchsia
  'Other':            const Color(0xFF6B7280),  // Gray
};

Color _getCategoryColor(String category) {
  return _categoryColors[category] ?? const Color(0xFF6B7280);
}

// ==================== DESIGN TOKENS ====================
class _DS {
  static const double radiusSm = 8;
  static const double radiusLg = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

class UpriseColors {
  static const Color primaryDark = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF3B82F6);
  static const Color greyText = Color(0xFF64748B);
  static const Color darkText = Color(0xFF1A202C);
}

// Keep CategoryColors for chips and dropdown dots only
class CategoryColors {
  static const Map<String, Color> bg = {
    'Academic': Color(0xFFDCFCE7),
    'Technical': Color(0xFFDBEAFE),
    'Cultural': Color(0xFFFCE7F3),
    'Sports': Color(0xFFFFEDD5),
    'Workshop': Color(0xFFFEF3C7),
    'Other': Color(0xFFF3F4F6),
  };
  static const Map<String, Color> fg = {
    'Academic': Color(0xFF15803D),
    'Technical': Color(0xFF1D4ED8),
    'Cultural': Color(0xFFBE185D),
    'Sports': Color(0xFFEA580C),
    'Workshop': Color(0xFFB45309),
    'Other': Color(0xFF374151),
  };
  static const Map<String, Color> dot = {
    'Academic': Color(0xFF22C55E),
    'Technical': Color(0xFF3B82F6),
    'Cultural': Color(0xFFEC4899),
    'Sports': Color(0xFFF97316),
    'Workshop': Color(0xFFF59E0B),
    'Other': Color(0xFF9CA3AF),
  };
  static Color getBg(String cat) => bg[cat] ?? bg['Other']!;
  static Color getFg(String cat) => fg[cat] ?? fg['Other']!;
  static Color getDot(String cat) => dot[cat] ?? dot['Other']!;
}

// ==================== HELPER WIDGETS ====================
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
        ],
        Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark, letterSpacing: 0.3)),
        const SizedBox(width: 12),
        Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
      ],
    ),
  );
}

Widget _categoryChip(String category) {
  // Keep original chip colors
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: CategoryColors.getBg(category),
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      category.toUpperCase(),
      style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: CategoryColors.getFg(category), letterSpacing: 0.8),
    ),
  );
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'approved': return const Color(0xFF059669);
    case 'pending': return const Color(0xFFD97706);
    case 'rejected': return const Color(0xFFDC2626);
    case 'archived': return const Color(0xFF6B7280);
    default: return UpriseColors.primaryDark;
  }
}

// ==================== EVENT MODEL ====================
class EventModel {
  final String id;
  final String orgId;
  final String title;
  final String description;
  final String location;
  final int capacity;
  final String startTime;
  final String endTime;
  final String category;
  final String guestSpeaker;
  final List<String> resources;
  final List<String> labPreparation;
  final List<String> tags;
  final DateTime date;
  final String status;

  EventModel({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.location,
    required this.capacity,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.guestSpeaker,
    required this.resources,
    required this.labPreparation,
    required this.tags,
    required this.date,
    required this.status,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<String> toList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }
    return EventModel(
      id: doc.id,
      orgId: (d['orgId'] ?? '').toString(),
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      location: d['location'] ?? '',
      capacity: d['capacity'] ?? 0,
      startTime: d['startTime'] ?? '',
      endTime: d['endTime'] ?? '',
      category: d['category'] ?? 'Other',
      guestSpeaker: d['guestSpeaker'] ?? '',
      resources: toList(d['resources']),
      labPreparation: toList(d['labPreparation']),
      tags: toList(d['tags']),
      date: d['date'] is Timestamp
          ? (d['date'] as Timestamp).toDate()
          : DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now(),
      status: (d['status'] ?? 'pending').toString().toLowerCase(),
    );
  }
}

// ==================== MAIN SCREEN ====================
class OrgEventsScheduleScreen extends StatefulWidget {
  final String orgId;
  const OrgEventsScheduleScreen({super.key, required this.orgId});

  @override
  State<OrgEventsScheduleScreen> createState() => _OrgEventsScheduleScreenState();
}

class _OrgEventsScheduleScreenState extends State<OrgEventsScheduleScreen> {
  DateTime _currentMonth = DateTime.now();
  List<EventModel> _cachedEvents = [];

  // true = only THIS org's events; false = all orgs' events (entire college).
  bool _showOrgEventsOnly = true;

  // ── Streams with status filter applied at Firestore level ──────────────
  // "Org Events" mode — only approved events belonging to this org.
  Stream<QuerySnapshot> get _orgEventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .snapshots();

  // "All Events" mode — every approved event across all orgs/colleges.
  Stream<QuerySnapshot> get _allEventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('status', isEqualTo: 'approved')
      .orderBy('date')
      .snapshots();

  // Returns the correct stream based on toggle state.
  Stream<QuerySnapshot> get _activeStream =>
      _showOrgEventsOnly ? _orgEventsStream : _allEventsStream;

  Future<void> _archivePastEvents(List<EventModel> events) async {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final event in events) {
      if (event.date.isBefore(today) && event.status != 'archived') {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(event.id)
            .update({'status': 'archived'});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 22.0 : 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 24, 0, 0),
              child: Text(
                _showOrgEventsOnly
                    ? 'Showing only your organization’s approved events'
                    : 'Showing all CICT approved events',
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
              ),
            ),
            _buildToolbar(isMobile, isTablet, horizontalPadding),
            const SizedBox(height: 16),
            _buildCalendarStream(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Toolbar (no stats, no status filter) ─────────────────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet, double horizontalPadding) {
    final fieldWidth = isMobile ? double.infinity : (isTablet ? 220.0 : 280.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canUseRow = constraints.maxWidth > 800;
          final dateControl = Container(
            height: 40,
            constraints: BoxConstraints(minWidth: fieldWidth),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E6EA)),
              boxShadow: _DS.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C)),
                  ),
                ),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
                ),
              ],
            ),
          );

          final controls = [
            dateControl,
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentMonth = DateTime.now()),
              icon: const Icon(Icons.today_rounded, size: 15),
              label: Text('Today', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: UpriseColors.primaryDark,
                side: BorderSide(color: UpriseColors.primaryDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E6EA)),
                boxShadow: _DS.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleTab(
                    label: 'Org Events',
                    active: _showOrgEventsOnly,
                    onTap: () => setState(() {
                      _showOrgEventsOnly = true;
                    }),
                  ),
                  _ToggleTab(
                    label: 'All Events',
                    active: !_showOrgEventsOnly,
                    onTap: () => setState(() {
                      _showOrgEventsOnly = false;
                    }),
                  ),
                ],
              ),
            ),
            AdminExportButton(onSelected: _exportEvents),
          ];

          if (canUseRow) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: dateControl),
                const SizedBox(width: 10),
                ...controls.sublist(1).expand((widget) => [widget, const SizedBox(width: 10)]).toList()..removeLast(),
              ],
            );
          }

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          );
        },
      ),
    );
  }

  // ── Calendar stream (only approved events from Firestore) ───────────────
  Widget _buildCalendarStream() {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('cal_${_showOrgEventsOnly}_${widget.orgId}'),
      stream: _activeStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Convert all docs to EventModel — all are already approved from Firestore
        var allEvents = (snapshot.data?.docs ?? [])
            .map((doc) => EventModel.fromFirestore(doc))
            .toList();

        allEvents.sort((a, b) => a.date.compareTo(b.date));
        _archivePastEvents(allEvents);

        _cachedEvents = allEvents;
        return _buildCalendarGrid(allEvents);
      },
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────
  Widget _buildCalendarGrid(List<EventModel> events) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday = firstDay.weekday % 7;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    final Map<int, List<EventModel>> byDay = {};
    for (final e in events) {
      if (e.date.year == _currentMonth.year && e.date.month == _currentMonth.month) {
        byDay.putIfAbsent(e.date.day, () => []).add(e);
      }
    }

    const weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    final horizontalPadding = MediaQuery.of(context).size.width < 720 ? 16.0 : 28.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
            ),
            child: Row(
              children: weekdays.map((d) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(d, textAlign: TextAlign.center,
                      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.7)),
                ),
              )).toList(),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.85),
            itemCount: 42,
            itemBuilder: (_, index) {
              final dayNum = index - startWeekday + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return _buildEmptyCell(
                  isLastRow: index >= 35,
                  colIndex: index % 7,
                  isBottomRight: index == 41,
                  isBottomLeft: index == 35,
                );
              }
              return _buildDayCell(dayNum, byDay[dayNum] ?? []);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCell({bool isLastRow = false, int colIndex = 0, bool isBottomRight = false, bool isBottomLeft = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        border: Border(
          right: colIndex < 6 ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
          bottom: !isLastRow ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
        ),
        borderRadius: isBottomLeft
            ? const BorderRadius.only(bottomLeft: Radius.circular(14))
            : isBottomRight ? const BorderRadius.only(bottomRight: Radius.circular(14)) : null,
      ),
    );
  }

  Widget _buildDayCell(int day, List<EventModel> events) {
    final isToday = day == DateTime.now().day &&
        _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

    final sorted = List<EventModel>.from(events)..sort((a, b) => a.startTime.compareTo(b.startTime));
    final display = sorted.take(3).toList();
    final extra = sorted.length - display.length;

    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startWeekday = firstDay.weekday % 7;
    final cellIndex = startWeekday + day - 1;
    final colIndex = cellIndex % 7;
    final isLastRow = cellIndex >= 35;
    final isBottomLeft = isLastRow && colIndex == 0;
    final isBottomRight = cellIndex == 41 ||
        (isLastRow && day == DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day);

    return InkWell(
      onTap: events.isEmpty ? null : () => _showDayEventsSheet(day, sorted),
      hoverColor: UpriseColors.primaryDark.withOpacity(0.03),
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? UpriseColors.primaryDark.withOpacity(0.04) : null,
          border: Border(
            right: colIndex < 6 ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
            bottom: !isLastRow ? const BorderSide(color: Color(0xFFF1F5F9)) : BorderSide.none,
          ),
          borderRadius: isBottomLeft
              ? const BorderRadius.only(bottomLeft: Radius.circular(14))
              : isBottomRight ? const BorderRadius.only(bottomRight: Radius.circular(14)) : null,
        ),
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: isToday ? BoxDecoration(color: UpriseColors.primaryDark, borderRadius: BorderRadius.circular(6)) : null,
                  alignment: Alignment.center,
                  child: Text('$day',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? Colors.white : const Color(0xFF1A202C),
                      )),
                ),
                if (events.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(events.first.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${events.length}',
                        style: GoogleFonts.beVietnamPro(fontSize: 9, fontWeight: FontWeight.w700, color: _getCategoryColor(events.first.category))),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            ...display.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(e.category).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border(left: BorderSide(color: _getCategoryColor(e.category), width: 2)),
                ),
                child: Text(
                  e.title.length > 13 ? '${e.title.substring(0, 13)}…' : e.title,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: _getCategoryColor(e.category),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )),
            if (extra > 0)
              Text('+$extra more', style: GoogleFonts.beVietnamPro(fontSize: 9, color: const Color(0xFF9AA5B4), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Day events bottom sheet ───────────────────────────────────────
  void _showDayEventsSheet(int day, List<EventModel> events) {
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy')
        .format(DateTime(_currentMonth.year, _currentMonth.month, day));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E6EA), borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: UpriseColors.primaryDark.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.event_rounded, color: UpriseColors.primaryDark, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dateLabel, style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                      Text('${events.length} event${events.length == 1 ? '' : 's'}',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24, color: Color(0xFFE8ECF0)),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _EventListTile(
                    event: events[i],
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEventDetailDialog(events[i]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Event detail dialog ───────────────────────────────────────────
  void _showEventDetailDialog(EventModel event) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 600,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: _getCategoryColor(event.category), // Changed from UpriseColors.primaryDark
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 45, height: 45,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.event_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(event.title, style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 4),
                          Row(children: [
                            _categoryChip(event.category),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(event.status).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(event.status.toUpperCase(),
                                  style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ]),
                        ])),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _quickInfoChip(Icons.calendar_today_rounded, DateFormat('MMM d, yyyy').format(event.date))),
                      const SizedBox(width: 8),
                      Expanded(child: _quickInfoChip(Icons.access_time_rounded, '${event.startTime} - ${event.endTime}')),
                      const SizedBox(width: 8),
                      Expanded(child: _quickInfoChip(Icons.location_on_rounded, event.location)),
                      const SizedBox(width: 8),
                      Expanded(child: _quickInfoChip(Icons.group_rounded, '${event.capacity} capacity')),
                    ]),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (event.description.isNotEmpty) ...[
                      _sectionLabel('Description', icon: Icons.description_outlined),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E6EA)),
                        ),
                        child: Text(event.description,
                            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151), height: 1.6)),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _sectionLabel('Event Details', icon: Icons.info_outline_rounded),
                    Row(children: [
                      Expanded(child: _detailItem('Status', event.status[0].toUpperCase() + event.status.substring(1), Icons.circle_outlined, valueColor: _statusColor(event.status))),
                      const SizedBox(width: 16),
                      Expanded(child: _detailItem('Category', event.category, Icons.category_outlined, valueColor: _getCategoryColor(event.category))),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _detailItem('Capacity', '${event.capacity} attendees', Icons.group_outlined)),
                      const SizedBox(width: 16),
                      Expanded(child: _detailItem('Location', event.location, Icons.location_on_outlined)),
                    ]),
                    if (event.guestSpeaker.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Guest Speaker', icon: Icons.person_outline),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(event.category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getCategoryColor(event.category).withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: _getCategoryColor(event.category).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.person_rounded, color: _getCategoryColor(event.category)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(event.guestSpeaker,
                              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)))),
                        ]),
                      ),
                    ],
                    if (event.resources.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Resources', icon: Icons.folder_outlined),
                      _listDetail('', event.resources),
                    ],
                    if (event.labPreparation.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Lab Preparation', icon: Icons.build_circle_outlined),
                      _listDetail('', event.labPreparation),
                    ],
                    if (event.tags.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Tags', icon: Icons.local_offer_outlined),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: event.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(event.category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getCategoryColor(event.category).withOpacity(0.3)),
                          ),
                          child: Text(tag, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: _getCategoryColor(event.category))),
                        )).toList(),
                      ),
                    ],
                  ]),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: Text('Close', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _detailItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? const Color(0xFF1A202C))),
    ]);
  }

  Widget _listDetail(String label, List<String> items) {
    if (items.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty)
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      if (label.isNotEmpty) const SizedBox(height: 6),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.circle, size: 5, color: Color(0xFF9AA5B4)),
          const SizedBox(width: 8),
          Expanded(child: Text(item, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF4B5563)))),
        ]),
      )),
    ]);
  }

  // ── Export ────────────────────────────────────────────────────────
  Future<void> _exportEvents(String format) async {
    if (_cachedEvents.isEmpty) return;
    String csvEscape(String value) => '"${value.replaceAll('"', '""')}"';
    final rows = _cachedEvents.map((event) => [
      event.title, event.category, event.status.toUpperCase(),
      DateFormat('yyyy-MM-dd').format(event.date),
      '${event.startTime} - ${event.endTime}', event.location,
    ]).toList();
    final headers = ['Title', 'Category', 'Status', 'Date', 'Time', 'Location'];

    if (format == 'csv') {
      final csv = StringBuffer();
      csv.writeln(headers.map(csvEscape).join(','));
      for (final row in rows) { csv.writeln(row.map(csvEscape).join(',')); }
      await AdminExportUtil.saveText(
        csv.toString(),
        '${_showOrgEventsOnly ? 'org' : 'cict'}_events_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
        mimeType: 'text/csv',
      );
      return;
    }

    final bytes = await AdminExportPdf.generateTablePdf(
      title: _showOrgEventsOnly ? 'Organization Events' : 'CICT Events',
      headers: headers,
      rows: rows,
      subtitle: _showOrgEventsOnly ? 'Organization event schedule export' : 'CICT event schedule export',
    );
    await AdminExportUtil.saveBytes(
      bytes,
      '${_showOrgEventsOnly ? 'org' : 'cict'}_events_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      mimeType: 'application/pdf',
    );
  }
}

// ==================== REUSABLE WIDGETS ====================
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 20, color: UpriseColors.primaryDark),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;
  const _EventListTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(event.category);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: categoryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: categoryColor.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 4, height: 48,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(event.category,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: categoryColor)),
              const SizedBox(width: 8),
              Text(event.location,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _categoryChip(event.category),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF9AA5B4)),
              const SizedBox(width: 3),
              Text(event.startTime, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4))),
            ]),
          ]),
        ]),
      ),
    );
  }
}

// ==================== ADD/EDIT MODAL ====================
class _EventModal extends StatefulWidget {
  final String orgId;
  final EventModel? existingEvent;
  
  const _EventModal({
    required this.orgId,
    this.existingEvent,
  });

  @override
  State<_EventModal> createState() => _EventModalState();
}

class _EventModalState extends State<_EventModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl = TextEditingController();
  final _speakerCtrl = TextEditingController();
  final _resourcesCtrl = TextEditingController();
  final _labPrepCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  DateTime? _selectedDate;
  String _selectedCategory = 'Academic';
  bool _isSubmitting = false;

  static const _categories = ['Academic', 'Technical', 'Cultural', 'Sports', 'Workshop', 'Other'];

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    if (e != null) {
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description;
      _locationCtrl.text = e.location;
      _capacityCtrl.text = e.capacity.toString();
      _startTimeCtrl.text = e.startTime;
      _endTimeCtrl.text = e.endTime;
      _speakerCtrl.text = e.guestSpeaker;
      _resourcesCtrl.text = e.resources.join(', ');
      _labPrepCtrl.text = e.labPreparation.join(', ');
      _tagsCtrl.text = e.tags.join(', ');
      _selectedDate = e.date;
      _selectedCategory = _categories.contains(e.category) ? e.category : 'Other';
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose();
    _capacityCtrl.dispose(); _startTimeCtrl.dispose(); _endTimeCtrl.dispose();
    _speakerCtrl.dispose(); _resourcesCtrl.dispose(); _labPrepCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date')));
      return;
    }
    setState(() => _isSubmitting = true);

    List<String> splitComma(String s) => s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final data = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 0,
      'startTime': _startTimeCtrl.text.trim(),
      'endTime': _endTimeCtrl.text.trim(),
      'guestSpeaker': _speakerCtrl.text.trim(),
      'resources': splitComma(_resourcesCtrl.text),
      'labPreparation': splitComma(_labPrepCtrl.text),
      'tags': splitComma(_tagsCtrl.text),
      'category': _selectedCategory,
      'date': Timestamp.fromDate(_selectedDate!),
      'updatedAt': FieldValue.serverTimestamp(),
      'orgId': widget.existingEvent?.orgId ?? widget.orgId,
      'status': 'pending', // Always start as pending
    };

    try {
      if ((data['orgId'] ?? '').toString().isNotEmpty) {
        final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(data['orgId'].toString()).get();
        if (orgDoc.exists) {
          final orgMap = orgDoc.data();
          if (orgMap != null && orgMap['name'] != null) data['orgName'] = orgMap['name'].toString();
        }
      }
    } catch (_) {}

    try {
      if (widget.existingEvent != null) {
        await FirebaseFirestore.instance.collection('events').doc(widget.existingEvent!.id).update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_event', module: 'events_schedule',
          details: {'orgId': widget.orgId, 'eventId': widget.existingEvent!.id, 'title': data['title']},
        );
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('events').add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_event', module: 'events_schedule',
          details: {'orgId': widget.orgId, 'title': data['title']},
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEvent != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
      child: Container(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(_DS.radiusLg)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(isEdit ? Icons.edit_outlined : Icons.add, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Event' : 'Create Event',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Fill in the event details below', style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white70)),
                ])),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20)),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  _buildField('Event Title *', _buildTextInput(_titleCtrl, 'e.g. Hacking Workshop', validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildField('Category *', _buildCategoryDropdown())),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('Date *', _buildDateInput())),
                  ]),
                  const SizedBox(height: 16),
                  _buildField('Description', _buildTextInput(_descCtrl, 'Describe the event...', maxLines: 3)),
                  const SizedBox(height: 16),
                  _buildField('Location *', _buildTextInput(_locationCtrl, 'e.g. CIT Lab 2', validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildField('Start Time', _buildTimeInput(_startTimeCtrl, 'Start time'))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('End Time', _buildTimeInput(_endTimeCtrl, 'End time'))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('Capacity', _buildTextInput(_capacityCtrl, '100', keyboardType: TextInputType.number))),
                  ]),
                  const SizedBox(height: 16),
                  _buildField('Guest Speaker', _buildTextInput(_speakerCtrl, 'Full name and title')),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _buildField('Resources (comma-separated)', _buildTextInput(_resourcesCtrl, 'e.g. Slides, Lab Files'))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildField('Lab Preparation', _buildTextInput(_labPrepCtrl, 'e.g. Pre-configured VMs'))),
                  ]),
                  const SizedBox(height: 16),
                  _buildField('Tags (comma-separated)', _buildTextInput(_tagsCtrl, 'e.g. Cybersecurity, Networking')),
                ]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusLg)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E6EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Create Event',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildField(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      const SizedBox(height: 6),
      child,
    ],
  );

  Widget _buildTextInput(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboardType, validator: validator,
      style: GoogleFonts.beVietnamPro(fontSize: 13),
      decoration: _DS.inputDecoration('', hint: hint),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      items: _categories.map((c) => DropdownMenuItem(
        value: c,
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: CategoryColors.getDot(c), shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(c, style: GoogleFonts.beVietnamPro(fontSize: 13)),
        ]),
      )).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v!),
      decoration: _DS.inputDecoration('', hint: 'Select category'),
    );
  }

  Widget _buildDateInput() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, initialDate: _selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020), lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: const Color(0xFFE2E6EA)),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF9AA5B4)),
          const SizedBox(width: 10),
          Text(
            _selectedDate != null ? DateFormat('MM/dd/yyyy').format(_selectedDate!) : 'Select date',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: _selectedDate != null ? const Color(0xFF1A202C) : const Color(0xFF9AA5B4)),
          ),
        ]),
      ),
    );
  }

  Widget _buildTimeInput(TextEditingController ctrl, String hint) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
        if (picked != null) setState(() => ctrl.text = picked.format(context));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: const Color(0xFFE2E6EA)),
        ),
        child: Row(children: [
          const Icon(Icons.access_time, size: 18, color: Color(0xFF9AA5B4)),
          const SizedBox(width: 10),
          Text(
            ctrl.text.isEmpty ? hint : ctrl.text,
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: ctrl.text.isEmpty ? const Color(0xFF9AA5B4) : const Color(0xFF1A202C)),
          ),
        ]),
      ),
    );
  }
}