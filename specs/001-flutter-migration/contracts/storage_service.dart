/// Storage Service Contract
///
/// datapersistserviceinterface。
/// securestoragestorageintegration。

import 'dart:async';

import '../models/connection.dart';
import '../models/app_settings.dart';

/// storageserviceinterface
abstract class StorageService {
  // === Connection ===

  /// connection listretrieve
  Future<List<Connection>> getConnections();

  /// connectionretrieve
  Future<Connection?> getConnection(String id);

  /// connectionsave
  Future<void> saveConnection(Connection connection);

  /// connectiondelete
  Future<void> deleteConnection(String id);

  /// passwordsave（encrypted）
  Future<void> savePassword({
    required String connectionId,
    required String password,
  });

  /// passwordretrieve
  Future<String?> getPassword(String connectionId);

  /// passworddelete
  Future<void> deletePassword(String connectionId);

  // === Settings ===

  /// settingsretrieve
  Future<AppSettings> getSettings();

  /// settingssave
  Future<void> saveSettings(AppSettings settings);

  /// settings
  Future<void> resetSettings();

  // === Migration ===

  /// dataport（JSONformat）
  Future<String> exportData();

  /// dataport（JSONformat）
  Future<void> importData(String json);

  /// alldata
  Future<void> clearAll();
}



