import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:odienthongminh/data/device_repository.dart';

void main() {
  test(
    'sendRelayCommand writes command/latest and state for modern protocol',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((http.Request request) async {
        requests.add(request);
        return http.Response('{}', 200);
      });

      final repository = DeviceRepository(deviceId: 'device01', client: client);

      await repository.sendRelayCommand(
        relayId: 'relay2',
        turnOn: true,
        mirrorLegacyState: false,
      );

      expect(requests, hasLength(2));
      expect(requests[0].method, 'PUT');
      expect(requests[0].url.path, '/devices/device01/command/latest.json');
      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/devices/device01/state.json');

      final payload = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(payload['target'], 'relay2');
      expect(payload['action'], 'on');
      expect(payload['source'], 'app');
      expect(payload['commandId'], startsWith('cmd_'));

      final statePatch = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(statePatch, <String, dynamic>{'relay2': true});
    },
  );

  test('sendRelayCommand mirrors state for legacy protocol nodes', () async {
    final requests = <http.Request>[];
    final client = MockClient((http.Request request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });

    final repository = DeviceRepository(deviceId: 'device01', client: client);

    await repository.sendRelayCommand(
      relayId: 'relay4',
      turnOn: false,
      mirrorLegacyState: true,
    );

    expect(requests, hasLength(3));
    expect(requests[0].method, 'PUT');
    expect(requests[0].url.path, '/devices/device01/command/latest.json');
    expect(requests[1].method, 'PATCH');
    expect(requests[1].url.path, '/devices/device01/state.json');
    expect(requests[2].method, 'PATCH');
    expect(requests[2].url.path, '/smart_home/relays.json');

    final commandPayload = jsonDecode(requests[0].body) as Map<String, dynamic>;
    expect(commandPayload['target'], 'relay4');
    expect(commandPayload['action'], 'off');

    final statePatch = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(statePatch, <String, dynamic>{'relay4': false});
    final legacyPatch = jsonDecode(requests[2].body) as Map<String, dynamic>;
    expect(legacyPatch, <String, dynamic>{'relay4': false});
  });

  test(
    'sendRelayCommand auto-detects legacy nodes before writing all targets',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((http.Request request) async {
        requests.add(request);

        if (request.method == 'GET' &&
            request.url.path == '/devices/device01.json') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'state': <String, dynamic>{
                'deviceId': 'device01',
                'deviceName': 'O dien thong minh',
                'location': 'Phong khach',
                'relay1': false,
                'relay2': false,
                'relay3': false,
                'relay4': false,
                'timeNow': '19:07:23',
                'dateNow': '16/03/2026',
                'uptime': '00:00:44',
              },
            }),
            200,
          );
        }

        return http.Response('{}', 200);
      });

      final repository = DeviceRepository(deviceId: 'device01', client: client);

      await repository.sendRelayCommand(relayId: 'relay1', turnOn: true);

      expect(requests, hasLength(4));
      expect(requests[0].method, 'GET');
      expect(requests[0].url.path, '/devices/device01.json');
      expect(requests[1].method, 'PUT');
      expect(requests[1].url.path, '/devices/device01/command/latest.json');
      expect(requests[2].method, 'PATCH');
      expect(requests[2].url.path, '/devices/device01/state.json');
      expect(requests[3].method, 'PATCH');
      expect(requests[3].url.path, '/smart_home/relays.json');

      final commandPayload =
          jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(commandPayload['target'], 'relay1');
      expect(commandPayload['action'], 'on');

      final statePatch = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(statePatch, <String, dynamic>{'relay1': true});
    },
  );

  test(
    'watchDashboard marks legacy relay write when device node is old style',
    () async {
      final client = MockClient((http.Request request) async {
        switch (request.url.path) {
          case '/devices/device01.json':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'state': <String, dynamic>{
                  'deviceId': 'device01',
                  'deviceName': 'O dien thong minh',
                  'location': 'Phong khach',
                  'relay1': false,
                  'relay2': false,
                  'relay3': false,
                  'relay4': false,
                  'timeNow': '18:54:17',
                  'dateNow': '16/03/2026',
                  'uptime': '00:06:52',
                },
                'command': <String, dynamic>{
                  'latest': <String, dynamic>{
                    'commandId': 'cmd_1',
                    'target': 'relay4',
                    'action': 'on',
                    'source': 'app',
                    'createdAt': 1773661837149,
                  },
                },
              }),
              200,
            );
          case '/smart_home.json':
            return http.Response('null', 200);
          default:
            return http.Response('null', 200);
        }
      });

      final repository = DeviceRepository(deviceId: 'device01', client: client);
      final dashboard = await repository.watchDashboard().first;

      expect(dashboard.prefersLegacyRelayWrite, isTrue);
    },
  );

  test(
    'watchDashboard keeps command/latest-only mode for modern nodes',
    () async {
      final client = MockClient((http.Request request) async {
        switch (request.url.path) {
          case '/devices/device01.json':
            return http.Response(
              jsonEncode(<String, dynamic>{
                'info': <String, dynamic>{
                  'name': 'O dien thong minh',
                  'location': 'Phong khach',
                },
                'state': <String, dynamic>{
                  'online': true,
                  'relay1': false,
                  'relay2': true,
                  'relay3': false,
                  'relay4': false,
                  'lastCommandId': 'cmd_10',
                },
                'history': <String, dynamic>{
                  'h1': <String, dynamic>{
                    'eventType': 'relay_change',
                    'target': 'relay2',
                    'source': 'app',
                    'newValue': true,
                    'time': 1773661837149,
                  },
                },
              }),
              200,
            );
          case '/smart_home.json':
            return http.Response('null', 200);
          default:
            return http.Response('null', 200);
        }
      });

      final repository = DeviceRepository(deviceId: 'device01', client: client);
      final dashboard = await repository.watchDashboard().first;

      expect(dashboard.prefersLegacyRelayWrite, isFalse);
    },
  );
}
