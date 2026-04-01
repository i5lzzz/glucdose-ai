// lib/data/mappers/encryption_mapper.dart
// ─────────────────────────────────────────────────────────────────────────────
// EncryptionMapper — thin async helpers for encrypting/decrypting typed values.
//
// WHY A SEPARATE CLASS:
//   All repository mappers need to encrypt/decrypt specific types (double, String,
//   List<String>).  This class provides typed converters so mapper code reads as:
//     final dose = await enc.decryptDouble(dto.doseUnitsEnc);
//   rather than:
//     final raw = await service.decrypt(dto.doseUnitsEnc);
//     final dose = double.parse(raw);
//
//   It also provides a null-safe variant for optional encrypted fields.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:insulin_assistant/core/errors/app_failures.dart';
import 'package:insulin_assistant/core/security/encryption_service.dart';
import 'package:insulin_assistant/domain/core/result.dart';

final class EncryptionMapper {
  const EncryptionMapper(this._enc);

  final EncryptionService _enc;

  // ── Encrypt ────────────────────────────────────────────────────────────────

  Future<String> encryptString(String value) => _enc.encrypt(value);

  Future<String> encryptDouble(double value) =>
      _enc.encrypt(value.toString());

  Future<String> encryptInt(int value) =>
      _enc.encrypt(value.toString());

  Future<String> encryptStringList(List<String> values) =>
      _enc.encrypt(values.join(','));

  Future<String> encryptBool(bool value) =>
      _enc.encrypt(value ? '1' : '0');

  Future<String?> encryptOptionalString(String? value) async {
    if (value == null) return null;
    return _enc.encrypt(value);
  }

  Future<String?> encryptOptionalDouble(double? value) async {
    if (value == null) return null;
    return _enc.encrypt(value.toString());
  }

  // ── Decrypt ────────────────────────────────────────────────────────────────

  Future<String> decryptString(String ciphertext) =>
      _enc.decrypt(ciphertext);

  Future<double> decryptDouble(String ciphertext) async {
    final plain = await _enc.decrypt(ciphertext);
    final v = double.tryParse(plain);
    if (v == null) throw DecryptionTypeError('double', plain);
    return v;
  }

  Future<int> decryptInt(String ciphertext) async {
    final plain = await _enc.decrypt(ciphertext);
    final v = int.tryParse(plain);
    if (v == null) throw DecryptionTypeError('int', plain);
    return v;
  }

  Future<List<String>> decryptStringList(String ciphertext) async {
    final plain = await _enc.decrypt(ciphertext);
    if (plain.isEmpty) return [];
    return plain.split(',').map((s) => s.trim()).toList();
  }

  Future<bool> decryptBool(String ciphertext) async {
    final plain = await _enc.decrypt(ciphertext);
    return plain == '1';
  }

  Future<String?> decryptOptionalString(String? ciphertext) async {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    return _enc.decrypt(ciphertext);
  }

  Future<double?> decryptOptionalDouble(String? ciphertext) async {
    if (ciphertext == null || ciphertext.isEmpty) return null;
    return decryptDouble(ciphertext);
  }

  // ── JSON ───────────────────────────────────────────────────────────────────

  Future<String> encryptJson(Map<String, dynamic> json) =>
      _enc.encryptMap(json);

  Future<Map<String, dynamic>> decryptJson(String ciphertext) =>
      _enc.decryptMap(ciphertext);

  // ── Result-wrapped versions (for use inside Result pipelines) ──────────────

  Future<Result<double>> safeDecryptDouble(String ciphertext) async {
    try {
      return Result.success(await decryptDouble(ciphertext));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Decryption failed for double: $e'),
      );
    }
  }

  Future<Result<String>> safeDecryptString(String ciphertext) async {
    try {
      return Result.success(await decryptString(ciphertext));
    } catch (e) {
      return Result.failure(
        DatabaseFailure('Decryption failed for string: $e'),
      );
    }
  }
}

/// Thrown when a decrypted plaintext cannot be parsed to the expected type.
final class DecryptionTypeError implements Exception {
  const DecryptionTypeError(this.expectedType, this.plaintext);
  final String expectedType;
  final String plaintext;

  @override
  String toString() =>
      'DecryptionTypeError: expected $expectedType, got "$plaintext"';
}
