import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestore: ref.watch(firestoreProvider));
});

/// Stream of currently authenticated Firebase user
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Stream of user document from `users/{uid}`
final currentUserProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) return Stream.value(null);
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.streamUserProfile(authUser.uid);
});

/// Current active user profile, or fallback based on Firebase Auth
final currentUserProfileProvider = Provider<UserProfile>((ref) {
  final asyncProfile = ref.watch(currentUserProfileStreamProvider);
  final authUser = ref.watch(authStateStreamProvider).value;

  if (asyncProfile.value != null) {
    return asyncProfile.value!;
  }

  // Fallback before doc loads or if offline
  return UserProfile(
    uid: authUser?.uid ?? '',
    email: authUser?.email ?? '',
    displayName: authUser?.displayName ?? 'Library Patron',
    role: 'member',
  );
});

/// True if currently logged in user is staff or admin
final isStaffProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile.isStaff;
});
