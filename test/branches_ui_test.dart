// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librasync/models/branch.dart';
import 'package:librasync/screens/branches/branches_screen.dart';
import 'package:librasync/screens/home_screen.dart';
import 'package:librasync/services/branch_service.dart';
import 'package:librasync/widgets/branches/branch_card.dart';
import 'package:librasync/widgets/dashboard_card.dart';

void main() {
  final sampleBranch1 = Branch(
    id: 'branch-central',
    name: 'Central City Library',
    address: '100 Downtown Plaza, Cityville',
    phone: '555-0101',
  );

  final sampleBranch2 = Branch(
    id: 'branch-west',
    name: 'Westside Community Branch',
    address: '450 West End Avenue, Cityville',
    phone: '555-0102',
  );

  final sampleBranchMinimal = Branch(
    id: 'branch-mini',
    name: 'Express Kiosk Branch',
  );

  group('BranchCard Widget Tests', () {
    testWidgets('Renders branch name, address, and phone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BranchCard(branch: sampleBranch1)),
        ),
      );

      expect(find.text('Central City Library'), findsOneWidget);
      expect(find.text('100 Downtown Plaza, Cityville'), findsOneWidget);
      expect(find.text('555-0101'), findsOneWidget);
      expect(find.byIcon(Icons.location_city_rounded), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    });

    testWidgets('Renders branch with missing optional address and phone', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BranchCard(branch: sampleBranchMinimal)),
        ),
      );

      expect(find.text('Express Kiosk Branch'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(find.byIcon(Icons.phone_outlined), findsNothing);
    });

    testWidgets('Triggers onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchCard(branch: sampleBranch1, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Central City Library'));
      expect(tapped, isTrue);
    });
  });

  group('BranchesScreen Widget Tests', () {
    testWidgets('Displays loading indicator while waiting for data stream', (
      WidgetTester tester,
    ) async {
      final controller = StreamController<List<Branch>>();

      await tester.pumpWidget(
        MaterialApp(home: BranchesScreen(branchesStream: controller.stream)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading library branches...'), findsOneWidget);

      await controller.close();
    });

    testWidgets('Displays empty state when stream emits an empty list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BranchesScreen(branchesStream: Stream.value(<Branch>[])),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Branches Available'), findsOneWidget);
      expect(
        find.text(
          'There are no library branches registered at the moment.\nPlease check back later.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
    });

    testWidgets(
      'Displays error state and triggers retry when stream emits error',
      (WidgetTester tester) async {
        final controller = StreamController<List<Branch>>.broadcast();

        await tester.pumpWidget(
          MaterialApp(home: BranchesScreen(branchesStream: controller.stream)),
        );

        // Emit error
        controller.addError('Network connection failed');
        await tester.pumpAndSettle();

        expect(find.text('Failed to load library branches'), findsOneWidget);
        expect(
          find.text('Please check your connection and try again.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('branches_retry_btn')), findsOneWidget);

        // Tap retry button
        await tester.tap(find.byKey(const Key('branches_retry_btn')));
        await tester.pump();

        await controller.close();
      },
    );

    testWidgets('Renders list of branches with details and summary banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BranchesScreen(
            branchesStream: Stream.value([sampleBranch1, sampleBranch2]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('2 branches currently active in the LibraSync network.'),
        findsOneWidget,
      );
      expect(find.text('Central City Library'), findsOneWidget);
      expect(find.text('100 Downtown Plaza, Cityville'), findsOneWidget);
      expect(find.text('555-0101'), findsOneWidget);
      expect(find.text('Westside Community Branch'), findsOneWidget);
      expect(find.text('450 West End Avenue, Cityville'), findsOneWidget);
      expect(find.text('555-0102'), findsOneWidget);
      expect(
        find.byKey(Key('branch_card_${sampleBranch1.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('branch_card_${sampleBranch2.id}')),
        findsOneWidget,
      );
    });

    testWidgets('Renders singular text for single branch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BranchesScreen(branchesStream: Stream.value([sampleBranch1])),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('1 branch currently active in the LibraSync network.'),
        findsOneWidget,
      );
      expect(find.text('Central City Library'), findsOneWidget);
    });

    testWidgets('Functions with dependency injected BranchService', (
      WidgetTester tester,
    ) async {
      final fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
          sampleBranch1.toFirestore();
      final branchService = BranchService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MaterialApp(home: BranchesScreen(branchService: branchService)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Central City Library'), findsOneWidget);
      expect(find.text('100 Downtown Plaza, Cityville'), findsOneWidget);
      expect(
        find.byKey(Key('branch_card_${sampleBranch1.id}')),
        findsOneWidget,
      );
    });

    testWidgets('AppBar refresh button triggers stream refresh', (
      WidgetTester tester,
    ) async {
      final fakeFirestore = FakeFirebaseFirestore();
      fakeFirestore.store.documents['branches/${sampleBranch1.id}'] =
          sampleBranch1.toFirestore();
      final branchService = BranchService(firestore: fakeFirestore);

      await tester.pumpWidget(
        MaterialApp(home: BranchesScreen(branchService: branchService)),
      );

      await tester.pumpAndSettle();
      expect(find.text('Central City Library'), findsOneWidget);

      // Tap refresh action
      await tester.tap(find.byTooltip('Refresh branches'));
      await tester.pumpAndSettle();

      expect(find.text('Central City Library'), findsOneWidget);
    });
  });

  group('HomeScreen Navigation to BranchesScreen Tests', () {
    testWidgets('Tapping Branches dashboard card opens BranchesScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      final branchesCardFinder = find.widgetWithText(DashboardCard, 'Branches');
      expect(branchesCardFinder, findsOneWidget);

      await tester.tap(branchesCardFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BranchesScreen), findsOneWidget);
      expect(find.text('Library Branches'), findsOneWidget);
    });
  });
}

// ── Fake Firestore Test Doubles ──────────────────────────────────────────────

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
