import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hold_record.dart';
import '../repositories/hold_repository.dart';
import 'auth_providers.dart';

final holdRepositoryProvider = Provider<HoldRepository>((ref) {
  return HoldRepository(firestore: ref.watch(firestoreProvider));
});

final myHoldsStreamProvider = StreamProvider<List<HoldRecord>>((ref) {
  final user = ref.watch(authStateStreamProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(holdRepositoryProvider).streamMemberHolds(user.uid);
});

final myActiveHoldsCountProvider = Provider<int>((ref) {
  final holds = ref.watch(myHoldsStreamProvider).value ?? [];
  return holds.where((h) => h.status != HoldRecord.statusCancelled && h.status != HoldRecord.statusFulfilled).length;
});
