import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'login_screen.dart';

/// Gatekeeper widget that listens to persistent auth changes and routes
/// the user to either [HomeScreen] or [LoginScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.authService});

  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final service = authService ?? AuthService();

    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      builder: (context, snapshot) {
        // Show loading spinner while checking initial auth status.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If authenticated user exists, show HomeScreen.
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // Otherwise, show LoginScreen.
        return const LoginScreen();
      },
    );
  }
}
