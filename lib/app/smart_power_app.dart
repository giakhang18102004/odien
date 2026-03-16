import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/connection_gate_page.dart';
import '../widgets/app_chrome.dart';

class SmartPowerApp extends StatelessWidget {
  const SmartPowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O Dien Thong Minh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppBootstrapPage(),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _initialize();
  }

  Future<void> _initialize() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  void _retry() {
    setState(() {
      _bootstrapFuture = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapStatusView(
            title: 'Khoi dong trung tam dieu khien',
            message:
                'Dang chuan bi dashboard REST de doc va ghi du lieu Firebase tren Windows.',
            icon: Icons.electric_bolt_rounded,
          );
        }

        if (snapshot.hasError) {
          return _BootstrapErrorView(
            errorText: snapshot.error.toString(),
            onRetry: _retry,
          );
        }

        return const ConnectionGatePage();
      },
    );
  }
}

class _BootstrapStatusView extends StatelessWidget {
  const _BootstrapStatusView({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppPalette.canvas,
              Color(0xFFFFF4E3),
              Color(0xFFE8F4EF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FrostPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppPalette.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(icon, size: 34, color: AppPalette.teal),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({required this.errorText, required this.onRetry});

  final String errorText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              AppPalette.canvas,
              Color(0xFFFFF4E3),
              Color(0xFFE8F4EF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FrostPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppPalette.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 34,
                          color: AppPalette.coral,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Khong the khoi tao ung dung',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thu lai'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
