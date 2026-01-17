import 'package:flutter/material.dart';
import 'package:nino/screens%20copy/nearby_pediatricians_screen.dart';
import 'package:nino/screens/children_list_page.dart';
import 'package:nino/screens/profile_page.dart';
import 'package:nino/screens/settings_page.dart';
import 'home_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2; // Home in the middle
  int? _selectedChildId;
  String? _selectedChildName;

  void _handleChildSelected(int? childId, String name) {
    setState(() {
      _selectedChildId = childId;
      _selectedChildName = name;
      _currentIndex = 2;
    });
  }

  void _clearSelectedChild() {
    setState(() {
      _selectedChildId = null;
      _selectedChildName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChildrenListPage(onChildSelected: _handleChildSelected), // My Children
      const NearbyPediatriciansScreen(),
      HomePage(
        selectedChildId: _selectedChildId,
        selectedChildName: _selectedChildName,
        onClearSelectedChild: _clearSelectedChild,
      ), // Home
      const ProfilePage(),
      const SettingsPage(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.child_care_outlined),
              activeIcon: Icon(Icons.child_care),
              label: 'Children',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on),
              label: 'Location',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

/// Temporary placeholders (replace later)
class _LocationPlaceholder extends StatelessWidget {
  const _LocationPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Location – coming soon')),
    );
  }
}

