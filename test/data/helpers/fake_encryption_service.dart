// test/data/helpers/fake_encryption_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// FakeEncryptionService — deterministic, synchronous encryption substitute.
//
// WHY NOT REAL AES IN TESTS:
//   Real AES requires Keychain/Keystore on device, unavailable in unit tests.
//   This fake uses a trivially reversible transformation (Base64) so:
//     1. Tests remain deterministic
//     2. "Encrypted" data is visually distinguishable from plaintext in logs
//     3. Decrypt(Encrypt(x)) == x — the round-trip contract is preserved
//
// NEVER use this in production — it is not cryptographically secure.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:insulin_assistant/core/security/encryption_service.dart';
import 'package:insulin_assistant/core/security/key_manager.dart';

/// Production [EncryptionService] replacement for tests.
/// Encodes values as Base64 instead of AES — preserves the interface contract.
final class FakeEncryptionService extends EncryptionService {
  FakeEncryptionService() : super(_FakeKeyManager());

  @override
  Future<String> encrypt(String plaintext) async =>
      'FAKE:${base64Encode(utf8.encode(plaintext))}';

  @override
  Future<String> decrypt(String ciphertext) async {
    if (ciphertext.startsWith('FAKE:')) {
      return utf8.decode(base64Decode(ciphertext.substring(5)));
    }
    // Handle already-plaintext values in test data
    return ciphertext;
  }

  @override
  Future<String> encryptMap(Map<String, dynamic> data) =>
      encrypt(jsonEncode(data));

  @override
  Future<Map<String, dynamic>> decryptMap(String ciphertext) async {
    final plain = await decrypt(ciphertext);
    return jsonDecode(plain) as Map<String, dynamic>;
  }

  @override
  Future<void> selfTest() async {} // Always passes in test context
}

final class _FakeKeyManager extends KeyManager {
  @override
  Future<List<int>> get encryptionKey async =>
      List.generate(32, (i) => i); // Deterministic fake key

  @override
  Future<List<int>> get iv async =>
      List.generate(16, (i) => i); // Deterministic fake IV

  @override
  Future<void> ensureKeysExist() async {}
}
