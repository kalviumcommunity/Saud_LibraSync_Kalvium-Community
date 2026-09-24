import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/book_service.dart';
import '../../services/branch_service.dart';
import '../../services/circulation_service.dart';
import '../home_screen.dart';
import 'login_screen.dart';

/// Gatekeeper widget that listens to persistent auth changes and routes
/// the user to either [HomeScreen] or [LoginScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.bookService,
    this.circulationService,
    this.branchService,
  });

  final AuthService? authService;
  final BookService? bookService;
  final CirculationService? circulationService;
  final BranchService? branchService;

  @override
  Widget build(BuildContext context) {
    final service = authService ?? AuthService();

    return StreamBuilder<User?>(
      stream: service.authStateChanges,
      builder: (context, snapshot) {
        // Show loading spinner while checking initial auth status.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If authenticated user exists, show HomeScreen.
        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen(
            authService: service,
            bookService: bookService,
            circulationService: circulationService,
            branchService: branchService,
          );
        }

        // Otherwise, show LoginScreen.
        return LoginScreen(authService: service);
      },
    );
  }
}
