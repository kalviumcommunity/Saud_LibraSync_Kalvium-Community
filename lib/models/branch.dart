/// Data model representing a library branch in LibraSync.
class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
  });

  /// Unique identifier for the branch document.
  final String id;

  /// Display name of the library branch (e.g., Central Library, North Branch).
  final String name;

  /// Physical address or location of the library branch.
  final String? address;

  /// Contact phone number for the library branch.
  final String? phone;

  /// Validates all branch data fields according to system invariants.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  void validate() {
    validateBranchData(name: name, address: address, phone: phone);
  }

  /// Static helper to validate branch parameters prior to creation or update.
  ///
  /// Throws an [ArgumentError] if any requirement is violated.
  static void validateBranchData({
    required String name,
    String? address,
    String? phone,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Branch name cannot be empty.');
    }
  }

  /// Factory constructor to deserialize a [Branch] from a Firestore document map.
  factory Branch.fromFirestore(Map<String, dynamic> data, String id) {
    return Branch(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? data['location'] as String?,
      phone: data['phone'] as String?,
    );
  }

  /// Converts this [Branch] into a map suitable for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    };
  }

  /// Creates a copy of this [Branch] with the given fields replaced.
  Branch copyWith({String? id, String? name, String? address, String? phone}) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Branch &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          address == other.address &&
          phone == other.phone;

  @override
  int get hashCode => Object.hash(id, name, address, phone);

  @override
  String toString() {
    return 'Branch(id: $id, name: $name, address: $address, phone: $phone)';
  }
}
