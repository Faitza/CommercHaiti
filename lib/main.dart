import 'package:flutter/material.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/client/client_home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CommercHaiti',
      initialRoute: '/',
      routes: {
        '/': (_) => const RoleSelectionScreen(),
        '/auth-client': (_) => const AuthScreen(isVendor: false),
        '/auth-vendor': (_) => const AuthScreen(isVendor: true),
        '/home-client': (_) => const ClientHomeScreen(userName: 'Marie'),
        '/home-guest': (_) => const ClientHomeScreen(userName: 'Visiteur'),
      },
    );
  }
}