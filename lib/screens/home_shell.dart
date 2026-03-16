import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/device_repository.dart';
import '../models/device_models.dart';
import '../widgets/app_chrome.dart';
import 'control_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final DeviceRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeviceDashboard>(
      stream: widget.repository.watchDashboard(),
      initialData: DeviceDashboard.empty(widget.repository.deviceId),
      builder: (BuildContext context, AsyncSnapshot<DeviceDashboard> snapshot) {
        final dashboard =
            snapshot.data ?? DeviceDashboard.empty(widget.repository.deviceId);

        final pages = <Widget>[
          DashboardPage(dashboard: dashboard),
          ControlPage(dashboard: dashboard, repository: widget.repository),
          HistoryPage(dashboard: dashboard, repository: widget.repository),
          SettingsPage(dashboard: dashboard, repository: widget.repository),
        ];

        final destinations = const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'Tong quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.toggle_off_outlined),
            selectedIcon: Icon(Icons.toggle_on_rounded),
            label: 'Dieu khien',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Lich su',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cai dat',
          ),
        ];

        final railDestinations = const <NavigationRailDestination>[
          NavigationRailDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: Text('Tong quan'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.toggle_off_outlined),
            selectedIcon: Icon(Icons.toggle_on_rounded),
            label: Text('Dieu khien'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: Text('Lich su'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: Text('Cai dat'),
          ),
        ];

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final wide = constraints.maxWidth >= 980;

            return Scaffold(
              backgroundColor: AppPalette.canvas,
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      destinations: destinations,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                    ),
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppPalette.canvas,
                      Color(0xFFFFF3DF),
                      Color(0xFFE7F3ED),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: wide
                      ? Row(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: FrostPanel(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 18,
                                ),
                                child: NavigationRail(
                                  selectedIndex: _currentIndex,
                                  labelType: NavigationRailLabelType.all,
                                  destinations: railDestinations,
                                  onDestinationSelected: (int index) {
                                    setState(() {
                                      _currentIndex = index;
                                    });
                                  },
                                  leading: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8,
                                      right: 8,
                                      bottom: 20,
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: AppPalette.teal.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.hub_rounded,
                                            color: AppPalette.teal,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: 110,
                                          child: Column(
                                            children: <Widget>[
                                              Text(
                                                dashboard.name,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                widget.repository.deviceId,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                child: KeyedSubtree(
                                  key: ValueKey<int>(_currentIndex),
                                  child: pages[_currentIndex],
                                ),
                              ),
                            ),
                          ],
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentIndex),
                            child: pages[_currentIndex],
                          ),
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
