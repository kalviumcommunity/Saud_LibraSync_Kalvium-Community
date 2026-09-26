/// Data model representing a user in LibraSync (from `users/{uid}`).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'member',
    this.branchId = 'central',
    this.branchName = 'Central Branch',
    this.libraryCardNumber = 'LS-89412',
    this.readingGoal = 12,
    this.booksReadThisYear = 5,
    this.standing = 'Good Standing',
    this.photoUrl,
    this.hasActiveCard = true,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final String branchId;
  final String branchName;
  final String libraryCardNumber;
  final int readingGoal;
  final int booksReadThisYear;
  final String standing;
  final String? photoUrl;
  final bool hasActiveCard;

  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isAdmin => role == 'admin';

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserProfile(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? data['name'] as String? ?? 'Patron',
      role: (data['role'] as String? ?? 'member').toLowerCase().trim(),
      branchId: data['branchId'] as String? ?? 'central',
      branchName: data['branchName'] as String? ?? 'Central Branch',
      libraryCardNumber: data['libraryCardNumber'] as String? ?? 'LS-${uid.length >= 5 ? uid.substring(0, 5).toUpperCase() : '89412'}',
      readingGoal: (data['readingGoal'] as num?)?.toInt() ?? 12,
      booksReadThisYear: (data['booksReadThisYear'] as num?)?.toInt() ?? 5,
      standing: data['standing'] as String? ?? 'Good Standing',
      photoUrl: data['photoUrl'] as String?,
      hasActiveCard: data['hasActiveCard'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'branchId': branchId,
      'branchName': branchName,
      'libraryCardNumber': libraryCardNumber,
      'readingGoal': readingGoal,
      'booksReadThisYear': booksReadThisYear,
      'standing': standing,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'hasActiveCard': hasActiveCard,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    String? branchId,
    String? branchName,
    String? libraryCardNumber,
    int? readingGoal,
    int? booksReadThisYear,
    String? standing,
    String? photoUrl,
    bool? hasActiveCard,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      libraryCardNumber: libraryCardNumber ?? this.libraryCardNumber,
      readingGoal: readingGoal ?? this.readingGoal,
      booksReadThisYear: booksReadThisYear ?? this.booksReadThisYear,
      standing: standing ?? this.standing,
      photoUrl: photoUrl ?? this.photoUrl,
      hasActiveCard: hasActiveCard ?? this.hasActiveCard,
    );
  }
}
