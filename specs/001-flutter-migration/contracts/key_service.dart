/// Key Service Contract
///
/// SSH Key Managementserviceinterface。
/// keygenerate、port、port、securestorage。

import 'dart:async';

import '../models/ssh_key.dart';

/// keygenerate
class KeyGenerationOptions {
  final KeyType type;
  final int? bits; // RSA: 2048, 3072, 4096
  final String? passphrase;
  final String? comment;

  const KeyGenerationOptions({
    required this.type,
    this.bits,
    this.passphrase,
    this.comment,
  });
}

/// keyportresult
class KeyImportResult {
  final SSHKey key;
  final bool requiresPassphrase;

  const KeyImportResult({
    required this.key,
    required this.requiresPassphrase,
  });
}

/// keyserviceinterface
abstract class KeyService {
  /// keylistretrieve
  Future<List<SSHKey>> listKeys();

  /// keyretrieve
  Future<SSHKey?> getKey(String keyId);

  /// keygenerate
  Future<SSHKey> generateKey({
    required String name,
    required KeyGenerationOptions options,
  });

  /// keyport（PEMformat）
  Future<KeyImportResult> importKey({
    required String name,
    required String privateKeyPem,
    String? passphrase,
  });

  /// keyport（file）
  Future<KeyImportResult> importKeyFromFile({
    required String name,
    required String filePath,
    String? passphrase,
  });

  /// private keyretrieve（authentication）
  Future<String> getPrivateKey({
    required String keyId,
    String? passphrase,
  });

  /// public keyretrieve（OpenSSHformat）
  Future<String> getPublicKey(String keyId);

  /// keydelete
  Future<void> deleteKey(String keyId);

  /// keyupdate
  Future<void> updateKeyName({
    required String keyId,
    required String name,
  });

  /// defaultkeysettings
  Future<void> setDefaultKey(String keyId);

  /// defaultkeyretrieve
  Future<SSHKey?> getDefaultKey();

  /// fingerprint
  Future<String> calculateFingerprint(String publicKey);

  /// key
  KeyType detectKeyType(String privateKeyPem);

  /// passphraseverify
  Future<bool> verifyPassphrase({
    required String keyId,
    required String passphrase,
  });
}



