import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.dashboard});

  final DeviceDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final relaysOn = dashboard.relays
        .where((RelayChannel relay) => relay.isOn)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FrostPanel(
                padding: const EdgeInsets.all(28),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 560,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              StatusBadge(
                                label: dashboard.isOnline
                                    ? 'Online'
                                    : 'Offline',
                                color: dashboard.isOnline
                                    ? AppPalette.teal
                                    : AppPalette.coral,
                                icon: dashboard.isOnline
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded,
                              ),
                              StatusBadge(
                                label: modeLabel(dashboard.mode),
                                color: AppPalette.gold,
                                icon: Icons.sync_alt_rounded,
                              ),
                              StatusBadge(
                                label: dashboard.overTempLock
                                    ? 'Khoa nhiet'
                                    : 'Nhiet do binh thuong',
                                color: dashboard.overTempLock
                                    ? AppPalette.coral
                                    : AppPalette.slate,
                                icon: dashboard.overTempLock
                                    ? Icons.lock_rounded
                                    : Icons.thermostat_rounded,
                              ),
                              StatusBadge(
                                label: dashboard.buzzerMuted
                                    ? 'Da tat buzzer'
                                    : 'Buzzer san sang',
                                color: dashboard.buzzerMuted
                                    ? AppPalette.slate
                                    : AppPalette.teal,
                                icon: dashboard.buzzerMuted
                                    ? Icons.notifications_off_rounded
                                    : Icons.notifications_active_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            dashboard.name,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            dashboard.location,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Lan dong bo gan nhat: ${formatRelativeTime(dashboard.lastSeen)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          if (dashboard.dateNow != null ||
                              dashboard.timeNow != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              'Dong ho ESP: ${dashboard.timeNow ?? '--:--:--'} ${dashboard.dateNow ?? ''}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          if (dashboard.uptime != null) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              'Uptime: ${dashboard.uptime}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                          const SizedBox(height: 22),
                          Text(
                            'App gui lenh qua command/latest va nhan trang thai relay tu state thuc te cua ESP theo luong realtime.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 500,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF1A4B45),
                              Color(0xFF316A5A),
                              Color(0xFFDBA84E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Ban do trang thai',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              '$relaysOn / ${dashboard.relays.length} relay dang bat',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'DHT11 la cam bien moi truong xung quanh. Ban bao cao nen ghi ro rang no khong dai dien nhiet do an toan cua relay hay o cam.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SectionHeading(
                eyebrow: 'Moi truong',
                title: 'Chi so giam sat tai cho',
                subtitle:
                    'ESP32 gui nhiet do, do am va anh sang ve dashboard theo thoi gian thuc.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: <Widget>[
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Nhiet do',
                      value: formatTemperature(
                        dashboard.environment.temperature,
                      ),
                      caption: 'DHT11 moi truong',
                      icon: Icons.thermostat_rounded,
                      tint: AppPalette.coral,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Do am',
                      value: formatHumidity(dashboard.environment.humidity),
                      caption: 'Thong so phong',
                      icon: Icons.water_drop_rounded,
                      tint: AppPalette.teal,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: 'Anh sang',
                      value:
                          dashboard.environment.lightText ??
                          formatLight(dashboard.environment.light),
                      caption: dashboard.environment.lightPercent != null
                          ? 'Ty le: ${formatPercent(dashboard.environment.lightPercent)}'
                          : dashboard.environment.lightDigital != null
                          ? 'Digital: ${dashboard.environment.lightDigital! ? 'BAT' : 'TAT'}'
                          : 'Cam bien anh sang',
                      icon: Icons.wb_sunny_rounded,
                      tint: AppPalette.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const SectionHeading(
                eyebrow: 'Relay',
                title: 'Trang thai 4 kenh',
                subtitle:
                    'Moi kenh duoc xac dinh theo state thuc te, khong dua vao lenh moi gui tu app.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: dashboard.relays
                    .map((RelayChannel relay) {
                      return SizedBox(
                        width: 280,
                        child: FrostPanel(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              StatusBadge(
                                label: relayStateLabel(relay.isOn),
                                color: relay.isOn
                                    ? AppPalette.teal
                                    : AppPalette.slate,
                                icon: relay.isOn
                                    ? Icons.flash_on_rounded
                                    : Icons.power_settings_new_rounded,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                relay.label,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cap nhat: ${formatRelativeTime(relay.lastChangedAt)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nguon: ${sourceLabel(relay.lastSource)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              if (dashboard.latestCommand != null) ...<Widget>[
                const SizedBox(height: 28),
                FrostPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Lenh gan nhat da gui',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${relayDisplayName(dashboard.latestCommand!.target, dashboard.settings.relayLabels)} -> ${dashboard.latestCommand!.action.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${sourceLabel(dashboard.latestCommand!.source)} | ${formatDateTime(dashboard.latestCommand!.createdAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Lenh nay duoc ghi vao command/latest. Giao dien relay chi doi khi ESP cap nhat state thuc te len Firebase.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
