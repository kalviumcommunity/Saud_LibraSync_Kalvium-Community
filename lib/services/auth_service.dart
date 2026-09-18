import 'package:firebase_auth/firebase_auth.dart';

/// Reusable service for managing Firebase Authentication in LibraSync.
class AuthService {
  final FirebaseAuth? _customAuth;

  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;

  /// Stream of authentication state changes (logged in / logged out).
  Stream<User?> get authStateChanges {
    try {
      return auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Gets the currently authenticated [User], or null if not signed in.
  User? get currentUser {
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Signs in a user with their [email] and [password].
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Registers a new user with [email], [password], and optional [displayName].
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        await credential.user?.reload();
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await auth.signOut();
  }

  /// Converts Firebase Auth error codes into human-readable messages.
  static String getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please check and try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase console.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
