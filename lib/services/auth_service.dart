import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reusable service for managing Firebase Authentication and user roles in LibraSync.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _customAuth = auth,
        _customFirestore = firestore;

  final FirebaseAuth? _customAuth;
  final FirebaseFirestore? _customFirestore;

  FirebaseAuth get auth => _customAuth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      firestore.collection('users');

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

  /// Retrieves the role of a user from their Firestore profile or custom claims.
  /// Defaults to 'member' if no explicit role is defined.
  Future<String> getUserRole([String? uid]) async {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null || targetUid.isEmpty) {
      return 'guest';
    }

    try {
      final doc = await _usersCollection.doc(targetUid).get();
      if (doc.exists && doc.data() != null) {
        final role = doc.data()!['role'] as String?;
        if (role != null && role.isNotEmpty) {
          return role.toLowerCase();
        }
      }
    } catch (_) {
      // Fall through to member role
    }

    return 'member';
  }

  /// Checks whether the user with [uid] (or the currently signed-in user) possesses staff privileges.
  Future<bool> isStaffUser([String? uid]) async {
    final role = await getUserRole(uid);
    return role == 'staff' || role == 'admin';
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

      final user = credential.user;
      if (user != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          await user.updateDisplayName(displayName.trim());
          await user.reload();
        }

        // Initialize user document in 'users' collection with 'member' role
        try {
          await _usersCollection.doc(user.uid).set({
            'uid': user.uid,
            'email': user.email ?? email.trim(),
            'displayName': displayName?.trim() ?? user.displayName,
            'role': 'member',
          }, SetOptions(merge: true));
        } catch (_) {
          // Non-blocking in case of offline / test environment
        }
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
