import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device_models.dart';

class DeviceRepository {
  DeviceRepository({this.deviceId = 'device01', http.Client? client})
    : _client = client ?? http.Client();

  final String deviceId;
  final http.Client _client;

  static const String _databaseUrl =
      'https://odienpremiumiot-default-rtdb.asia-southeast1.firebasedatabase.app';
  static const String _databaseAuth = '';

  static const Duration _dashboardPollInterval = Duration(seconds: 2);
  static const Duration _historyPollInterval = Duration(seconds: 3);

  Future<ConnectionSummary> fetchConnectionSummary() async {
    final snapshot = await _fetchSnapshot();
    return _buildConnectionSummary(
      snapshot.deviceValue,
      snapshot.smartHomeValue,
    );
  }

  Stream<DeviceDashboard> watchDashboard() {
    return _poll<DeviceDashboard>(
      loader: () async {
        final snapshot = await _fetchSnapshot();
        return _buildDashboard(snapshot.deviceValue, snapshot.smartHomeValue);
      },
      interval: _dashboardPollInterval,
    );
  }

  Stream<List<HistoryEntry>> watchHistory({int limit = 60}) {
    return _poll<List<HistoryEntry>>(
      loader: () async {
        final historyValue = await _getValue(_devicePath('history'));
        final entries = _parseHistory(asStringMap(historyValue));
        if (entries.length <= limit) {
          return entries;
        }
        return entries.sublist(0, limit);
      },
      interval: _historyPollInterval,
    );
  }

  Future<void> sendRelayCommand({
    required String relayId,
    required bool turnOn,
    String source = 'app',
    bool? mirrorLegacyState,
  }) async {
    final shouldMirrorState =
        mirrorLegacyState ?? await _shouldMirrorRelayStateForDevice();

    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = <String, dynamic>{
      'commandId': 'cmd_$now',
      'target': relayId,
      'action': turnOn ? 'on' : 'off',
      'source': source,
      'createdAt': now,
    };

    final writes = <Future<void>>[
      _setValue(_devicePath('command/latest'), payload),
      _patchValue(_devicePath('state'), <String, dynamic>{relayId: turnOn}),
    ];

    if (shouldMirrorState) {
      writes.add(
        _patchValue('smart_home/relays', <String, dynamic>{relayId: turnOn}),
      );
    }

    await Future.wait<void>(writes);
  }

  Future<void> saveSettings(DeviceSettings settings) async {
    await Future.wait<void>(<Future<void>>[
      _patchValue(_devicePath('info'), <String, dynamic>{
        'name': settings.deviceName,
        'location': settings.location,
        'relayNames': settings.relayLabels,
      }),
      _patchValue(_devicePath('settings'), <String, dynamic>{
        'mode': settings.mode,
        'buzzerEnabled': settings.buzzerEnabled,
        'buzzerEnable': settings.buzzerEnabled,
        'tempLimit': settings.tempLimit,
        'lightLimit': settings.lightLimit,
        'relayLabels': settings.relayLabels,
      }),
    ]);
  }

  Stream<T> _poll<T>({
    required Future<T> Function() loader,
    required Duration interval,
  }) {
    return Stream<T>.multi((StreamController<T> controller) {
      var active = true;
      var busy = false;

      Future<void> emit() async {
        if (!active || busy) {
          return;
        }

        busy = true;
        try {
          controller.add(await loader());
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        } finally {
          busy = false;
        }
      }

      unawaited(emit());
      final timer = Timer.periodic(interval, (_) => unawaited(emit()));

      controller.onCancel = () {
        active = false;
        timer.cancel();
      };
    });
  }

  Future<_DatabaseSnapshot> _fetchSnapshot() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _getValue(_deviceBasePath),
      _getValue('smart_home'),
    ]);

    return _DatabaseSnapshot(
      deviceValue: results[0],
      smartHomeValue: results[1],
    );
  }

  String get _deviceBasePath => 'devices/$deviceId';

  String _devicePath(String child) => '$_deviceBasePath/$child';

  Uri _uriFor(String path) {
    final baseUri = Uri.parse(_databaseUrl);
    final normalizedBasePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    final queryParameters = <String, String>{
      ...baseUri.queryParameters,
      if (_databaseAuth.isNotEmpty) 'auth': _databaseAuth,
    };

    return baseUri.replace(
      path: '$normalizedBasePath/$path.json',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Future<Object?> _getValue(String path) async {
    final response = await _client.get(_uriFor(path));
    _ensureSuccess(response, path);
    return _decodeResponse(response);
  }

  Future<void> _setValue(String path, Object? value) async {
    final response = await _client.put(
      _uriFor(path),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(value),
    );
    _ensureSuccess(response, path);
  }

  Future<void> _patchValue(String path, Map<String, dynamic> value) async {
    final response = await _client.patch(
      _uriFor(path),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(value),
    );
    _ensureSuccess(response, path);
  }

  Object? _decodeResponse(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty || body.trim() == 'null') {
      return null;
    }
    return jsonDecode(body);
  }

  void _ensureSuccess(http.Response response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Firebase REST failed for $path (${response.statusCode})',
        _uriFor(path),
      );
    }
  }

  ConnectionSummary _buildConnectionSummary(
    Object? deviceValue,
    Object? smartHomeValue,
  ) {
    final dashboard = _buildDashboard(deviceValue, smartHomeValue);
    final hasDeviceNode = asStringMap(deviceValue).isNotEmpty;
    final hasLegacyBridge = asStringMap(smartHomeValue).isNotEmpty;

    final message = dashboard.isOnline
        ? 'Firebase da phan hoi va thiet bi dang gui trang thai.'
        : hasDeviceNode || hasLegacyBridge
        ? 'Da ket noi database, nhung thiet bi hien chua gui heartbeat moi.'
        : 'Chua tim thay node du lieu phu hop cho thiet bi.';

    return ConnectionSummary(
      deviceId: deviceId,
      deviceName: dashboard.name,
      isReachable: hasDeviceNode || hasLegacyBridge,
      isOnline: dashboard.isOnline,
      hasLegacyBridge: hasLegacyBridge,
      message: message,
    );
  }

  DeviceDashboard _buildDashboard(Object? deviceValue, Object? smartHomeValue) {
    final deviceMap = asStringMap(deviceValue);
    final smartHomeMap = asStringMap(smartHomeValue);

    final stateMap = _resolveStateMap(deviceMap);
    final infoMap = _resolveInfoMap(deviceMap, stateMap);
    final settingsMap = _resolveSettingsMap(deviceMap, stateMap);
    final commandMap = asStringMap(asStringMap(deviceMap['command'])['latest']);
    final historyEntries = _parseHistory(asStringMap(deviceMap['history']));
    final prefersLegacyRelayWrite = _shouldMirrorRelayState(deviceMap);

    final smartRelays = asStringMap(smartHomeMap['relays']);
    final smartSensors = asStringMap(smartHomeMap['sensors']);
    final smartStatus = asStringMap(smartHomeMap['status']);

    final relayLabels = <String, String>{
      ...relayDefaultLabels,
      ...readStringMap(settingsMap['relayLabels']),
      ...readStringMap(infoMap['relayNames']),
    };

    final settings = DeviceSettings(
      deviceName:
          readString(infoMap['name']) ??
          readString(infoMap['deviceName']) ??
          'O dien thong minh',
      location: readString(infoMap['location']) ?? 'Phong khach',
      mode:
          (readString(stateMap['mode']) ??
                  readString(settingsMap['mode']) ??
                  'manual')
              .toLowerCase(),
      buzzerEnabled:
          readBool(settingsMap['buzzerEnabled']) ??
          readBool(settingsMap['buzzerEnable']) ??
          _invertNullableBool(readBool(stateMap['buzzerMuted'])) ??
          true,
      tempLimit: readDouble(settingsMap['tempLimit']) ?? 40,
      lightLimit: readDouble(settingsMap['lightLimit']) ?? 75,
      relayLabels: relayLabels,
    );

    final latestCommand = commandMap.isEmpty
        ? null
        : DeviceCommand(
            commandId:
                readString(commandMap['commandId']) ?? 'cmd_manual_preview',
            target: readString(commandMap['target']) ?? 'relay1',
            action: readString(commandMap['action']) ?? 'toggle',
            source: readString(commandMap['source']) ?? 'app',
            createdAt: readDateTime(commandMap['createdAt']),
          );

    final deviceClock = _readDeviceClock(stateMap);

    final lastSeen =
        readDateTime(stateMap['lastSeen']) ??
        deviceClock ??
        readDateTime(smartStatus['lastSeen']) ??
        (historyEntries.isNotEmpty ? historyEntries.first.time : null);

    final bool isOnline =
        readBool(stateMap['online']) ??
        readBool(smartStatus['online']) ??
        (lastSeen != null &&
            DateTime.now().difference(lastSeen) <= const Duration(minutes: 5));

    final relays = relayIds
        .map((String relayId) {
          final latestEntry = _latestRelayEntry(historyEntries, relayId);
          final relayState =
              readBool(stateMap[relayId]) ??
              readBool(smartRelays[relayId]) ??
              latestEntry?.newValue ??
              false;

          return RelayChannel(
            id: relayId,
            label: relayDisplayName(relayId, relayLabels),
            isOn: relayState,
            lastChangedAt: latestEntry?.time,
            lastSource: latestEntry?.source,
          );
        })
        .toList(growable: false);

    final environment = EnvironmentSnapshot(
      temperature:
          readDouble(stateMap['temperature']) ??
          readDouble(smartSensors['temperature']),
      humidity:
          readDouble(stateMap['humidity']) ??
          readDouble(smartSensors['humidity']),
      light: readDouble(stateMap['light']) ?? readDouble(smartSensors['light']),
      lightPercent:
          readDouble(stateMap['lightPercent']) ??
          readDouble(smartSensors['light_percent']),
      lightDigital: readBool(stateMap['lightDigital']),
      lightText: readString(stateMap['lightText']),
    );

    return DeviceDashboard(
      deviceId: deviceId,
      name: settings.deviceName,
      location: settings.location,
      mode: settings.mode,
      isOnline: isOnline,
      lastSeen: lastSeen,
      environment: environment,
      relays: relays,
      latestCommand: latestCommand,
      settings: settings,
      overTempLock: readBool(stateMap['overTempLock']) ?? false,
      buzzerMuted: readBool(stateMap['buzzerMuted']) ?? !settings.buzzerEnabled,
      uptime: readString(stateMap['uptime']),
      timeNow: readString(stateMap['timeNow']),
      dateNow: readString(stateMap['dateNow']),
      prefersLegacyRelayWrite: prefersLegacyRelayWrite,
    );
  }

  Map<String, dynamic> _resolveInfoMap(
    Map<String, dynamic> deviceMap,
    Map<String, dynamic> stateMap,
  ) {
    final infoMap = asStringMap(deviceMap['info']);
    if (infoMap.isNotEmpty) {
      return infoMap;
    }

    final flatSource =
        deviceMap.containsKey('deviceName') || deviceMap.containsKey('location')
        ? deviceMap
        : stateMap;

    return <String, dynamic>{
      if (flatSource.containsKey('deviceName'))
        'name': flatSource['deviceName'],
      if (flatSource.containsKey('location'))
        'location': flatSource['location'],
      if (flatSource.containsKey('relayLabels'))
        'relayNames': flatSource['relayLabels'],
    };
  }

  Map<String, dynamic> _resolveStateMap(Map<String, dynamic> deviceMap) {
    final stateMap = asStringMap(deviceMap['state']);
    if (stateMap.isNotEmpty) {
      return stateMap;
    }

    return <String, dynamic>{
      for (final MapEntry<String, dynamic> entry in deviceMap.entries)
        if (!_isStructuredChildKey(entry.key)) entry.key: entry.value,
    };
  }

  Map<String, dynamic> _resolveSettingsMap(
    Map<String, dynamic> deviceMap,
    Map<String, dynamic> stateMap,
  ) {
    final settingsMap = asStringMap(deviceMap['settings']);
    if (settingsMap.isNotEmpty) {
      return settingsMap;
    }

    return <String, dynamic>{
      if (deviceMap.containsKey('relayLabels'))
        'relayLabels': deviceMap['relayLabels'],
      if (stateMap.containsKey('buzzerMuted'))
        'buzzerEnabled': !(readBool(stateMap['buzzerMuted']) ?? false),
    };
  }

  Future<bool> _shouldMirrorRelayStateForDevice() async {
    try {
      final deviceValue = await _getValue(_deviceBasePath);
      return _shouldMirrorRelayState(asStringMap(deviceValue));
    } catch (_) {
      return false;
    }
  }

  bool _shouldMirrorRelayState(Map<String, dynamic> deviceMap) {
    if (deviceMap.isEmpty) {
      return false;
    }

    final stateMap = _resolveStateMap(deviceMap);
    if (stateMap.isEmpty) {
      return false;
    }

    if (stateMap.containsKey('lastCommandId')) {
      return false;
    }

    if (asStringMap(deviceMap['info']).isNotEmpty ||
        asStringMap(deviceMap['settings']).isNotEmpty ||
        asStringMap(deviceMap['history']).isNotEmpty) {
      return false;
    }

    const legacyMarkers = <String>{
      'deviceId',
      'deviceName',
      'location',
      'timeNow',
      'dateNow',
      'uptime',
      'lightText',
      'overTempLock',
      'buzzerMuted',
    };

    return stateMap.keys.any(legacyMarkers.contains);
  }

  bool _isStructuredChildKey(String key) {
    switch (key) {
      case 'info':
      case 'state':
      case 'settings':
      case 'command':
      case 'history':
        return true;
      default:
        return false;
    }
  }

  bool? _invertNullableBool(bool? value) {
    if (value == null) {
      return null;
    }
    return !value;
  }

  DateTime? _readDeviceClock(Map<String, dynamic> stateMap) {
    final dateText = readString(stateMap['dateNow']);
    final timeText = readString(stateMap['timeNow']);
    if (dateText == null || timeText == null) {
      return null;
    }

    final dateParts = dateText.split('/');
    final timeParts = timeText.split(':');
    if (dateParts.length != 3 || timeParts.length != 3) {
      return null;
    }

    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = int.tryParse(timeParts[2]);

    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute, second);
  }

  List<HistoryEntry> _parseHistory(Map<String, dynamic> historyMap) {
    final entries = <HistoryEntry>[];

    for (final MapEntry<String, dynamic> entry in historyMap.entries) {
      final data = asStringMap(entry.value);
      if (data.isEmpty) {
        continue;
      }
      entries.add(HistoryEntry.fromMap(entry.key, data));
    }

    entries.sort((HistoryEntry a, HistoryEntry b) {
      final aTime = a.time?.millisecondsSinceEpoch ?? 0;
      final bTime = b.time?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    return entries;
  }

  HistoryEntry? _latestRelayEntry(
    List<HistoryEntry> historyEntries,
    String relayId,
  ) {
    for (final HistoryEntry entry in historyEntries) {
      if (entry.target == relayId) {
        return entry;
      }
    }
    return null;
  }
}

class _DatabaseSnapshot {
  const _DatabaseSnapshot({
    required this.deviceValue,
    required this.smartHomeValue,
  });

  final Object? deviceValue;
  final Object? smartHomeValue;
}
