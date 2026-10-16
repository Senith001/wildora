import 'package:flutter/material.dart';

/// App-wide bottom navigation for the 4-tab shell.
///
/// Fixed [BottomNavigationBar] with Home, Incident, Alert, and Settings.
/// Does NOT include a Profile tab. The incident standalone route keeps using
/// [WildlifeIncidentBottomNav] and is unaffected by this widget.
class AppShellBottomNav extends StatelessWidget {
  const AppShellBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => BottomNavigationBar(
    currentIndex: selectedIndex,
    onTap: onDestinationSelected,
    type: BottomNavigationBarType.fixed,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Incident'),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_active),
        label: 'Alert',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
    ],
  );
}
