import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/device_repository.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.dashboard,
    required this.repository,
  });

  final DeviceDashboard dashboard;
  final DeviceRepository repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late DeviceSettings _draft;
  late final TextEditingController _deviceNameController;
  late final TextEditingController _locationController;
  late final Map<String, TextEditingController> _relayControllers;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _deviceNameController = TextEditingController();
    _locationController = TextEditingController();
    _relayControllers = <String, TextEditingController>{
      for (final String relayId in relayIds) relayId: TextEditingController(),
    };
    _hydrateFromDashboard(widget.dashboard.settings);
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty) {
      _hydrateFromDashboard(widget.dashboard.settings);
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _locationController.dispose();
    for (final TextEditingController controller in _relayControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _hydrateFromDashboard(DeviceSettings settings) {
    _draft = settings;
    _deviceNameController.text = settings.deviceName;
    _locationController.text = settings.location;
    for (final String relayId in relayIds) {
      _relayControllers[relayId]!.text = relayDisplayName(
        relayId,
        settings.relayLabels,
      );
    }
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
      });
    }
  }

  void _updateDraftFromControllers() {
    _draft = _draft.copyWith(
      deviceName: _deviceNameController.text.trim().isEmpty
          ? 'O dien thong minh'
          : _deviceNameController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? 'Phong khach'
          : _locationController.text.trim(),
      relayLabels: <String, String>{
        for (final String relayId in relayIds)
          relayId: _relayControllers[relayId]!.text.trim().isEmpty
              ? relayDisplayName(relayId, relayDefaultLabels)
              : _relayControllers[relayId]!.text.trim(),
      },
    );
  }

  Future<void> _save() async {
    _updateDraftFromControllers();

    setState(() {
      _saving = true;
    });

    try {
      await widget.repository.saveSettings(_draft);

      if (!mounted) {
        return;
      }

      setState(() {
        _dirty = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da luu cau hinh thiet bi.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Khong the luu cai dat: $error'),
          backgroundColor: AppPalette.coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
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
                eyebrow: 'Cai dat',
                title: 'Thong tin thiet bi va nguong canh bao',
                subtitle:
                    'Noi de luu ten thiet bi, nhan relay, mode va gioi hanh thong bao cho do an.',
              ),
              const SizedBox(height: 18),
              FrostPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Thong tin chung',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _deviceNameController,
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Ten thiet bi',
                        hintText: 'O dien phong khach',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _locationController,
                      onChanged: (_) => _markDirty(),
                      decoration: const InputDecoration(
                        labelText: 'Vi tri lap dat',
                        hintText: 'Phong khach',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Che do hoat dong',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'manual',
                          label: Text('Thu cong'),
                          icon: Icon(Icons.touch_app_rounded),
                        ),
                        ButtonSegment<String>(
                          value: 'auto',
                          label: Text('Tu dong'),
                          icon: Icon(Icons.auto_mode_rounded),
                        ),
                      ],
                      selected: <String>{_draft.mode},
                      onSelectionChanged: (Set<String> value) {
                        setState(() {
                          _draft = _draft.copyWith(mode: value.first);
                          _dirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      value: _draft.buzzerEnabled,
                      onChanged: (bool value) {
                        setState(() {
                          _draft = _draft.copyWith(buzzerEnabled: value);
                          _dirty = true;
                        });
                      },
                      title: const Text('Bat buzzer canh bao'),
                      subtitle: const Text(
                        'Dung cho feedback thao tac va canh bao nguong.',
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FrostPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Nguong canh bao',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Nhiet do moi truong: ${_draft.tempLimit.toStringAsFixed(0)} C',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _draft.tempLimit.clamp(20, 80),
                      min: 20,
                      max: 80,
                      divisions: 60,
                      label: _draft.tempLimit.toStringAsFixed(0),
                      onChanged: (double value) {
                        setState(() {
                          _draft = _draft.copyWith(tempLimit: value);
                          _dirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nguong anh sang: ${_draft.lightLimit.toStringAsFixed(0)} %',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Slider(
                      value: _draft.lightLimit.clamp(0, 100),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: _draft.lightLimit.toStringAsFixed(0),
                      onChanged: (double value) {
                        setState(() {
                          _draft = _draft.copyWith(lightLimit: value);
                          _dirty = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Trang thai he thong hien tai: ${widget.dashboard.isOnline ? 'Online' : 'Offline'} | ${modeLabel(widget.dashboard.mode)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FrostPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Nhan cho 4 kenh relay',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...relayIds.map((String relayId) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextField(
                          controller: _relayControllers[relayId],
                          onChanged: (_) => _markDirty(),
                          decoration: InputDecoration(
                            labelText: relayId.toUpperCase(),
                            hintText: relayDisplayName(
                              relayId,
                              relayDefaultLabels,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Dang luu...' : 'Luu cau hinh'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            setState(() {
                              _dirty = false;
                              _hydrateFromDashboard(widget.dashboard.settings);
                            });
                          },
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Hoan tac'),
                  ),
                  if (_dirty)
                    const StatusBadge(
                      label: 'Co thay doi chua luu',
                      color: AppPalette.coral,
                      icon: Icons.edit_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
