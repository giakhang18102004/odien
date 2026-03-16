import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/device_repository.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.dashboard,
    required this.repository,
  });

  final DeviceDashboard dashboard;
  final DeviceRepository repository;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _sourceFilter = 'all';
  String _relayFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryEntry>>(
      stream: widget.repository.watchHistory(),
      builder: (BuildContext context, AsyncSnapshot<List<HistoryEntry>> snapshot) {
        final entries = snapshot.data ?? const <HistoryEntry>[];
        final filteredEntries = entries
            .where((HistoryEntry entry) {
              final sourcePass =
                  _sourceFilter == 'all' || entry.source == _sourceFilter;
              final relayPass =
                  _relayFilter == 'all' || entry.target == _relayFilter;
              return sourcePass && relayPass;
            })
            .toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SectionHeading(
                    eyebrow: 'Lich su',
                    title: 'Nhat ky thao tac va dong bo',
                    subtitle:
                        'Lich su cho biet lenh den tu ung dung, nut vat ly hay che do tu dong.',
                  ),
                  const SizedBox(height: 18),
                  FrostPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bo loc nhanh',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Nguon thao tac',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _FilterChip(
                              label: 'Tat ca',
                              selected: _sourceFilter == 'all',
                              onTap: () {
                                setState(() {
                                  _sourceFilter = 'all';
                                });
                              },
                            ),
                            ...entries
                                .map((HistoryEntry entry) => entry.source)
                                .toSet()
                                .map(
                                  (String source) => _FilterChip(
                                    label: sourceLabel(source),
                                    selected: _sourceFilter == source,
                                    onTap: () {
                                      setState(() {
                                        _sourceFilter = source;
                                      });
                                    },
                                  ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Kenh',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _FilterChip(
                              label: 'Tat ca',
                              selected: _relayFilter == 'all',
                              onTap: () {
                                setState(() {
                                  _relayFilter = 'all';
                                });
                              },
                            ),
                            ...widget.dashboard.relays.map(
                              (RelayChannel relay) => _FilterChip(
                                label: relay.label,
                                selected: _relayFilter == relay.id,
                                onTap: () {
                                  setState(() {
                                    _relayFilter = relay.id;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      entries.isEmpty)
                    const FrostPanel(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredEntries.isEmpty)
                    const EmptyStateCard(
                      title: 'Chua co ban ghi phu hop',
                      message:
                          'Thu doi bo loc hoac gui lenh dieu khien de tao lich su moi.',
                      icon: Icons.history_toggle_off_rounded,
                    )
                  else
                    Column(
                      children: filteredEntries
                          .map((HistoryEntry entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: FrostPanel(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppPalette.gold.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.bolt_rounded,
                                        color: AppPalette.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            historyTitle(
                                              entry,
                                              widget
                                                  .dashboard
                                                  .settings
                                                  .relayLabels,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            historySubtitle(entry),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            formatDateTime(entry.time),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                          if (entry.temperature != null ||
                                              entry.humidity != null ||
                                              entry.light != null) ...<Widget>[
                                            const SizedBox(height: 12),
                                            Text(
                                              'Moi truong: ${formatTemperature(entry.temperature)} | ${formatHumidity(entry.humidity)} | Anh sang ${formatLight(entry.light)}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ],
                                        ],
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
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
