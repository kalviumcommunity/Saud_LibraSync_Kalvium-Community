import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librasync/main.dart';
import 'package:librasync/screens/auth/login_screen.dart';
import 'package:librasync/screens/auth/signup_screen.dart';
import 'package:librasync/screens/home_screen.dart';
import 'package:librasync/services/auth_service.dart';

void main() {
  group('AuthService Unit Tests', () {
    test('Converts Firebase error codes to readable messages', () {
      expect(
        AuthService.getReadableAuthError(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        'No user found for this email address.',
      );
      expect(
        AuthService.getReadableAuthError(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        'Incorrect password. Please check and try again.',
      );
      expect(
        AuthService.getReadableAuthError(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        'Invalid email or password. Please verify your credentials.',
      );
      expect(
        AuthService.getReadableAuthError(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        'An account already exists for this email address.',
      );
    });
  });

  group('HomeScreen Tests', () {
    testWidgets('LibraSync app renders home screen with quick access cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const LibraSyncApp(
          home: HomeScreen(),
        ),
      );

      // Verify the app title and welcome banner.
      expect(find.text('LibraSync'), findsWidgets);
      expect(find.text('Welcome to LibraSync'), findsOneWidget);
      expect(find.text('Quick Access'), findsOneWidget);

      // Verify quick access cards are present.
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Branches'), findsOneWidget);
      expect(find.text('Borrowing'), findsOneWidget);

      // Verify logout action button is present.
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    testWidgets('Tapping logout button shows confirmation dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const LibraSyncApp(
          home: HomeScreen(),
        ),
      );

      await tester.tap(find.byIcon(Icons.logout_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out of LibraSync?'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Log Out'), findsWidgets);
    });
  });

  group('LoginScreen Tests', () {
    testWidgets('Renders all login UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Welcome to LibraSync'), findsOneWidget);
      expect(find.byKey(const Key('login_email_field')), findsOneWidget);
      expect(find.byKey(const Key('login_password_field')), findsOneWidget);
      expect(find.byKey(const Key('login_submit_btn')), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Validates empty email and password on submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Tap Sign In without filling form.
      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);
    });

    testWidgets('Validates invalid email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'invalid-email',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );

      await tester.tap(find.byKey(const Key('login_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
    });
  });

  group('SignUpScreen Tests', () {
    testWidgets('Renders all sign up UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.byKey(const Key('signup_name_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_email_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_password_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const Key('signup_submit_btn')), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Validates short name and empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'A',
      );

      await tester.tap(find.byKey(const Key('signup_submit_btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Name must be at least 2 characters long.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter your email address.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter a password.'),
        findsOneWidget,
      );
      expect(
        find.text('Please confirm your password.'),
        findsOneWidget,
      );
    });

    testWidgets('Validates short password and mismatched confirm password',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('signup_name_field')),
        'John Doe',
      );
      await tester.enterText(
        find.byKey(const Key('signup_email_field')),
        'john@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('signup_password_field')),
        '123',
      );
      await tester.enterText(
        find.byKey(const Key('signup_confirm_password_field')),
        '123456',
      );

      await tester.tap(find.byKey(const Key('signup_submit_btn')));
      await tester.pumpAndSettle();

      expect(
        find.text('Password must be at least 6 characters long.'),
        findsOneWidget,
      );
      expect(
        find.text('Passwords do not match.'),
        findsOneWidget,
      );
    });
  });
}
