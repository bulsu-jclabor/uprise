// Canonical certificate rendering — shared by the org's Generate/Customize/
// View flows (org_certificates.dart) and the student's certificate viewer
// (student_certificates_screen.dart).
//
// Certificates that don't use a custom imported/designed template are never
// flattened into a static image — there's nothing to flatten consistently
// per recipient. Instead every viewer (org or student) renders this same
// widget directly from the stored Firestore fields (recipientName,
// organization, eventName, signatories, ...), so the certificate a student
// sees always has their own real name on it, and can never visually drift
// from what the org saw when they issued it.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CertSignatory {
  final String name;
  final String title;
  final String? signatureImageBase64;
  const CertSignatory({required this.name, this.title = '', this.signatureImageBase64});
}

class CertTheme {
  final Color bg, accent, text;
  const CertTheme({required this.bg, required this.accent, required this.text});

  // Single source of truth for what a `templateType` string looks like —
  // used everywhere a certificate is rendered so the same template name
  // always produces the same colors, regardless of which screen is asking.
  factory CertTheme.forType(String? templateType, {required Color primaryDark, required Color primaryLight, required Color accentColor}) {
    switch (templateType) {
      case 'Modern Workshop':
        return CertTheme(bg: primaryDark, accent: primaryLight, text: Colors.white);
      case 'Vibrant Event':
        return CertTheme(bg: accentColor, accent: primaryDark, text: Colors.white);
      default:
        return CertTheme(bg: Colors.white, accent: primaryDark, text: const Color(0xFF1A202C));
    }
  }
}

class CertificatePreview extends StatelessWidget {
  final CertTheme theme;
  final String orgName, eventTitle, eventDate, recipient;
  final List<CertSignatory> signatories;
  final String? verificationCode;
  const CertificatePreview({
    super.key,
    required this.theme,
    required this.orgName,
    required this.eventTitle,
    required this.eventDate,
    required this.recipient,
    this.signatories = const [],
    this.verificationCode,
  });

  @override
  Widget build(BuildContext context) {
    final bg = theme.bg, accent = theme.accent, textColor = theme.text;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(76), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Stack(children: [
        Positioned(
          top: 14, right: 14,
          child: Icon(Icons.workspace_premium_rounded, size: 20, color: accent.withAlpha(140)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 38, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(7)),
                alignment: Alignment.center,
                child: Text(orgName.isNotEmpty ? orgName[0].toUpperCase() : '?',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Text(
                orgName.toUpperCase(),
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
            ]),
            const SizedBox(height: 14),
            Text('CERTIFICATE', style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1)),
            Text('OF PARTICIPATION', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: accent, letterSpacing: 3)),
            const SizedBox(height: 14),
            Text('This certificate is proudly presented to',
                style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withAlpha(166))),
            const SizedBox(height: 6),
            Text(recipient,
                style: GoogleFonts.beVietnamPro(fontSize: 19, fontWeight: FontWeight.w700, color: textColor, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            SizedBox(width: 140, child: Divider(color: accent.withAlpha(102), thickness: 0.8)),
            const SizedBox(height: 10),
            Text('for successfully participating in',
                style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withAlpha(153)),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(eventTitle,
                style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text('held on $eventDate',
                style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withAlpha(153))),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: signatories.isEmpty
                    ? Column(children: [
                        Divider(color: accent.withAlpha(102), thickness: 0.8, indent: 30, endIndent: 30),
                        const SizedBox(height: 2),
                        Text('Authorized Signatory',
                            style: GoogleFonts.beVietnamPro(fontSize: 9, color: textColor.withAlpha(115), fontStyle: FontStyle.italic)),
                      ])
                    : Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 14,
                        runSpacing: 10,
                        children: signatories.map((s) => SizedBox(
                          width: 92,
                          // Signature ink sits on top of — overlapping down into —
                          // the divider and the printed name beneath it, like a
                          // real signed certificate, instead of in its own box.
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(children: [
                                  Divider(color: accent.withAlpha(102), thickness: 0.8),
                                  const SizedBox(height: 2),
                                  Text(s.name,
                                      style: GoogleFonts.beVietnamPro(fontSize: 9, fontWeight: FontWeight.w700, color: textColor),
                                      textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                  if (s.title.isNotEmpty)
                                    Text(s.title,
                                        style: GoogleFonts.beVietnamPro(fontSize: 8, color: textColor.withAlpha(140)),
                                        textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              if (s.signatureImageBase64 != null)
                                Positioned(
                                  top: -6,
                                  child: Image.memory(base64Decode(s.signatureImageBase64!), height: 30, fit: BoxFit.contain),
                                ),
                            ],
                          ),
                        )).toList(),
                      ),
              ),
              if (verificationCode != null) ...[
                const SizedBox(width: 10),
                Column(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                    child: QrImageView(data: verificationCode!, version: QrVersions.auto, size: 44, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text('Verify', style: GoogleFonts.beVietnamPro(fontSize: 7.5, color: textColor.withAlpha(128))),
                ]),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}
