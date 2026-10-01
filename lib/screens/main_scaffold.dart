import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/user_feedback.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_state_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/main_shell_scope.dart';
import '../widgets/top_slide_banner.dart';
import 'tabs/home_tab.dart';
import 'tabs/trips_tab.dart';
import 'marketplace/marketplace_screen.dart';
import 'payments/payments_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  int? _lastPendingTabIndex;

  static const int _networkIndex = 2;
  static const int _paymentsIndex = 3;
  static const int _moreIndex = 4;

  bool get _kycVerified {
    return context.read<AuthProvider>().user?.isKycVerified == true;
  }

  void _selectTab(int index) {
    if (index == _moreIndex) {
      _openDrawer();
      return;
    }
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  Future<void> _onNetworkFabPressed() async {
    if (!_kycVerified) {
      showUserErrorSnackBar(
        context,
        null,
        fallback: 'Please complete KYC first to explore Networks',
      );
      return;
    }
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search'),
                  onTap: () => Navigator.of(sheetContext).pop(0),
                ),
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: const Text('Post vehicle'),
                  onTap: () => Navigator.of(sheetContext).pop(1),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    setState(() => _currentIndex = _networkIndex);
    context.read<NavigationStateProvider>().requestOpenMarketplaceSubTab(choice);
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
        if (navState.pendingOpenPaymentsTab &&
            _currentIndex != _paymentsIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _currentIndex = _paymentsIndex;
            });
            navState.clearPendingOpenPaymentsTab();
          });
        }
        if (navState.pendingOpenHomeTab && _currentIndex != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _currentIndex = 0;
            });
            navState.clearPendingOpenHomeTab();
          });
        } else if (navState.pendingOpenHomeTab && _currentIndex == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navState.clearPendingOpenHomeTab();
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
                    PaymentsScreen(),
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
            bottomNavigationBar: _buildBottomBar(),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final networkActive = _currentIndex == _networkIndex;
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      top: BorderSide(color: AppColors.dividerGrey),
                    ),
                  ),
                  child: Row(
                    children: [
                      _sideDestination(
                        index: 0,
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Home',
                      ),
                      _sideDestination(
                        index: 1,
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2,
                        label: 'Trips',
                      ),
                      const Expanded(child: SizedBox()),
                      _sideDestination(
                        index: _paymentsIndex,
                        icon: Icons.payments_outlined,
                        selectedIcon: Icons.payments,
                        label: 'Payments',
                      ),
                      _sideDestination(
                        index: _moreIndex,
                        icon: Icons.more_horiz,
                        selectedIcon: Icons.more_horiz,
                        label: 'More',
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: AppColors.primary,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.24),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _onNetworkFabPressed,
                        child: const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(
                            Icons.add,
                            color: AppColors.background,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Network',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: networkActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: networkActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideDestination({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = index != _moreIndex && _currentIndex == index;
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
