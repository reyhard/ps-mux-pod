import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

import '../keychain/secure_storage.dart';

// Re-export BiometricType from local_auth for convenience
export 'package:local_auth/local_auth.dart' show BiometricType;

/// SSH authentication method
enum SshAuthMethod {
  /// Password authentication
  password,

  /// Public key authentication
  publicKey,
}

/// Biometric authentication result
enum BiometricAuthResult {
  /// Success
  success,

  /// Cancelled
  cancelled,

  /// Unavailable
  notAvailable,

  /// Not enrolled
  notEnrolled,

  /// Locked out (too many attempts)
  lockedOut,

  /// Permanently locked out
  permanentlyLockedOut,

  /// Error
  error,
}

/// SSH authentication credentials
class SshCredential {
  /// Authentication method
  final SshAuthMethod method;

  /// Password (for password authentication)
  final String? password;

  /// Private key (for public key authentication)
  final String? privateKey;

  /// Passphrase (when the private key is encrypted)
  final String? passphrase;

  const SshCredential({
    required this.method,
    this.password,
    this.privateKey,
    this.passphrase,
  });

  /// For password authentication
  const SshCredential.password(this.password)
      : method = SshAuthMethod.password,
        privateKey = null,
        passphrase = null;

  /// For public key authentication
  const SshCredential.publicKey({
    required this.privateKey,
    this.passphrase,
  })  : method = SshAuthMethod.publicKey,
        password = null;

  /// Whether the credentials are valid
  bool get isValid {
    switch (method) {
      case SshAuthMethod.password:
        return password != null && password!.isNotEmpty;
      case SshAuthMethod.publicKey:
        return privateKey != null && privateKey!.isNotEmpty;
    }
  }
}

/// SSH authentication service
///
/// Provides credential management and biometric authentication.
class SshAuthService {
  final SecureStorageService _storage;
  final LocalAuthentication _localAuth;

  /// Whether biometric authentication is required (depends on app settings)
  bool requireBiometricAuth = false;

  SshAuthService({
    SecureStorageService? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ?? SecureStorageService(),
        _localAuth = localAuth ?? LocalAuthentication();

  // ===== Credential retrieval =====

  /// Get the authentication credentials for a connection
  ///
  /// [connectionId] Connection ID
  /// [authMethod] Authentication method
  /// [keyId] SSH key ID to use (for public key authentication)
  Future<SshCredential?> getCredential({
    required String connectionId,
    required SshAuthMethod authMethod,
    String? keyId,
  }) async {
    // If biometric authentication is required
    if (requireBiometricAuth) {
      final bioResult = await authenticateWithBiometrics(
        reason: 'Biometric authentication is required to access credentials',
      );
      if (bioResult != BiometricAuthResult.success) {
        return null;
      }
    }

    switch (authMethod) {
      case SshAuthMethod.password:
        final password = await getPassword(connectionId);
        if (password == null) return null;
        return SshCredential.password(password);

      case SshAuthMethod.publicKey:
        if (keyId == null) return null;
        final privateKey = await getPrivateKey(keyId);
        if (privateKey == null) return null;
        final passphrase = await getPassphrase(keyId);
        return SshCredential.publicKey(
          privateKey: privateKey,
          passphrase: passphrase,
        );
    }
  }

  // ===== Password management =====

  /// Get credentials for password authentication
  Future<String?> getPassword(String connectionId) async {
    return _storage.getPassword(connectionId);
  }

  /// Save a password
  Future<void> savePassword(String connectionId, String password) async {
    await _storage.savePassword(connectionId, password);
  }

  /// Delete a password
  Future<void> deletePassword(String connectionId) async {
    await _storage.deletePassword(connectionId);
  }

  /// Check whether a password is saved
  Future<bool> hasPassword(String connectionId) async {
    final password = await getPassword(connectionId);
    return password != null && password.isNotEmpty;
  }

  // ===== SSH key management =====

  /// Retrieve a private key
  Future<String?> getPrivateKey(String keyId) async {
    return _storage.getPrivateKey(keyId);
  }

  /// Save a private key
  Future<void> savePrivateKey(String keyId, String privateKey) async {
    await _storage.savePrivateKey(keyId, privateKey);
  }

  /// Delete a private key
  Future<void> deletePrivateKey(String keyId) async {
    await _storage.deletePrivateKey(keyId);
  }

  /// Retrieve a passphrase
  Future<String?> getPassphrase(String keyId) async {
    return _storage.getPassphrase(keyId);
  }

  /// Save a passphrase
  Future<void> savePassphrase(String keyId, String passphrase) async {
    await _storage.savePassphrase(keyId, passphrase);
  }

  /// Delete a passphrase
  Future<void> deletePassphrase(String keyId) async {
    await _storage.deletePassphrase(keyId);
  }

  /// Check whether a private key is saved
  Future<bool> hasPrivateKey(String keyId) async {
    final key = await getPrivateKey(keyId);
    return key != null && key.isNotEmpty;
  }

  // ===== Biometric authentication =====

  /// Check whether biometric authentication is available
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Check whether the device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Get the available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Perform biometric authentication
  ///
  /// [reason] Reason shown to the user
  Future<BiometricAuthResult> authenticateWithBiometrics({
    String reason = 'Please authenticate',
  }) async {
    try {
      // Check whether biometric authentication is available
      final canCheck = await canCheckBiometrics();
      final isSupported = await isDeviceSupported();

      if (!canCheck || !isSupported) {
        return BiometricAuthResult.notAvailable;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );

      return authenticated ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
    } on PlatformException catch (e) {
      return _handleAuthError(e);
    }
  }

  /// Authenticate (biometric or device PIN/pattern)
  ///
  /// If biometric auth is unavailable, fall back to device authentication (PIN/pattern, etc.)
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate',
  }) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return BiometricAuthResult.notAvailable;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
      );

      return authenticated ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
    } on PlatformException catch (e) {
      return _handleAuthError(e);
    }
  }

  /// Handle authentication errors
  BiometricAuthResult _handleAuthError(PlatformException e) {
    // Return a result based on the local_auth error code
    final code = e.code;
    if (code == 'NotEnrolled' || code == 'notEnrolled') {
      return BiometricAuthResult.notEnrolled;
    } else if (code == 'LockedOut' || code == 'lockedOut') {
      return BiometricAuthResult.lockedOut;
    } else if (code == 'PermanentlyLockedOut' || code == 'permanentlyLockedOut') {
      return BiometricAuthResult.permanentlyLockedOut;
    } else if (code == 'NotAvailable' || code == 'notAvailable') {
      return BiometricAuthResult.notAvailable;
    }
    return BiometricAuthResult.error;
  }

  /// Cancel authentication
  Future<bool> stopAuthentication() async {
    return _localAuth.stopAuthentication();
  }

  // ===== Bulk credential operations =====

  /// Delete all credentials for a connection
  Future<void> deleteConnectionCredentials(String connectionId) async {
    await deletePassword(connectionId);
  }

  /// Delete all credentials for an SSH key
  Future<void> deleteKeyCredentials(String keyId) async {
    await Future.wait([
      deletePrivateKey(keyId),
      deletePassphrase(keyId),
    ]);
  }

  /// Delete all credentials
  Future<void> deleteAllCredentials() async {
    await _storage.deleteAll();
  }
}

/// Factory function
SshAuthService createSshAuthService({
  SecureStorageService? storage,
}) {
  return SshAuthService(storage: storage);
}
