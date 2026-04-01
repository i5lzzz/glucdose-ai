// lib/data/models/base_dto.dart
// ─────────────────────────────────────────────────────────────────────────────
// BaseDTO — root class for all database transfer objects.
//
// DESIGN PRINCIPLES:
//   1. DTOs are PLAIN DATA — no business logic, no validation.
//      They represent exactly what is stored in SQLite rows.
//   2. All PHI columns are stored as encrypted Base64 strings.
//      Non-PHI reference data (food names, categories) may be plaintext.
//   3. Every DTO has a toMap() for insertion and fromMap() for retrieval.
//   4. Timestamps are UTC ISO-8601 strings for portability across timezones.
//
// SEPARATION OF CONCERNS:
//   DTO  ←→  Mapper  ←→  Domain Entity
//   The mapper holds all encryption/decryption and type conversion.
//   The DTO never calls EncryptionService — it only holds string values.
// ─────────────────────────────────────────────────────────────────────────────

/// Marker interface for all database transfer objects.
abstract interface class BaseDTO {
  String get id;
  Map<String, dynamic> toMap();
}
