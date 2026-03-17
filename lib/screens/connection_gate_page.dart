import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/device_repository.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';
import 'home_shell.dart';

class ConnectionGatePage extends StatefulWidget {
  const ConnectionGatePage({super.key});

  @override
  State<ConnectionGatePage> createState() => _ConnectionGatePageState();
}

class _ConnectionGatePageState extends State<ConnectionGatePage> {
  late final TextEditingController _deviceIdController;
  Future<ConnectionSummary>? _summaryFuture;
  DeviceRepository? _activeRepository;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _deviceIdController = TextEditingController();
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  String get _normalizedDeviceId => _deviceIdController.text.trim();

  bool get _hasValidatedRepository =>
      _activeRepository != null &&
      _activeRepository!.deviceId == _normalizedDeviceId;

  void _checkDevice() {
    final deviceId = _normalizedDeviceId;
    if (deviceId.isEmpty) {
      setState(() {
        _inputError = 'Nhap DEVICE_ID de truy cap thiet bi.';
        _summaryFuture = null;
        _activeRepository = null;
      });
      return;
    }

    final repository = DeviceRepository(deviceId: deviceId);
    setState(() {
      _inputError = null;
      _activeRepository = repository;
      _summaryFuture = repository.fetchConnectionSummary();
    });
  }

  void _retry() {
    if (_activeRepository == null) {
      _checkDevice();
      return;
    }

    setState(() {
      _summaryFuture = _activeRepository!.fetchConnectionSummary();
    });
  }

  void _openControlCenter() {
    if (_activeRepository == null) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            HomeShell(repository: _activeRepository!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = _activeRepository;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppPalette.canvas,
              Color(0xFFFFF3DF),
              Color(0xFFE5F2EC),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: FutureBuilder<ConnectionSummary>(
                  future: _summaryFuture,
                  builder: (BuildContext context, AsyncSnapshot<ConnectionSummary> snapshot) {
                    final summary = snapshot.data;
                    final canOpen =
                        summary != null &&
                        summary.isReachable &&
                        _hasValidatedRepository;

                    return Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 470,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'ESP32 + Firebase + Flutter',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Nhap DEVICE_ID de mo bang dieu khien',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Ung dung chi cho phep truy cap sau khi ban nhap dung DEVICE_ID va doc duoc node tu Firebase. Moi thao tac dieu khien sau do se gan voi thiet bi vua chon.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 28),
                              const Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: <Widget>[
                                  _FeatureChip(
                                    icon: Icons.key_rounded,
                                    label: 'Nhap DEVICE_ID',
                                  ),
                                  _FeatureChip(
                                    icon: Icons.cloud_done_rounded,
                                    label: 'Xac thuc qua Firebase',
                                  ),
                                  _FeatureChip(
                                    icon: Icons.toggle_on_rounded,
                                    label: 'Dieu khien dung thiet bi',
                                  ),
                                  _FeatureChip(
                                    icon: Icons.history_rounded,
                                    label: 'Theo doi lich su',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 560,
                          child: FrostPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppPalette.gold.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.lock_open_rounded,
                                        color: AppPalette.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            'Nhap DEVICE_ID',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            repository == null
                                                ? 'Chua chon thiet bi nao'
                                                : 'Dang kiem tra: ${repository.deviceId}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _deviceIdController,
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) {
                                    if (_inputError != null ||
                                        _summaryFuture != null) {
                                      setState(() {
                                        _inputError = null;
                                        if (!_hasValidatedRepository) {
                                          _summaryFuture = null;
                                          _activeRepository = null;
                                        }
                                      });
                                    }
                                  },
                                  onSubmitted: (_) => _checkDevice(),
                                  decoration: InputDecoration(
                                    labelText: 'DEVICE_ID',
                                    hintText: 'Vi du: device01',
                                    errorText: _inputError,
                                    prefixIcon: const Icon(
                                      Icons.memory_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: <Widget>[
                                    FilledButton.icon(
                                      onPressed: _checkDevice,
                                      icon: const Icon(Icons.search_rounded),
                                      label: const Text('Kiem tra thiet bi'),
                                    ),
                                    if (_summaryFuture != null)
                                      OutlinedButton.icon(
                                        onPressed: _retry,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Tai lai'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                if (_summaryFuture == null) ...<Widget>[
                                  const StatusBadge(
                                    label: 'Cho nhap DEVICE_ID',
                                    color: AppPalette.slate,
                                    icon: Icons.pending_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nhap ma thiet bi truoc. App chi mo trung tam dieu khien khi Firebase tra ve node hop le cho DEVICE_ID nay.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ] else if (snapshot.connectionState !=
                                        ConnectionState.done &&
                                    summary == null) ...<Widget>[
                                  const LinearProgressIndicator(),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Dang doc cac node devices/${repository?.deviceId ?? _normalizedDeviceId}/info, state va settings...',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ] else if (snapshot.hasError) ...<Widget>[
                                  const StatusBadge(
                                    label: 'Khong doc duoc database',
                                    color: AppPalette.coral,
                                    icon: Icons.error_outline_rounded,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    snapshot.error.toString(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ] else if (summary != null) ...<Widget>[
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: <Widget>[
                                      StatusBadge(
                                        label: summary.isReachable
                                            ? 'Tim thay node thiet bi'
                                            : 'Khong tim thay node',
                                        color: summary.isReachable
                                            ? AppPalette.teal
                                            : AppPalette.coral,
                                        icon: summary.isReachable
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                      ),
                                      StatusBadge(
                                        label: summary.isOnline
                                            ? 'Thiet bi online'
                                            : 'Thiet bi chua online',
                                        color: summary.isOnline
                                            ? AppPalette.teal
                                            : AppPalette.coral,
                                        icon: summary.isOnline
                                            ? Icons.wifi_rounded
                                            : Icons.wifi_off_rounded,
                                      ),
                                      StatusBadge(
                                        label: summary.hasLegacyBridge
                                            ? 'Co du lieu legacy'
                                            : 'Dang dung node toi uu',
                                        color: AppPalette.gold,
                                        icon: Icons.swap_horiz_rounded,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    summary.deviceName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    summary.message,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 18),
                                  const _NoteRow(
                                    icon: Icons.touch_app_rounded,
                                    text:
                                        'Nut bam vat ly van phai duoc uu tien dieu khien cuc bo ngay ca khi mat mang.',
                                  ),
                                  const SizedBox(height: 10),
                                  const _NoteRow(
                                    icon: Icons.thermostat_rounded,
                                    text:
                                        'DHT11 duoc mo ta la cam bien moi truong xung quanh, khong dai dien nhiet do an toan cua relay.',
                                  ),
                                ],
                                const SizedBox(height: 26),
                                FilledButton.icon(
                                  onPressed: canOpen
                                      ? _openControlCenter
                                      : null,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('Mo trung tam dieu khien'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppPalette.teal),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: AppPalette.teal, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
