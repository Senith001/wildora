import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/wildlife-incident/data/incident_repository.dart';
import '../features/wildlife-incident/wildlife_incident_demo.dart';
import '../features/high_risk_movement/application/animal_monitoring_controller.dart';
import '../features/high_risk_movement/application/high_risk_zone_detection_service.dart';
import '../features/high_risk_movement/presentation/monitoring_dashboard_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../data/repositories/animal_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/high_risk_zone_repository.dart';
import '../data/repositories/officer_repository.dart';
import '../data/repositories/duty_roster_repository.dart';
import '../data/repositories/alert_recipient_repository.dart';
import '../data/repositories/user_preferences_repository.dart';
import 'app_shell_tab_controller.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_shell_bottom_nav.dart';

/// App-wide 4-tab navigation shell: Home, Incident, Alert, Settings.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
    this.monitoringController,
    this.themeController,
  });

  final AnimalMonitoringController? monitoringController;
  final ThemeController? themeController;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  IncidentRepository? _repository;
  final Map<int, Widget> _pages = {};

  late final ThemeController _tc;
  late final AnimalMonitoringController _mc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Lazily resolve dependencies when not injected.
    _tc =
        widget.themeController ??
        ThemeController(FirestoreUserPreferencesRepository());
    _mc = widget.monitoringController ?? _buildMonitoringController();

    // Home, Alert (dashboard), and Settings are available immediately.
    _pages[0] = const HomeScreen();
    _pages[2] = MonitoringDashboardScreen(
      controller: _mc,
      themeController: _tc,
      isEmbedded: true,
    );
    _pages[3] = SettingsScreen(themeController: _tc);

    // Allow any screen to request a shell tab switch via AppShellTabController.
    AppShellTabController.selectedTab.value = _selectedIndex;
    AppShellTabController.selectedTab.addListener(_onExternalTabRequest);
  }

  /// Handle a tab-switch request originating from another screen.
  void _onExternalTabRequest() {
    final requested = AppShellTabController.selectedTab.value;
    if (!mounted || requested == _selectedIndex) return;
    _select(requested);
  }

  /// Build an [AnimalMonitoringController] inline, mirroring
  /// AppRouter.createWithFirestoreDependencies.
  AnimalMonitoringController _buildMonitoringController() {
    final animalRepository = FirestoreAnimalRepository();
    final alertRepository = FirestoreAlertRepository();
    final zoneRepository = FirestoreHighRiskZoneRepository();
    final officerRepository = FirestoreOfficerRepository();
    final dutyRosterRepository = FirestoreDutyRosterRepository();
    final alertRecipientRepository = FirestoreAlertRecipientRepository();

    final detectionService = HighRiskZoneDetectionService(
      officerRepository: officerRepository,
      dutyRosterRepository: dutyRosterRepository,
      zoneRepository: zoneRepository,
    );

    return AnimalMonitoringController(
      animalRepository: animalRepository,
      alertRepository: alertRepository,
      alertRecipientRepository: alertRecipientRepository,
      detectionService: detectionService,
      zoneRepository: zoneRepository,
    );
  }

  void _select(int index) {
    setState(() {
      if (index == 1) {
        _repository ??= IncidentRepository.firebase();
        _pages.putIfAbsent(
          index,
          () => WildlifeIncidentDemo(
            showBottomNav: false,
            initialTab: 0,
            repository: _repository,
            onNavigate: _select,
          ),
        );
      }
      _selectedIndex = index;
    });
    // Keep the shared controller in sync so external listeners observe the
    // shell's current tab (and we don't re-enter via the listener).
    AppShellTabController.selectedTab.value = index;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _repository?.ready == true) {
      unawaited(
        _repository!.syncPending(includeFailed: false).catchError((
          Object error,
        ) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(incidentErrorMessage(error))),
            );
          }
          return IncidentSyncSummary(
            uploaded: 0,
            failed: 0,
            remaining: _repository!.pendingCount,
          );
        }),
      );
    }
  }

  @override
  void dispose() {
    AppShellTabController.selectedTab.removeListener(_onExternalTabRequest);
    WidgetsBinding.instance.removeObserver(this);
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: List.generate(
        4,
        (index) => _pages[index] ?? const SizedBox.shrink(),
      ),
    ),
    bottomNavigationBar: AppShellBottomNav(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _select,
    ),
  );
}
