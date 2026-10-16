import 'package:flutter/material.dart';

/// Navigation shared by the app wrapper and standalone incident route.
class WildlifeIncidentBottomNav extends StatelessWidget {
  const WildlifeIncidentBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.includeProfile = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool includeProfile;

  @override
  Widget build(BuildContext context) => BottomNavigationBar(
    currentIndex: selectedIndex,
    onTap: onDestinationSelected,
    type: BottomNavigationBarType.fixed,
    items: [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Incident'),
      if (includeProfile)
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
    ],
  );
}
