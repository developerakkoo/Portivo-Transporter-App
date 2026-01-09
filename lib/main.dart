import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prottivo Transporter',
      theme: AppTheme.lightTheme(),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/pin-setup': (context) => const PinSetupScreen(),
        '/pin-login': (context) => const PinLoginScreen(),
        '/home': (context) => const MainScaffold(),
        '/create-trip': (context) => const CreateTripScreen(),
        '/search-vehicle': (context) => const SearchVehicleScreen(),
        '/search-customer': (context) => const SearchCustomerScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/fuel-cards': (context) => const FuelCardsScreen(),
        '/fuel-card-qr': (context) => const FuelCardQRScreen(),
      },
    );
  }
}

