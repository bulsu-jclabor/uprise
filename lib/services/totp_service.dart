// lib/services/totp_service.dart
//
// Minimal RFC 6238 TOTP (Time-based One-Time Password) implementation —
// the same algorithm used by Google Authenticator, Authy, etc. No external
// OTP package is added; this uses only `crypto` (already a dependency) for
// HMAC-SHA1 and a small hand-rolled RFC 4648 Base32 codec, since the
// `otpauth://` URI standard that authenticator apps expect requires the
// secret to be Base32, not Base64/hex.
//
// Security note: the shared secret is stored in Firestore under the user's
// own settings doc (readable only by that user, same as other security
// settings here). This is genuine second-factor verification — a stolen
// password alone can't get in — but it isn't a hardware-backed or
// server-validated secret store, so treat it as "real campus-app 2FA",
// not bank-grade.

import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpService {
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const int _digits = 6;
  static const int _periodSeconds = 30;

  /// Generates a fresh random 20-byte (160-bit) secret, Base32-encoded —
  /// the standard secret length used by authenticator apps.
  static String generateSecret() {
    final rand = Random.secure();
    final bytes = Uint8List.fromList(List.generate(20, (_) => rand.nextInt(256)));
    return _base32Encode(bytes);
  }

  /// Builds the `otpauth://totp/...` URI an authenticator app's QR scanner
  /// expects, so users can set this up with Google Authenticator/Authy/etc.
  static String buildOtpAuthUri({
    required String secret,
    required String accountName,
    String issuer = 'Uprise',
  }) {
    final label = Uri.encodeComponent('$issuer:$accountName');
    final encodedIssuer = Uri.encodeComponent(issuer);
    return 'otpauth://totp/$label?secret=$secret&issuer=$encodedIssuer&digits=$_digits&period=$_periodSeconds&algorithm=SHA1';
  }

  /// Generates the current 6-digit TOTP code for [secret]. Exposed mainly
  /// for testing — verification should go through [verifyCode].
  static String generateCode(String secret, {DateTime? at}) {
    final time = at ?? DateTime.now().toUtc();
    final counter = time.millisecondsSinceEpoch ~/ 1000 ~/ _periodSeconds;
    return _hotp(secret, counter);
  }

  /// Verifies a user-entered code against the current time step, allowing
  /// ±1 step (30s) of clock drift either side — the standard tolerance
  /// window for TOTP verification.
  static bool verifyCode(String secret, String code, {DateTime? at}) {
    final normalized = code.trim();
    if (normalized.length != _digits || int.tryParse(normalized) == null) return false;
    final time = at ?? DateTime.now().toUtc();
    final counter = time.millisecondsSinceEpoch ~/ 1000 ~/ _periodSeconds;
    for (final offset in [0, -1, 1]) {
      if (_hotp(secret, counter + offset) == normalized) return true;
    }
    return false;
  }

  static String _hotp(String base32Secret, int counter) {
    final keyBytes = _base32Decode(base32Secret);
    final counterBytes = ByteData(8)..setInt64(0, counter, Endian.big);
    final hmac = Hmac(sha1, keyBytes);
    final hash = hmac.convert(counterBytes.buffer.asUint8List()).bytes;

    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
        ((hash[offset + 1] & 0xff) << 16) |
        ((hash[offset + 2] & 0xff) << 8) |
        (hash[offset + 3] & 0xff);
    final code = binary % pow(10, _digits).toInt();
    return code.toString().padLeft(_digits, '0');
  }

  static String _base32Encode(Uint8List bytes) {
    final buffer = StringBuffer();
    int bitBuffer = 0;
    int bitsInBuffer = 0;
    for (final byte in bytes) {
      bitBuffer = (bitBuffer << 8) | byte;
      bitsInBuffer += 8;
      while (bitsInBuffer >= 5) {
        bitsInBuffer -= 5;
        buffer.write(_base32Alphabet[(bitBuffer >> bitsInBuffer) & 0x1f]);
      }
    }
    if (bitsInBuffer > 0) {
      buffer.write(_base32Alphabet[(bitBuffer << (5 - bitsInBuffer)) & 0x1f]);
    }
    return buffer.toString();
  }

  static Uint8List _base32Decode(String input) {
    final cleaned = input.toUpperCase().replaceAll('=', '');
    int bitBuffer = 0;
    int bitsInBuffer = 0;
    final out = <int>[];
    for (final char in cleaned.split('')) {
      final index = _base32Alphabet.indexOf(char);
      if (index < 0) continue;
      bitBuffer = (bitBuffer << 5) | index;
      bitsInBuffer += 5;
      if (bitsInBuffer >= 8) {
        bitsInBuffer -= 8;
        out.add((bitBuffer >> bitsInBuffer) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }

  /// Formats a secret with spaces every 4 chars for easier manual entry
  /// (e.g. "ABCD EFGH IJKL ...").
  static String formatSecretForDisplay(String secret) {
    final chunks = <String>[];
    for (var i = 0; i < secret.length; i += 4) {
      chunks.add(secret.substring(i, min(i + 4, secret.length)));
    }
    return chunks.join(' ');
  }
}
