// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/services/branch_service.dart';

void main() {
  final sampleBranch1 = Branch(
    id: 'branch-central',
    name: 'Central Library',
    address: '123 Main Street, Cityville',
    phone: '555-0199',
  );

  final sampleBranch2 = Branch(
    id: 'branch-north',
    name: 'North Campus Library',
    address: '456 College Way, Cityville',
    phone: '555-0200',
  );

  group('Branch Model Serialization & Validation Tests', () {
    test('Valid branch passes validation without error', () {
      expect(() => sampleBranch1.validate(), returnsNormally);
    });

    test('Throws ArgumentError when branch name is empty or whitespace', () {
      final invalidBranch = sampleBranch1.copyWith(name: '   ');
      expect(
        () => invalidBranch.validate(),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Branch name cannot be empty'),
          ),
        ),
      );
    });

    test('Correctly serializes to and from Firestore map', () {
      final map = sampleBranch1.toFirestore();
      expect(map['name'], 'Central Library');
      expect(map['address'], '123 Main Street, Cityville');
      expect(map['phone'], '555-0199');

      final deserialized = Branch.fromFirestore(map, 'branch-central');
      expect(deserialized.id, 'branch-central');
      expect(deserialized.name, 'Central Library');
      expect(deserialized.address, '123 Main Street, Cityville');
      expect(deserialized.phone, '555-0199');
    });

    test('Handles missing optional fields during deserialization', () {
      final minimalMap = <String, dynamic>{'name': 'Minimal Branch'};
      final deserialized = Branch.fromFirestore(minimalMap, 'branch-min');

      expect(deserialized.id, 'branch-min');
      expect(deserialized.name, 'Minimal Branch');
      expect(deserialized.address, isNull);
      expect(deserialized.phone, isNull);
    });

    test('Handles location field alias during deserialization', () {
      final aliasMap = <String, dynamic>{
        'name': 'Alias Branch',
        'location': '789 Secondary Rd',
      };
      final deserialized = Branch.fromFirestore(aliasMap, 'branch-alias');

      expect(deserialized.id, 'branch-alias');
      expect(deserialized.name, 'Alias Branch');
      expect(deserialized.address, '789 Secondary Rd');
    });

    test('copyWith updates properties properly', () {
      final updated = sampleBranch1.copyWith(
        name: 'Central Main Library',
        phone: '555-9999',
      );
      expect(updated.id, sampleBranch1.id);
      expect(updated.name, 'Central Main Library');
      expect(updated.address, sampleBranch1.address);
      expect(updated.phone, '555-9999');
    });

    test('Equality and hashCode operate correctly', () {
      final duplicate = Branch(
        id: 'branch-central',
        name: 'Central Library',
        address: '123 Main Street, Cityville',
        phone: '555-0199',
      );
      expect(sampleBranch1, equals(duplicate));
      expect(sampleBranch1.hashCode, equals(duplicate.hashCode));
      expect(sampleBranch1.toString(), contains('Central Library'));
    });
  });

  group('BranchService Operations Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BranchService branchService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      branchService = BranchService(firestore: fakeFirestore);
    });

    test('getBranches returns empty list when collection is empty', () async {
      final branches = await branchService.getBranches();
      expect(branches, isEmpty);
    });

    test('getBranches returns seeded branches', () async {
      fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
          sampleBranch1.toFirestore();
      fakeFirestore.store.documents['branches/${sampleBranch2.id}'] =
          sampleBranch2.toFirestore();

      final branches = await branchService.getBranches();
      expect(branches.length, 2);
      expect(
        branches.map((b) => b.name),
        containsAll(['Central Library', 'North Campus Library']),
      );
    });

    test(
      'getBranchById returns correct branch or null if non-existent or empty',
      () async {
        fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
            sampleBranch1.toFirestore();

        final found = await branchService.getBranchById(sampleBranch1.id);
        expect(found, isNotNull);
        expect(found!.name, 'Central Library');

        final missing = await branchService.getBranchById('non-existent-id');
        expect(missing, isNull);

        final emptyId = await branchService.getBranchById('   ');
        expect(emptyId, isNull);
      },
    );

    test('streamBranches emits branch updates in real time', () async {
      fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
          sampleBranch1.toFirestore();

      final stream = branchService.streamBranches();
      final firstEmitted = await stream.first;

      expect(firstEmitted.length, 1);
      expect(firstEmitted.first.id, sampleBranch1.id);
      expect(firstEmitted.first.name, sampleBranch1.name);
    });

    test('streamBranches handles empty collection properly', () async {
      final stream = branchService.streamBranches();
      final firstEmitted = await stream.first;

      expect(firstEmitted, isEmpty);
    });

    test('streamBranchById emits branch updates or null', () async {
      fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
          sampleBranch1.toFirestore();

      final stream = branchService.streamBranchById(sampleBranch1.id);
      final emitted = await stream.first;
      expect(emitted, isNotNull);
      expect(emitted!.name, sampleBranch1.name);

      final missingStream = branchService.streamBranchById('missing-id');
      final missingEmitted = await missingStream.first;
      expect(missingEmitted, isNull);

      final emptyStream = branchService.streamBranchById('  ');
      final emptyEmitted = await emptyStream.first;
      expect(emptyEmitted, isNull);
    });

    test('Handles Firestore errors gracefully in streamBranches', () async {
      final errorFirestore = ErrorFirebaseFirestore();
      final errorService = BranchService(firestore: errorFirestore);

      expect(
        errorService.streamBranches(),
        emitsError(isA<FirebaseException>()),
      );
    });

    test('Handles Firestore errors gracefully in getBranches', () async {
      final errorFirestore = ErrorFirebaseFirestore();
      final errorService = BranchService(firestore: errorFirestore);

      expect(
        () => errorService.getBranches(),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}

// ── Fake Test Doubles ────────────────────────────────────────────────────────

class FakeDocumentSnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  FakeDocumentSnapshot(this._id, this._data);

  final String _id;
  final T? _data;

  @override
  String get id => _id;

  @override
  bool get exists => _data != null;

  @override
  T? data() => _data;
}

class FakeQueryDocumentSnapshot<T extends Object?> extends Fake
    implements QueryDocumentSnapshot<T> {
  FakeQueryDocumentSnapshot(this._id, this._data);

  final String _id;
  final T _data;

  @override
  String get id => _id;

  @override
  bool get exists => true;

  @override
  T data() => _data;
}

class FakeQuerySnapshot<T extends Object?> extends Fake
    implements QuerySnapshot<T> {
  FakeQuerySnapshot(this._docs);

  final List<QueryDocumentSnapshot<T>> _docs;

  @override
  List<QueryDocumentSnapshot<T>> get docs => _docs;
}

class FakeDocumentReference<T extends Object?> extends Fake
    implements DocumentReference<T> {
  FakeDocumentReference(this._path, this._store);

  final String _path;
  final FakeFirestoreData _store;

  @override
  String get id => _path.split('/').last;

  @override
  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final data = _store.documents[_path];
    return FakeDocumentSnapshot<T>(id, data as T?);
  }

  @override
  Stream<DocumentSnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final data = _store.documents[_path];
    return Stream.value(FakeDocumentSnapshot<T>(id, data as T?));
  }
}

class FakeCollectionReference<T extends Object?> extends Fake
    implements CollectionReference<T> {
  FakeCollectionReference(this._collectionPath, this._store);

  final String _collectionPath;
  final FakeFirestoreData _store;

  @override
  DocumentReference<T> doc([String? path]) {
    final docId = path ?? 'generated_id_${_store.documents.length + 1}';
    return FakeDocumentReference<T>('$_collectionPath/$docId', _store);
  }

  @override
  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final docs = <QueryDocumentSnapshot<T>>[];
    _store.documents.forEach((path, data) {
      if (path.startsWith('$_collectionPath/')) {
        final docId = path.substring('$_collectionPath/'.length);
        docs.add(FakeQueryDocumentSnapshot<T>(docId, data as T));
      }
    });
    return FakeQuerySnapshot<T>(docs);
  }

  @override
  Stream<QuerySnapshot<T>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    final docs = <QueryDocumentSnapshot<T>>[];
    _store.documents.forEach((path, data) {
      if (path.startsWith('$_collectionPath/')) {
        final docId = path.substring('$_collectionPath/'.length);
        docs.add(FakeQueryDocumentSnapshot<T>(docId, data as T));
      }
    });
    return Stream.value(FakeQuerySnapshot<T>(docs));
  }
}

class FakeFirestoreData {
  final Map<String, Map<String, dynamic>> documents = {};
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final FakeFirestoreData store = FakeFirestoreData();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference<Map<String, dynamic>>(collectionPath, store);
  }
}

class ErrorFirebaseFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Firestore service unavailable.',
    );
  }
}
