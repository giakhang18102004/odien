import 'package:flutter/foundation.dart';

const List<String> relayIds = <String>['relay1', 'relay2', 'relay3', 'relay4'];

const Map<String, String> relayDefaultLabels = <String, String>{
  'relay1': 'Den ban',
  'relay2': 'Quat',
  'relay3': 'Sac',
  'relay4': 'Du phong',
};

@immutable
class ConnectionSummary {
  const ConnectionSummary({
    required this.deviceId,
    required this.deviceName,
    required this.isReachable,
    required this.isOnline,
    required this.hasLegacyBridge,
    required this.message,
  });

  final String deviceId;
  final String deviceName;
  final bool isReachable;
  final bool isOnline;
  final bool hasLegacyBridge;
  final String message;
}

@immutable
class DeviceDashboard {
  const DeviceDashboard({
    required this.deviceId,
    required this.name,
    required this.location,
    required this.mode,
    required this.isOnline,
    required this.lastSeen,
    required this.environment,
    required this.relays,
    required this.latestCommand,
    required this.settings,
    required this.overTempLock,
    required this.buzzerMuted,
    required this.uptime,
    required this.timeNow,
    required this.dateNow,
    required this.prefersLegacyRelayWrite,
  });

  factory DeviceDashboard.empty(String deviceId) {
    final settings = DeviceSettings.initial();
    return DeviceDashboard(
      deviceId: deviceId,
      name: settings.deviceName,
      location: settings.location,
      mode: settings.mode,
      isOnline: false,
      lastSeen: null,
      environment: const EnvironmentSnapshot(),
      relays: relayIds
          .map(
            (String relayId) => RelayChannel(
              id: relayId,
              label: relayDisplayName(relayId, settings.relayLabels),
              isOn: false,
              lastChangedAt: null,
              lastSource: null,
            ),
          )
          .toList(growable: false),
      latestCommand: null,
      settings: settings,
      overTempLock: false,
      buzzerMuted: false,
      uptime: null,
      timeNow: null,
      dateNow: null,
      prefersLegacyRelayWrite: false,
    );
  }

  final String deviceId;
  final String name;
  final String location;
  final String mode;
  final bool isOnline;
  final DateTime? lastSeen;
  final EnvironmentSnapshot environment;
  final List<RelayChannel> relays;
  final DeviceCommand? latestCommand;
  final DeviceSettings settings;
  final bool overTempLock;
  final bool buzzerMuted;
  final String? uptime;
  final String? timeNow;
  final String? dateNow;
  final bool prefersLegacyRelayWrite;
}

@immutable
class RelayChannel {
  const RelayChannel({
    required this.id,
    required this.label,
    required this.isOn,
    required this.lastChangedAt,
    required this.lastSource,
  });

  final String id;
  final String label;
  final bool isOn;
  final DateTime? lastChangedAt;
  final String? lastSource;
}

@immutable
class EnvironmentSnapshot {
  const EnvironmentSnapshot({
    this.temperature,
    this.humidity,
    this.light,
    this.lightPercent,
    this.lightDigital,
    this.lightText,
  });

  final double? temperature;
  final double? humidity;
  final double? light;
  final double? lightPercent;
  final bool? lightDigital;
  final String? lightText;
}

@immutable
class DeviceCommand {
  const DeviceCommand({
    required this.commandId,
    required this.target,
    required this.action,
    required this.source,
    required this.createdAt,
  });

  final String commandId;
  final String target;
  final String action;
  final String source;
  final DateTime? createdAt;

  bool? get desiredState {
    switch (action.toLowerCase()) {
      case 'on':
        return true;
      case 'off':
        return false;
      default:
        return null;
    }
  }
}

@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.eventType,
    required this.target,
    required this.source,
    required this.oldValue,
    required this.newValue,
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.light,
  });

  factory HistoryEntry.fromMap(String id, Map<String, dynamic> data) {
    return HistoryEntry(
      id: id,
      eventType: readString(data['eventType']) ?? 'relay_change',
      target: readString(data['target']) ?? 'system',
      source: readString(data['source']) ?? 'unknown',
      oldValue: readBool(data['oldValue']),
      newValue: readBool(data['newValue']),
      time: readDateTime(data['time']),
      temperature: readDouble(data['temperature']),
      humidity: readDouble(data['humidity']),
      light: readDouble(data['light']),
    );
  }

  final String id;
  final String eventType;
  final String target;
  final String source;
  final bool? oldValue;
  final bool? newValue;
  final DateTime? time;
  final double? temperature;
  final double? humidity;
  final double? light;

  bool get isRelayEvent => target.startsWith('relay');
}

@immutable
class DeviceSettings {
  const DeviceSettings({
    required this.deviceName,
    required this.location,
    required this.mode,
    required this.buzzerEnabled,
    required this.tempLimit,
    required this.lightLimit,
    required this.relayLabels,
  });

  factory DeviceSettings.initial() {
    return const DeviceSettings(
      deviceName: 'O dien thong minh',
      location: 'Phong khach',
      mode: 'manual',
      buzzerEnabled: true,
      tempLimit: 40,
      lightLimit: 75,
      relayLabels: relayDefaultLabels,
    );
  }

  final String deviceName;
  final String location;
  final String mode;
  final bool buzzerEnabled;
  final double tempLimit;
  final double lightLimit;
  final Map<String, String> relayLabels;

  DeviceSettings copyWith({
    String? deviceName,
    String? location,
    String? mode,
    bool? buzzerEnabled,
    double? tempLimit,
    double? lightLimit,
    Map<String, String>? relayLabels,
  }) {
    return DeviceSettings(
      deviceName: deviceName ?? this.deviceName,
      location: location ?? this.location,
      mode: mode ?? this.mode,
      buzzerEnabled: buzzerEnabled ?? this.buzzerEnabled,
      tempLimit: tempLimit ?? this.tempLimit,
      lightLimit: lightLimit ?? this.lightLimit,
      relayLabels: relayLabels ?? this.relayLabels,
    );
  }
}

Map<String, dynamic> asStringMap(Object? value) {
  if (value is Map) {
    return value.map(
      (Object? key, Object? entryValue) => MapEntry(key.toString(), entryValue),
    );
  }
  return <String, dynamic>{};
}

Map<String, String> readStringMap(Object? value) {
  final data = asStringMap(value);
  return data.map(
    (String key, dynamic entryValue) =>
        MapEntry(key, entryValue?.toString() ?? ''),
  )..removeWhere((String key, String entryValue) => entryValue.trim().isEmpty);
}

String? readString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool? readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'off':
        return false;
    }
  }
  return null;
}

double? readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? readDateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is num) {
    final intValue = value.toInt();
    if (intValue >= 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intValue);
    }
    if (intValue >= 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
    }
    return null;
  }
  if (value is String) {
    final numberValue = int.tryParse(value);
    if (numberValue != null) {
      return readDateTime(numberValue);
    }
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

String relayDisplayName(String relayId, Map<String, String> overrides) {
  final override = overrides[relayId];
  if (override != null && override.trim().isNotEmpty) {
    return override.trim();
  }
  return relayDefaultLabels[relayId] ?? relayId.toUpperCase();
}
