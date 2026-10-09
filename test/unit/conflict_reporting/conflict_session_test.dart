import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/conflict_reporting/application/conflict_session.dart';

class TestToken extends Fake implements IdTokenResult {
  TestToken(this.claims);
  @override
  final Map<String, dynamic>? claims;
}

class TestUser extends Fake implements User {
  TestUser(this.uid, {this.claims = const {}});
  @override
  final String uid;
  final Map<String, dynamic> claims;
  bool forced = false;
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    forced = forceRefresh;
    return TestToken(claims);
  }
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User? user;
}

class TestAuth extends Fake implements FirebaseAuth {
  TestUser? current;
  TestUser loginUser = TestUser(
    'clo',
    claims: const {'role': 'clo', 'isDemo': true},
  );
  int anonymousSignIns = 0;
  String? email;
  @override
  User? get currentUser => current;
  @override
  Future<UserCredential> signInAnonymously() async {
    anonymousSignIns++;
    current = TestUser('anonymous');
    return TestCredential(current);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    current = loginUser;
    return TestCredential(current);
  }
}

void main() {
  test(
    'existing reporter identity is reused without creating another account',
    () async {
      final auth = TestAuth()..current = TestUser('existing');
      final session = FirebaseConflictSession(auth: auth);
      expect(await session.reporterId(), 'existing');
      expect(auth.anonymousSignIns, 0);
    },
  );
  test(
    'anonymous identity is created once and reused on later calls',
    () async {
      final auth = TestAuth();
      final session = FirebaseConflictSession(auth: auth);
      expect(await session.reporterId(), 'anonymous');
      expect(await session.reporterId(), 'anonymous');
      expect(auth.anonymousSignIns, 1);
    },
  );
  test('signed-out users and members do not gain CLO access', () async {
    final auth = TestAuth();
    final session = FirebaseConflictSession(auth: auth);
    expect(await session.isClo(), isFalse);
    expect(await session.isDemo(), isFalse);
    auth.current = TestUser('member');
    expect(await session.isClo(), isFalse);
    expect(auth.anonymousSignIns, 0);
  });
  test('sign-in trims email and refreshes the server role claim', () async {
    final auth = TestAuth();
    final session = FirebaseConflictSession(auth: auth);
    await session.signInClo(' demo@wildora.example ', 'test-only-password');
    expect(auth.email, 'demo@wildora.example');
    expect(auth.loginUser.forced, isTrue);
    expect(await session.isClo(), isTrue);
    expect(await session.isDemo(), isTrue);
  });
  test('valid credentials without a CLO role are rejected', () async {
    final auth = TestAuth()..loginUser = TestUser('member');
    await expectLater(
      FirebaseConflictSession(auth: auth)
          .signInClo('member@wildora.example', 'test-only-password'),
      throwsA(isA<CloAccessDenied>()),
    );
  });
}
