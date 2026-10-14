import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/application/conflict_session.dart';
import 'package:wildora/src/features/conflict_reporting/application/conflict_report_repository.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/clo_access_screen.dart';

import '../../unit/conflict_reporting/fakes.dart';

class FakeSession implements ConflictSession {
  bool allowed = false;
  bool fail = false;
  int attempts = 0;
  @override
  Future<String> reporterId() async => 'member';
  @override
  Future<bool> isClo() async => allowed;
  @override
  Future<bool> isDemo() async => false;
  @override
  Future<void> signInClo(String email, String password) async {
    attempts++;
    if (fail) throw const CloAccessDenied();
    allowed = true;
  }
}

void main() {
  late FakeSession session;
  late FakeReportRemote remote;
  late ConflictReportRepository repository;
  setUp(() {
    session = FakeSession();
    remote = FakeReportRemote();
    repository = ConflictReportRepository(
      store: FakeReportStore(),
      remote: remote,
    );
  });
  tearDown(() async {
    repository.dispose();
    await remote.events.close();
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CloAccessScreen(
          repository: repository,
          session: session,
          child: const Scaffold(body: Text('Protected dashboard')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('members cannot see the protected dashboard', (tester) async {
    await pump(tester);
    expect(find.text('CLO sign-in'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your CLO email and password.'), findsOneWidget);
    expect(session.attempts, 0);
  });
  testWidgets('authorized CLO can enter directly', (tester) async {
    session.allowed = true;
    await pump(tester);
    expect(find.text('Protected dashboard'), findsOneWidget);
    expect(find.text('CLO sign-in'), findsNothing);
  });
  testWidgets('failed role check retains sign-in form', (tester) async {
    session.fail = true;
    await pump(tester);
    await tester.enterText(
      find.byType(TextField).at(0),
      'demo@wildora.example',
    );
    await tester.enterText(find.byType(TextField).at(1), 'test password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign-in failed'), findsOneWidget);
    expect(find.text('Protected dashboard'), findsNothing);
  });
  testWidgets(
    'successful sign-in refreshes feed before revealing the dashboard',
    (tester) async {
      await pump(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'demo@wildora.example',
      );
      await tester.enterText(find.byType(TextField).at(1), 'test password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Protected dashboard'), findsOneWidget);
      expect(repository.initialized, isTrue);
      expect(session.attempts, 1);
    },
  );
}
