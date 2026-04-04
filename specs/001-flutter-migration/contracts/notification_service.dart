/// Notification Service Contract
///
/// Notification Rulesmanagementprocessingserviceinterface。

import 'dart:async';

import '../models/notification_rule.dart';

/// notification
class NotificationEvent {
  final String ruleId;
  final String ruleName;
  final String connectionId;
  final String? sessionName;
  final int? windowIndex;
  final int? paneIndex;
  final String matchedText;
  final DateTime timestamp;

  const NotificationEvent({
    required this.ruleId,
    required this.ruleName,
    required this.connectionId,
    this.sessionName,
    this.windowIndex,
    this.paneIndex,
    required this.matchedText,
    required this.timestamp,
  });
}

/// notificationserviceinterface
abstract class NotificationService {
  /// notification
  Stream<NotificationEvent> get notifications;

  /// rulelistretrieve
  Future<List<NotificationRule>> listRules();

  /// ruleretrieve
  Future<NotificationRule?> getRule(String ruleId);

  /// rulecreate
  Future<NotificationRule> createRule(NotificationRule rule);

  /// ruleupdate
  Future<void> updateRule(NotificationRule rule);

  /// ruledelete
  Future<void> deleteRule(String ruleId);

  /// ruleenabled/disabledswitch
  Future<void> toggleRule({
    required String ruleId,
    required bool enabled,
  });

  /// outputcheck（internal）
  void checkOutput({
    required String connectionId,
    required String sessionName,
    required int windowIndex,
    required int paneIndex,
    required String output,
  });

  /// session（once_per_session）
  void resetSession(String connectionId);

  /// notificationhistoryretrieve
  Future<List<NotificationEvent>> getHistory({
    int limit = 50,
    String? connectionId,
  });

  /// notificationhistory
  Future<void> clearHistory();
}



