import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// TODO : décommenter quand Firebase sera configuré
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/order_provider.dart';
import 'screens/auth/splash_screen.dart';
// TODO : décommenter quand app_router.dart sera mergé
// import 'router/app_router.dart';

/// Point d'entrée — Falexson MERCIVAL
/// Branch : feature/firebase-core (merge sur main après)
/// Path : lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO Falexson : activer quand Firebase sera configuré
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const CommercHaitiApp());
}

class CommercHaitiApp extends StatelessWidget {
  const CommercHaitiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CommercHaiti',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.navy,
            primary: AppColors.navy,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const SplashScreen(),
        // TODO : remplacer par GoRouter quand app_router sera mergé
        // routerConfig: AppRouter.router,
      ),
    );
  }
}