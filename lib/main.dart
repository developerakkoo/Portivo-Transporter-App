import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_flags.dart';
import 'services/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/navigation_state_provider.dart';
import 'providers/vehicle_provider.dart';
import 'providers/vehicle_type_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/fuel_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/company_user_provider.dart';
import 'providers/pinned_trips_provider.dart';
import 'providers/marketplace_chat_provider.dart';
import 'providers/support_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/pin_setup.dart';
import 'screens/pin_login.dart';
import 'screens/main_scaffold.dart';
import 'screens/create_trip.dart';
import 'screens/search_vehicle.dart';
import 'screens/search_customer.dart';
import 'screens/wallet.dart';
import 'screens/fuel_cards.dart';
import 'screens/fuel_card_qr.dart';
import 'screens/drivers/add_driver_screen.dart';
import 'screens/company_users/company_users_screen.dart';
import 'screens/company_users/add_edit_user_screen.dart';
import 'screens/profile.dart';
import 'screens/vehicles/vehicles_list_screen.dart';
import 'screens/vehicles/add_edit_vehicle_screen.dart';
import 'screens/notifications.dart';
import 'screens/support.dart';
import 'screens/trip_detail.dart';
import 'screens/map_screen.dart';
import 'screens/marketplace/marketplace_screen.dart';
import 'screens/dev/live_tracking_sandbox_screen.dart';

Future<void> main() async {
  await _runBootstrap();
}

Future<void> _runBootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force Google Maps to use the hybrid-composition (AndroidView surface) path.
  // The default Texture Layer path uses an ImageReader that races on the GPU
  // fence on Android < 33, causing "Image is already closed" raster-thread
  // crashes (SIGABRT) when the map view is mounted/unmounted or hot-reloaded.
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      print('Flutter Error: ${details.exception}');
      print('Stack: ${details.stack}');
      print('Library: ${details.library}');
      print('Context: ${details.context}');
    }
  };

  // Set error widget builder
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return Material(
        child: Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${details.exception}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (details.exception.toString().contains('authorization') ||
                    details.exception.toString().contains('token') ||
                    details.exception.toString().contains('401') ||
                    details.exception.toString().contains('403'))
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Text(
                      'Authentication Error: Please log in again.',
                      style: TextStyle(color: Colors.orange, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  details.stack.toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'An error occurred. Please restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      print('Async Error: $error');
      print('Stack: $stack');

      if (error.toString().contains('authorization') ||
          error.toString().contains('token') ||
          error.toString().contains('401') ||
          error.toString().contains('403')) {
        print('Async Error: Authentication issue detected');
      }

      if (error.toString().contains('network') ||
          error.toString().contains('connection') ||
          error.toString().contains('timeout')) {
        print('Async Error: Network issue detected');
      }
    }
    return true;
  };

  try {
    await StorageService().init();
    if (kDebugMode) {
      print('StorageService initialized successfully');
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('Error initializing StorageService: $e');
      print('Stack: $stackTrace');
    }
    // Continue anyway - storage might work partially
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          try {
            return AuthProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating AuthProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return TripProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating TripProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return VehicleProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating VehicleProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return VehicleTypeProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating VehicleTypeProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return CustomerProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating CustomerProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return DriverProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating DriverProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return FuelProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating FuelProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return WalletProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating WalletProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return CompanyUserProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating CompanyUserProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return NotificationProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating NotificationProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return MarketplaceChatProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating MarketplaceChatProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return SupportProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating SupportProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return NavigationStateProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating NavigationStateProvider: $e');
            }
            rethrow;
          }
        }),
        ChangeNotifierProvider(create: (_) {
          try {
            return PinnedTripsProvider();
          } catch (e) {
            if (kDebugMode) {
              print('Error creating PinnedTripsProvider: $e');
            }
            rethrow;
          }
        }),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Prottivo Transporter',
        theme: AppTheme.lightTheme(),
        initialRoute: AppFlags.trackingSandbox ? '/' : '/splash',
        routes: {
          if (AppFlags.trackingSandbox)
            '/': (context) => const LiveTrackingSandboxScreen(),
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/pin-setup': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return PinSetupScreen(
              mobileNumber: args is String ? args : null,
            );
          },
          '/pin-login': (context) => const PinLoginScreen(),
          '/home': (context) => const MainScaffold(),
          '/create-trip': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return CreateTripScreen(
              draftId: args is String ? args : null,
            );
          },
          '/search-vehicle': (context) => const SearchVehicleScreen(),
          '/search-customer': (context) => const SearchCustomerScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/fuel-cards': (context) => const FuelCardsScreen(),
          '/fuel-card-qr': (context) => const FuelCardQRScreen(),
          '/add-driver': (context) => const AddDriverScreen(),
          '/company-users': (context) => const CompanyUsersScreen(),
          '/add-user': (context) => const AddEditUserScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/vehicles': (context) => const VehiclesListScreen(),
          '/add-vehicle': (context) => const AddEditVehicleScreen(),
          '/edit-vehicle': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return AddEditVehicleScreen(vehicleId: args is String ? args : null);
          },
          '/notifications': (context) => const NotificationsScreen(),
          '/support': (context) => const SupportHubScreen(),
          '/trip-detail': (context) => const TripDetailScreen(),
          '/map': (context) => const MapScreen(),
          '/marketplace': (context) => const MarketplaceScreen(),
        },
      ),
    );
  }
}

