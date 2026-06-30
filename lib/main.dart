import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/client/client_home_screen.dart';
import 'screens/vendor/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CommercHaitiApp());
}

class CommercHaitiApp extends StatelessWidget {
  const CommercHaitiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..loadCurrentUser(),
      child: MaterialApp(
        title: 'CommercHaiti',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003F88)),
          useMaterial3: true,
        ),
        home: const AuthGate(),
        routes: {
          '/role': (_) => const RoleSelectionScreen(),
          '/vendor': (_) => const VendorDashboardScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/auth') {
            final role = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => AuthScreen(role: role),
            );
          }
          return null;
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user == null) return const RoleSelectionScreen();
    if (auth.user!.role == 'vendor') return const VendorDashboardScreen();
    return const ClientHomeScreen();
  }
}
