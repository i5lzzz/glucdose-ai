// lib/core/errors/security_exception.dart

/// Base class for all security-layer failures.
/// These are NEVER swallowed — they surface to the audit log and UI.
sealed class SecurityException implements Exception {
  const SecurityException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class KeyStorageWriteFailure extends SecurityException {
  const KeyStorageWriteFailure(super.message);
}

final class EncryptionFailure extends SecurityException {
  const EncryptionFailure(super.message);
}

final class DecryptionFailure extends SecurityException {
  const DecryptionFailure(super.message);
}

final class EncryptionSelfTestFailure extends SecurityException {
  const EncryptionSelfTestFailure(super.message);
}
