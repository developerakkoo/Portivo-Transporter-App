import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/navigation_state_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/trips_tab.dart';
import 'tabs/drivers_tab.dart';
import 'tabs/more_tab.dart';

/// Horizontally centers the FAB and places it so it straddles the top edge of the bottom [NavigationBar].
class _FabCenterOverNavigationBar extends FloatingActionButtonLocation {
  const _FabCenterOverNavigationBar({required this.navigationBarHeight});

  final double navigationBarHeight;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final safeBottom = scaffoldGeometry.minViewPadding.bottom;
    final dx = (scaffoldGeometry.scaffoldSize.width - fabSize.width) / 2;
    final dy = scaffoldGeometry.scaffoldSize.height -
        safeBottom -
        navigationBarHeight -
        fabSize.height / 2;
    return Offset(dx, dy);
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
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
      icon: Icon(Icons.people_outlined),
      selectedIcon: Icon(Icons.people),
      label: 'Drivers',
    ),
    NavigationDestination(
      icon: Icon(Icons.more_horiz_outlined),
      selectedIcon: Icon(Icons.more_horiz),
      label: 'More',
    ),
  ];

  void _onDestinationSelected(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
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
        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _currentIndex,
            children: const [
              HomeTab(),
              TripsTab(),
              DriversTab(),
              MoreTab(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'fab_main_marketplace',
            onPressed: () {
              Navigator.pushNamed(context, '/marketplace');
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 6,
            child: const Icon(Icons.storefront),
          ),
          floatingActionButtonLocation:
              const _FabCenterOverNavigationBar(navigationBarHeight: 70),
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
        );
      },
    );
  }
}

