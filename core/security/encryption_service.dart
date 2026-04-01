// lib/core/security/encryption_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// AES-256-CBC symmetric encryption service.
//
// All PHI (Protected Health Information) — BG readings, doses, meal logs —
// is encrypted before persistence. Plaintext never touches SQLite rows.
//
// Complies with:
//   HIPAA §164.312(e)(2)(ii) — Encryption in transit & at rest
//   GDPR Article 32           — Technical security measures
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;

import 'package:insulin_assistant/core/errors/security_exception.dart';
import 'package:insulin_assistant/core/security/key_manager.dart';

final class EncryptionService {
  EncryptionService(this._keyManager);

  final KeyManager _keyManager;

  /// Encrypts [plaintext] and returns Base64-encoded ciphertext.
  Future<String> encrypt(String plaintext) async {
    try {
      final encrypter = await _buildEncrypter();
      final iv = await _buildIV();
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      return encrypted.base64;
    } catch (e) {
      throw EncryptionFailure('Encryption failed: $e');
    }
  }

  /// Decrypts Base64-encoded [ciphertext] and returns plaintext.
  Future<String> decrypt(String ciphertext) async {
    try {
      final encrypter = await _buildEncrypter();
      final iv = await _buildIV();
      final encrypted = enc.Encrypted.fromBase64(ciphertext);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw DecryptionFailure('Decryption failed — data may be corrupt: $e');
    }
  }

  /// Encrypts a [Map] by JSON-serialising then encrypting.
  Future<String> encryptMap(Map<String, dynamic> data) async {
    return encrypt(jsonEncode(data));
  }

  /// Decrypts back to a [Map].
  Future<Map<String, dynamic>> decryptMap(String ciphertext) async {
    final plaintext = await decrypt(ciphertext);
    return jsonDecode(plaintext) as Map<String, dynamic>;
  }

  /// Self-test: encrypts a known plaintext, decrypts, and verifies round-trip.
  /// Called during bootstrap — throws [EncryptionSelfTestFailure] on failure.
  Future<void> selfTest() async {
    const probe = 'insulin_assistant_selftest_2024';
    final ct = await encrypt(probe);
    final rt = await decrypt(ct);
    if (rt != probe) {
      throw const EncryptionSelfTestFailure(
        'Encryption round-trip self-test failed. '
        'Key material may be corrupted. App cannot start safely.',
      );
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<enc.Encrypter> _buildEncrypter() async {
    final keyBytes = await _keyManager.encryptionKey;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    return enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  }

  Future<enc.IV> _buildIV() async {
    final ivBytes = await _keyManager.iv;
    return enc.IV(Uint8List.fromList(ivBytes));
  }
}
