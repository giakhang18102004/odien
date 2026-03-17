import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/device_repository.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({
    super.key,
    required this.dashboard,
    required this.repository,
  });

  final DeviceDashboard dashboard;
  final DeviceRepository repository;

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  String? _busyRelayId;

  Future<void> _toggleRelay(RelayChannel relay) async {
    setState(() {
      _busyRelayId = relay.id;
    });

    try {
      await widget.repository.sendRelayCommand(
        relayId: relay.id,
        turnOn: !relay.isOn,
        source: 'app',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Da gui lenh ${!relay.isOn ? 'BAT' : 'TAT'} cho ${relay.label}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khong gui duoc lenh: $error'),
          backgroundColor: AppPalette.coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyRelayId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeading(
                eyebrow: 'Dieu khien',
                title: 'Dong cat tai theo tung kenh',
                subtitle:
                    'Moi lenh deu ghi vao control/relayX va command/latest. Neu phat hien node cu, app ghi them smart_home/relays.',
              ),
              const SizedBox(height: 18),
              const FrostPanel(
                child: Text(
                  'Nut bam vat ly tren thiet bi van phai hoat dong cuc bo ngay ca khi mat mang. App dong vai tro dieu khien tu xa va giam sat, khong thay the co che local control cua ESP32.',
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 18,
                runSpacing: 18,
                children: widget.dashboard.relays
                    .map((RelayChannel relay) {
                      final isBusy = _busyRelayId == relay.id;

                      return SizedBox(
                        width: 360,
                        child: FrostPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      relay.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                  Switch(
                                    value: relay.isOn,
                                    onChanged: isBusy
                                        ? null
                                        : (bool _) {
                                            _toggleRelay(relay);
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
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
                                  StatusBadge(
                                    label: sourceLabel(relay.lastSource),
                                    color: AppPalette.gold,
                                    icon: Icons.route_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cap nhat luc ${formatDateTime(relay.lastChangedAt)}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                relay.isOn
                                    ? 'Kenh dang dong dien cho tai.'
                                    : 'Kenh dang o trang thai ngat tai.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () => _toggleRelay(relay),
                                  icon: isBusy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          relay.isOn
                                              ? Icons.power_settings_new_rounded
                                              : Icons.flash_on_rounded,
                                        ),
                                  label: Text(
                                    isBusy
                                        ? 'Dang gui lenh...'
                                        : relay.isOn
                                        ? 'Tat kenh'
                                        : 'Bat kenh',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
