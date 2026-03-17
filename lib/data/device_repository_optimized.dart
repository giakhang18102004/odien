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

  static const Duration _historyPollInterval = Duration(seconds: 5);
  static const Duration _dashboardStaticRefreshInterval = Duration(seconds: 20);
  static const Duration _sseReconnectDelay = Duration(seconds: 2);
  static const Duration _onlineFreshness = Duration(seconds: 20);
  static const String _readTimeout = '4s';

  final StreamController<void> _dashboardInvalidateController =
      StreamController<void>.broadcast();

  Map<String, dynamic> _infoCache = <String, dynamic>{};
  Map<String, dynamic> _settingsCache = <String, dynamic>{};
  Map<String, dynamic> _stateCache = <String, dynamic>{};
  Map<String, dynamic> _commandCache = <String, dynamic>{};

  Future<ConnectionSummary> fetchConnectionSummary() async {
    final results = await Future.wait<Object?>(<Future<Object?>>[
      _getValue(_devicePath('info')),
      _getValue(_devicePath('state')),
      _getValue(_devicePath('settings')),
    ]);

    _infoCache = asStringMap(results[0]);
    _stateCache = asStringMap(results[1]);
    _settingsCache = asStringMap(results[2]);

    final dashboard = _buildDashboardFromCaches();
    final hasDeviceNode =
        _infoCache.isNotEmpty ||
        _stateCache.isNotEmpty ||
        _settingsCache.isNotEmpty;

    final message = dashboard.isOnline
        ? 'Firebase da phan hoi va thiet bi dang gui trang thai moi.'
        : hasDeviceNode
        ? 'Da tim thay node thiet bi, nhung heartbeat hien chua moi.'
        : 'Chua tim thay node du lieu cho thiet bi.';

    return ConnectionSummary(
      deviceId: deviceId,
      deviceName: dashboard.name,
      isReachable: hasDeviceNode,
      isOnline: dashboard.isOnline,
      hasLegacyBridge: false,
      message: message,
    );
  }

  Stream<DeviceDashboard> watchDashboard() {
    return Stream<DeviceDashboard>.multi((
      StreamController<DeviceDashboard> controller,
    ) {
      var active = true;
      var disposed = false;
      StreamSubscription<Map<String, dynamic>>? stateSubscription;
      StreamSubscription<void>? invalidateSubscription;
      Timer? staticRefreshTimer;

      void emit() {
        if (!active || disposed) {
          return;
        }
        controller.add(_buildDashboardFromCaches());
      }

      Future<void> refreshStatic({bool emitAfter = true}) async {
        final results = await Future.wait<Object?>(<Future<Object?>>[
          _getValue(_devicePath('info')),
          _getValue(_devicePath('settings')),
          _getValue(_devicePath('command/latest')),
        ]);

        _infoCache = asStringMap(results[0]);
        _settingsCache = asStringMap(results[1]);
        _commandCache = asStringMap(results[2]);

        if (emitAfter) {
          emit();
        }
      }

      Future<void> bootstrap() async {
        try {
          await refreshStatic(emitAfter: false);
          _stateCache = asStringMap(await _getValue(_devicePath('state')));
          emit();
        } catch (error, stackTrace) {
          if (!active || disposed) {
            return;
          }
          controller.addError(error, stackTrace);
        }

        if (!active || disposed) {
          return;
        }

        stateSubscription = _streamJsonNode(_devicePath('state')).listen((
          Map<String, dynamic> state,
        ) {
          _stateCache = state;
          emit();
        });

        invalidateSubscription = _dashboardInvalidateController.stream.listen((
          _,
        ) {
          emit();
        });

        staticRefreshTimer = Timer.periodic(
          _dashboardStaticRefreshInterval,
          (_) => unawaited(_refreshStaticSilently(controller, refreshStatic)),
        );
      }

      unawaited(bootstrap());

      controller.onCancel = () async {
        active = false;
        disposed = true;
        staticRefreshTimer?.cancel();
        await stateSubscription?.cancel();
        await invalidateSubscription?.cancel();
      };
    });
  }

  Stream<List<HistoryEntry>> watchHistory({int limit = 60}) {
    return _poll<List<HistoryEntry>>(
      loader: () async {
        final historyValue = await _getValue(
          _devicePath('history'),
          queryParameters: <String, String>{
            'orderBy': jsonEncode(r'$key'),
            'limitToLast': '$limit',
          },
        );
        return _parseHistory(asStringMap(historyValue));
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
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> command = <String, dynamic>{
      'commandId': 'cmd_$now',
      'target': relayId,
      'action': turnOn ? 'on' : 'off',
      'source': source,
      'createdAt': now,
    };

    await _setValue(_devicePath('command/latest'), command);

    _commandCache = command;
    _dashboardInvalidateController.add(null);
  }

  Future<void> saveSettings(DeviceSettings settings) async {
    await _patchValue(_deviceBasePath, <String, dynamic>{
      'info': <String, dynamic>{
        'name': settings.deviceName,
        'location': settings.location,
        'relayNames': settings.relayLabels,
      },
      'settings': <String, dynamic>{
        'mode': settings.mode,
        'buzzerEnabled': settings.buzzerEnabled,
        'buzzerEnable': settings.buzzerEnabled,
        'tempLimit': settings.tempLimit,
        'lightLimit': settings.lightLimit,
        'relayLabels': settings.relayLabels,
      },
    });

    _infoCache = <String, dynamic>{
      'name': settings.deviceName,
      'location': settings.location,
      'relayNames': settings.relayLabels,
    };
    _settingsCache = <String, dynamic>{
      'mode': settings.mode,
      'buzzerEnabled': settings.buzzerEnabled,
      'buzzerEnable': settings.buzzerEnabled,
      'tempLimit': settings.tempLimit,
      'lightLimit': settings.lightLimit,
      'relayLabels': settings.relayLabels,
    };
    _dashboardInvalidateController.add(null);
  }

  void dispose() {
    _dashboardInvalidateController.close();
    _client.close();
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
      final Timer timer = Timer.periodic(interval, (_) => unawaited(emit()));

      controller.onCancel = () {
        active = false;
        timer.cancel();
      };
    });
  }

  Future<void> _refreshStaticSilently(
    StreamController<DeviceDashboard> controller,
    Future<void> Function({bool emitAfter}) refreshStatic,
  ) async {
    try {
      await refreshStatic(emitAfter: true);
    } catch (error, stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }
  }

  Stream<Map<String, dynamic>> _streamJsonNode(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return Stream<Map<String, dynamic>>.multi((
      StreamController<Map<String, dynamic>> controller,
    ) {
      var active = true;
      Object? currentValue;

      Future<void> connectLoop() async {
        while (active) {
          try {
            final http.Request request =
                http.Request(
                    'GET',
                    _uriFor(path, queryParameters: queryParameters),
                  )
                  ..headers['Accept'] = 'text/event-stream'
                  ..headers['Cache-Control'] = 'no-cache';

            final http.StreamedResponse response = await _client.send(request);
            _ensureStreamSuccess(response, path);

            String? currentEvent;
            final StringBuffer dataBuffer = StringBuffer();

            await for (final String line
                in response.stream
                    .transform(utf8.decoder)
                    .transform(const LineSplitter())) {
              if (!active) {
                break;
              }

              if (line.isEmpty) {
                if (dataBuffer.isNotEmpty) {
                  final String payload = dataBuffer.toString().trimRight();
                  currentValue = _applySseEvent(
                    currentValue: currentValue,
                    eventType: currentEvent ?? 'put',
                    payload: payload,
                  );
                  controller.add(asStringMap(currentValue));
                  dataBuffer.clear();
                }
                currentEvent = null;
                continue;
              }

              if (line.startsWith('event:')) {
                currentEvent = line.substring(6).trim();
                continue;
              }

              if (line.startsWith('data:')) {
                dataBuffer.writeln(line.substring(5).trimLeft());
              }
            }
          } catch (_) {
            // Keep retrying silently; the dashboard stream should survive network blips.
          }

          if (active) {
            await Future<void>.delayed(_sseReconnectDelay);
          }
        }
      }

      unawaited(connectLoop());

      controller.onCancel = () {
        active = false;
      };
    });
  }

  Object? _applySseEvent({
    required Object? currentValue,
    required String eventType,
    required String payload,
  }) {
    if (eventType == 'keep-alive' || payload.trim().isEmpty) {
      return currentValue;
    }

    if (eventType == 'cancel' || eventType == 'auth_revoked') {
      return currentValue;
    }

    final Map<String, dynamic> envelope = asStringMap(jsonDecode(payload));
    final String path = readString(envelope['path']) ?? '/';
    final Object? data = envelope['data'];

    if (eventType == 'put') {
      return _setJsonPath(currentValue, path, data);
    }

    if (eventType == 'patch' && data is Map) {
      Object? next = currentValue;
      final Map<String, dynamic> patchMap = asStringMap(data);
      for (final MapEntry<String, dynamic> entry in patchMap.entries) {
        final String childPath = path == '/'
            ? '/${entry.key}'
            : '$path/${entry.key}'.replaceAll('//', '/');
        next = _setJsonPath(next, childPath, entry.value);
      }
      return next;
    }

    return currentValue;
  }

  Object? _setJsonPath(Object? currentValue, String path, Object? data) {
    if (path == '/' || path.isEmpty) {
      return data;
    }

    final List<String> segments = path
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);

    Object? root = _cloneJson(currentValue);
    if (root is! Map<String, dynamic>) {
      root = <String, dynamic>{};
    }

    Map<String, dynamic> node = root;
    for (int index = 0; index < segments.length - 1; index++) {
      final String segment = segments[index];
      final Object? existing = node[segment];
      if (existing is Map<String, dynamic>) {
        node = existing;
        continue;
      }
      final Map<String, dynamic> next = <String, dynamic>{};
      node[segment] = next;
      node = next;
    }

    final String leaf = segments.last;
    if (data == null) {
      node.remove(leaf);
    } else {
      node[leaf] = data;
    }

    return root;
  }

  Object? _cloneJson(Object? value) {
    if (value is Map) {
      return value.map<String, dynamic>(
        (Object? key, Object? child) =>
            MapEntry(key.toString(), _cloneJson(child)),
      );
    }
    if (value is List) {
      return value.map<Object?>((Object? child) => _cloneJson(child)).toList();
    }
    return value;
  }

  DeviceDashboard _buildDashboardFromCaches() {
    final Map<String, dynamic> stateMap = _resolveStateMap(<String, dynamic>{
      'state': _stateCache,
      'settings': _settingsCache,
      'info': _infoCache,
      'command': <String, dynamic>{'latest': _commandCache},
    });
    final Map<String, dynamic> infoMap = _resolveInfoMap(<String, dynamic>{
      'info': _infoCache,
    }, stateMap);
    final Map<String, dynamic> settingsMap = _resolveSettingsMap(
      <String, dynamic>{'settings': _settingsCache},
      stateMap,
    );
    final Map<String, dynamic> commandMap = _commandCache;

    final Map<String, String> relayLabels = <String, String>{
      ...relayDefaultLabels,
      ...readStringMap(settingsMap['relayLabels']),
      ...readStringMap(infoMap['relayNames']),
    };

    final DeviceSettings settings = DeviceSettings(
      deviceName:
          readString(infoMap['name']) ??
          readString(infoMap['deviceName']) ??
          'O dien thong minh',
      location: readString(infoMap['location']) ?? 'Phong khach',
      mode:
          (readString(settingsMap['mode']) ??
                  readString(stateMap['mode']) ??
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

    final DeviceCommand? latestCommand = commandMap.isEmpty
        ? null
        : DeviceCommand(
            commandId: readString(commandMap['commandId']) ?? 'cmd_preview',
            target: readString(commandMap['target']) ?? 'relay1',
            action: readString(commandMap['action']) ?? 'toggle',
            source: readString(commandMap['source']) ?? 'app',
            createdAt: readDateTime(commandMap['createdAt']),
          );

    final DateTime? deviceClock = _readDeviceClock(stateMap);
    final DateTime? lastSeen =
        readDateTime(stateMap['lastSeen']) ?? deviceClock;

    final bool isOnline =
        readBool(stateMap['online']) ??
        (lastSeen != null &&
            DateTime.now().difference(lastSeen) <= _onlineFreshness);

    final List<RelayChannel> relays = relayIds
        .map((String relayId) {
          return RelayChannel(
            id: relayId,
            label: relayDisplayName(relayId, relayLabels),
            isOn: readBool(stateMap[relayId]) ?? false,
            lastChangedAt: readDateTime(stateMap['${relayId}ChangedAt']),
            lastSource: readString(stateMap['${relayId}Source']),
          );
        })
        .toList(growable: false);

    final EnvironmentSnapshot environment = EnvironmentSnapshot(
      temperature: readDouble(stateMap['temperature']),
      humidity: readDouble(stateMap['humidity']),
      light: readDouble(stateMap['light']),
      lightPercent: readDouble(stateMap['lightPercent']),
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
      prefersLegacyRelayWrite: false,
    );
  }

  Map<String, dynamic> _resolveInfoMap(
    Map<String, dynamic> deviceMap,
    Map<String, dynamic> stateMap,
  ) {
    final Map<String, dynamic> infoMap = asStringMap(deviceMap['info']);
    if (infoMap.isNotEmpty) {
      return infoMap;
    }

    final Map<String, dynamic> flatSource =
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
    final Map<String, dynamic> stateMap = asStringMap(deviceMap['state']);
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
    final Map<String, dynamic> settingsMap = asStringMap(deviceMap['settings']);
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
    final String? dateText = readString(stateMap['dateNow']);
    final String? timeText = readString(stateMap['timeNow']);
    if (dateText == null || timeText == null) {
      return null;
    }

    final List<String> dateParts = dateText.split('/');
    final List<String> timeParts = timeText.split(':');
    if (dateParts.length != 3 || timeParts.length != 3) {
      return null;
    }

    final int? day = int.tryParse(dateParts[0]);
    final int? month = int.tryParse(dateParts[1]);
    final int? year = int.tryParse(dateParts[2]);
    final int? hour = int.tryParse(timeParts[0]);
    final int? minute = int.tryParse(timeParts[1]);
    final int? second = int.tryParse(timeParts[2]);

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
    final List<HistoryEntry> entries = <HistoryEntry>[];

    for (final MapEntry<String, dynamic> entry in historyMap.entries) {
      final Map<String, dynamic> data = asStringMap(entry.value);
      if (data.isEmpty) {
        continue;
      }
      entries.add(HistoryEntry.fromMap(entry.key, data));
    }

    entries.sort((HistoryEntry a, HistoryEntry b) {
      final int aTime = a.time?.millisecondsSinceEpoch ?? 0;
      final int bTime = b.time?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    return entries;
  }

  String get _deviceBasePath => 'devices/$deviceId';

  String _devicePath(String child) => '$_deviceBasePath/$child';

  Uri _uriFor(
    String path, {
    Map<String, String>? queryParameters,
    bool silentWrite = false,
    bool useReadTimeout = false,
  }) {
    final Uri baseUri = Uri.parse(_databaseUrl);
    final String normalizedBasePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;

    final Map<String, String> mergedQueryParameters = <String, String>{
      ...baseUri.queryParameters,
      if (_databaseAuth.isNotEmpty) 'auth': _databaseAuth,
      if (useReadTimeout) 'timeout': _readTimeout,
      if (silentWrite) 'print': 'silent',
      ...?queryParameters,
    };

    return baseUri.replace(
      path: '$normalizedBasePath/$path.json',
      queryParameters: mergedQueryParameters.isEmpty
          ? null
          : mergedQueryParameters,
    );
  }

  Future<Object?> _getValue(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final http.Response response = await _client.get(
      _uriFor(path, queryParameters: queryParameters, useReadTimeout: true),
      headers: const <String, String>{'Connection': 'keep-alive'},
    );
    _ensureSuccess(response, path);
    return _decodeResponse(response);
  }

  Future<void> _setValue(String path, Object? value) async {
    final http.Response response = await _client.put(
      _uriFor(path, silentWrite: true),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
      },
      body: jsonEncode(value),
    );
    _ensureSuccess(response, path);
  }

  Future<void> _patchValue(String path, Map<String, dynamic> value) async {
    final http.Response response = await _client.patch(
      _uriFor(path, silentWrite: true),
      headers: const <String, String>{
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
      },
      body: jsonEncode(value),
    );
    _ensureSuccess(response, path);
  }

  Object? _decodeResponse(http.Response response) {
    final String body = utf8.decode(response.bodyBytes);
    if (body.trim().isEmpty || body.trim() == 'null') {
      return null;
    }
    return jsonDecode(body);
  }

  void _ensureSuccess(http.BaseResponse response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Firebase request failed for $path (${response.statusCode})',
        _uriFor(path),
      );
    }
  }

  void _ensureStreamSuccess(http.BaseResponse response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Firebase stream failed for $path (${response.statusCode})',
        _uriFor(path),
      );
    }
  }
}
