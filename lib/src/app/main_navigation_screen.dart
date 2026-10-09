import 'dart:async';

import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/wildlife-incident/data/incident_repository.dart';
import '../features/wildlife-incident/wildlife_incident_bottom_nav.dart';
import '../features/wildlife-incident/wildlife_incident_demo.dart';
import '../features/wildlife-incident/incident_theme.dart';

/// App navigation surrounds the original homepage without changing its UI.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  IncidentRepository? _repository;
  final Map<int, Widget> _pages = {0: const HomeScreen()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      if (index == 2) {
        _pages.putIfAbsent(
          index,
          () => const Scaffold(
            body: SafeArea(
              child: Center(child: Text('Officer profile is not configured.')),
            ),
          ),
        );
      }
      _selectedIndex = index;
    });
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
    WidgetsBinding.instance.removeObserver(this);
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: List.generate(
        3,
        (index) => _pages[index] ?? const SizedBox.shrink(),
      ),
    ),
    bottomNavigationBar: Theme(
      data: _selectedIndex == 1 ? incidentTheme() : Theme.of(context),
      child: WildlifeIncidentBottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        includeProfile: true,
      ),
    ),
  );
}
