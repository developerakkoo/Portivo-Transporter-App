import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/navigation_state_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/main_shell_scope.dart';
import '../widgets/top_slide_banner.dart';
import 'tabs/home_tab.dart';
import 'tabs/trips_tab.dart';
import 'tabs/drivers_tab.dart';
import 'marketplace/marketplace_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int? _lastPendingTabIndex;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Trips',
    ),
    NavigationDestination(
      icon: Icon(Icons.hub_outlined),
      selectedIcon: Icon(Icons.hub),
      label: 'Network',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outlined),
      selectedIcon: Icon(Icons.people),
      label: 'Drivers',
    ),
  ];

  void _onDestinationSelected(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationStateProvider>(
      builder: (context, navState, _) {
        if (navState.pendingHighlightTripId != null &&
            _lastPendingTabIndex != 1) {
          _lastPendingTabIndex = 1;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex = 1;
              });
            }
          });
        } else if (navState.pendingHighlightTripId == null) {
          _lastPendingTabIndex = null;
        }
        if (navState.pendingOpenTripsSubTabOnly != null &&
            _currentIndex != 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex = 1;
              });
            }
          });
        }
        return MainShellScope(
          openDrawer: _openDrawer,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppColors.background,
            drawer: const AppDrawer(),
            body: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: const [
                    HomeTab(),
                    TripsTab(),
                    MarketplaceScreen(),
                    DriversTab(),
                  ],
                ),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TopSlideBanner(),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onDestinationSelected,
              backgroundColor: AppColors.background,
              elevation: 0,
              indicatorColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              animationDuration: const Duration(milliseconds: 200),
              destinations: _destinations,
              height: 70.0,
            ),
          ),
        );
      },
    );
  }
}
