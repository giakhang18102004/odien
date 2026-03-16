import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:odienthongminh/core/theme/app_theme.dart';
import 'package:odienthongminh/models/device_models.dart';
import 'package:odienthongminh/screens/dashboard_page.dart';

void main() {
  testWidgets('dashboard renders device summary and relay cards', (
    WidgetTester tester,
  ) async {
    final dashboard = DeviceDashboard(
      deviceId: 'device01',
      name: 'O dien phong khach',
      location: 'Tang 1',
      mode: 'manual',
      isOnline: true,
      lastSeen: DateTime.now(),
      environment: const EnvironmentSnapshot(
        temperature: 31.4,
        humidity: 64,
        light: 620,
        lightPercent: 75,
        lightDigital: true,
        lightText: 'TOI',
      ),
      relays: const <RelayChannel>[
        RelayChannel(
          id: 'relay1',
          label: 'Den ban',
          isOn: true,
          lastChangedAt: null,
          lastSource: 'app',
        ),
        RelayChannel(
          id: 'relay2',
          label: 'Quat',
          isOn: false,
          lastChangedAt: null,
          lastSource: 'button',
        ),
        RelayChannel(
          id: 'relay3',
          label: 'Sac',
          isOn: false,
          lastChangedAt: null,
          lastSource: 'app',
        ),
        RelayChannel(
          id: 'relay4',
          label: 'Du phong',
          isOn: true,
          lastChangedAt: null,
          lastSource: 'auto',
        ),
      ],
      latestCommand: const DeviceCommand(
        commandId: 'cmd_1',
        target: 'relay1',
        action: 'on',
        source: 'app',
        createdAt: null,
      ),
      settings: const DeviceSettings(
        deviceName: 'O dien phong khach',
        location: 'Tang 1',
        mode: 'manual',
        buzzerEnabled: true,
        tempLimit: 40,
        lightLimit: 75,
        relayLabels: <String, String>{
          'relay1': 'Den ban',
          'relay2': 'Quat',
          'relay3': 'Sac',
          'relay4': 'Du phong',
        },
      ),
      overTempLock: false,
      buzzerMuted: false,
      uptime: '00:12:32',
      timeNow: '22:45:10',
      dateNow: '15/03/2026',
      prefersLegacyRelayWrite: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DashboardPage(dashboard: dashboard),
      ),
    );

    expect(find.text('O dien phong khach'), findsOneWidget);
    expect(find.text('Tang 1'), findsOneWidget);
    expect(find.text('Den ban'), findsOneWidget);
    expect(find.text('Quat'), findsOneWidget);
  });
}
