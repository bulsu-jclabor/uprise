import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class GuestQrAttendanceScreen extends StatefulWidget {
  const GuestQrAttendanceScreen({super.key});

  @override
  State<GuestQrAttendanceScreen> createState() =>
      _GuestQrAttendanceScreenState();
}

class _GuestQrAttendanceScreenState
    extends State<GuestQrAttendanceScreen>
    with SingleTickerProviderStateMixin {
  bool _scanned = false;
  bool _isVerifying = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  _AttendanceResult? _result;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulateScan() async {
    if (_isVerifying) return;

    setState(() => _isVerifying = true);

    await Future.delayed(const Duration(milliseconds: 1800));

    setState(() {
      _isVerifying = false;
      _scanned = true;

      _result = const _AttendanceResult(
        name: 'Juan Dela Cruz',
        event: 'TechTalk 2025',
        date: 'Nov 10, 2025',
        time: '9:00 AM',
        status: 'Verified',
        ticketCode: 'EVT-2025-001-G-0042',
      );
    });
  }

  void _reset() {
    setState(() {
      _scanned = false;
      _result = null;
      _isVerifying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'QR Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (_scanned)
            TextButton(
              onPressed: _reset,
              child: const Text(
                'Scan Again',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),

      body: _scanned
          ? _VerifiedView(result: _result!)
          : _ScanView(
              isVerifying: _isVerifying,
              pulseAnim: _pulseAnim,
              onSimulateScan: _simulateScan,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SCAN VIEW
// ─────────────────────────────────────────────────────────────

class _ScanView extends StatelessWidget {
  final bool isVerifying;
  final Animation<double> pulseAnim;
  final VoidCallback onSimulateScan;

  const _ScanView({
    required this.isVerifying,
    required this.pulseAnim,
    required this.onSimulateScan,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),

      child: Column(
        children: [
          // ── Instructions ──

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HOW IT WORKS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888),
                  ),
                ),

                SizedBox(height: 14),

                _StepRow(
                  step: '1',
                  icon: Icons.app_registration_rounded,
                  text:
                      'Register for a public event and receive a QR code.',
                ),

                SizedBox(height: 10),

                _StepRow(
                  step: '2',
                  icon: Icons.email_outlined,
                  text: 'Open the QR code from your email.',
                ),

                SizedBox(height: 10),

                _StepRow(
                  step: '3',
                  icon: Icons.qr_code_scanner_rounded,
                  text: 'Scan the QR code at the venue.',
                ),

                SizedBox(height: 10),

                _StepRow(
                  step: '4',
                  icon: Icons.check_circle_outline_rounded,
                  text: 'Attendance is instantly recorded.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Scanner ──

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Column(
              children: [
                const Text(
                  'SCAN YOUR QR CODE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 20),

                ScaleTransition(
                  scale: pulseAnim,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),

                    child: SizedBox(
                      width: 240,
                      height: 240,

                      child: Stack(
                        children: [
                          MobileScanner(
                            onDetect: (capture) {
                              final barcode = capture.barcodes.first;

                              if (barcode.rawValue != null &&
                                  !isVerifying) {
                                // TODO:
                                // Replace with Firestore verification
                                // using barcode.rawValue

                                onSimulateScan();
                              }
                            },
                          ),

                          // ── Border overlay ──

                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE53935),
                                  width: 2,
                                ),
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                          ),

                          // ── Corners ──

                          Positioned(
                            top: 16,
                            left: 16,
                            child: _Corner(topLeft: true),
                          ),

                          Positioned(
                            top: 16,
                            right: 16,
                            child: _Corner(topRight: true),
                          ),

                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: _Corner(bottomLeft: true),
                          ),

                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: _Corner(bottomRight: true),
                          ),

                          // ── Verifying overlay ──

                          if (isVerifying)
                            Container(
                              color: Colors.black.withOpacity(0.55),

                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color(0xFFE53935),
                                      strokeWidth: 3,
                                    ),

                                    SizedBox(height: 16),

                                    Text(
                                      'Verifying...',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,

                  child: ElevatedButton.icon(
                    onPressed:
                        isVerifying ? null : onSimulateScan,

                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                    ),

                    label: Text(
                      isVerifying
                          ? 'Verifying...'
                          : 'Open Camera to Scan',
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Allow camera access when prompted.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              children: const [
                Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: Colors.grey,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Register for an event first to receive a QR code.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
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
//  VERIFIED VIEW
// ─────────────────────────────────────────────────────────────

class _VerifiedView extends StatelessWidget {
  final _AttendanceResult result;

  const _VerifiedView({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 72,
              color: Color(0xFF2E7D32),
            ),

            const SizedBox(height: 16),

            const Text(
              'Attendance Verified!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              result.event,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),

              child: Column(
                children: [
                  _ResultRow(
                    icon: Icons.person,
                    label: 'Attendee',
                    value: result.name,
                  ),

                  const SizedBox(height: 14),

                  _ResultRow(
                    icon: Icons.calendar_today,
                    label: 'Date',
                    value: result.date,
                  ),

                  const SizedBox(height: 14),

                  _ResultRow(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: result.time,
                  ),

                  const SizedBox(height: 14),

                  _ResultRow(
                    icon: Icons.confirmation_number,
                    label: 'Ticket Code',
                    value: result.ticketCode,
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

// ─────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────

class _AttendanceResult {
  final String name;
  final String event;
  final String date;
  final String time;
  final String status;
  final String ticketCode;

  const _AttendanceResult({
    required this.name,
    required this.event,
    required this.date,
    required this.time,
    required this.status,
    required this.ticketCode,
  });
}

class _StepRow extends StatelessWidget {
  final String step;
  final IconData icon;
  final String text;

  const _StepRow({
    required this.step,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: const Color(0xFFE53935),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Icon(icon, size: 18, color: Colors.grey),

        const SizedBox(width: 8),

        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Corner({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _CornerPainter({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    if (topLeft) {
      canvas.drawLine(
          const Offset(0, 16), const Offset(0, 0), paint);

      canvas.drawLine(
          const Offset(0, 0), const Offset(16, 0), paint);
    }

    if (topRight) {
      canvas.drawLine(
          Offset(w - 16, 0), Offset(w, 0), paint);

      canvas.drawLine(
          Offset(w, 0), Offset(w, 16), paint);
    }

    if (bottomLeft) {
      canvas.drawLine(
          Offset(0, h - 16), Offset(0, h), paint);

      canvas.drawLine(
          Offset(0, h), Offset(16, h), paint);
    }

    if (bottomRight) {
      canvas.drawLine(
          Offset(w, h - 16), Offset(w, h), paint);

      canvas.drawLine(
          Offset(w, h), Offset(w - 16, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}