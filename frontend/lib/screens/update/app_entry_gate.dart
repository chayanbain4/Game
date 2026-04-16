import 'package:flutter/material.dart';
import '../../services/update_service.dart';
import '../../services/user_session.dart';
import '../dashboard/dashboard_screen.dart';
import '../home_screen.dart';
import 'force_update_screen.dart';

class AppEntryGate extends StatefulWidget {
  const AppEntryGate({super.key});

  @override
  State<AppEntryGate> createState() => _AppEntryGateState();
}

class _AppEntryGateState extends State<AppEntryGate> {
  bool _loading = true;
  bool _hasSession = false;
  bool _mustUpdate = false;
  AppUpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final hasSession = await UserSession.instance.tryRestore();
    final currentVersion = await UpdateService.getCurrentVersion();
    final updateInfo = await UpdateService.checkForUpdate();

    bool mustUpdate = false;

    if (updateInfo != null) {
      mustUpdate = updateInfo.forceUpdate ||
          UpdateService.isVersionLower(currentVersion, updateInfo.minRequiredVersion);
    }

    if (!mounted) return;

    setState(() {
      _hasSession = hasSession;
      _updateInfo = updateInfo;
      _mustUpdate = mustUpdate;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_mustUpdate && _updateInfo != null) {
      return ForceUpdateScreen(
        message: _updateInfo!.message,
        apkUrl: _updateInfo!.apkUrl,
      );
    }

    return _hasSession ? const HomeScreen() : const DashboardScreen();
  }
}