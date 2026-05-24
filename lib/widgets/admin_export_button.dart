import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminExportButton extends StatelessWidget {
  final void Function(String) onSelected;
  final String label;

  const AdminExportButton({
    super.key,
    required this.onSelected,
    this.label = 'Export',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        itemBuilder: (_) => [
          _item('csv', Icons.table_chart_rounded, 'Export as CSV'),
          _item('pdf', Icons.picture_as_pdf_rounded, 'Export as PDF'),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            const Icon(Icons.download_rounded, size: 16, color: Color(0xFF374151)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA5B4)),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13)),
      ]),
    );
  }
}
