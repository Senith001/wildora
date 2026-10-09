import 'package:firebase_auth/firebase_auth.dart';

/// Identity operations are isolated from widgets and persistence adapters.
abstract interface class ConflictSession {
  Future<String> reporterId();
  Future<bool> isClo();
  Future<bool> isDemo();
  Future<void> signInClo(String email, String password);
}

class FirebaseConflictSession implements ConflictSession {
  FirebaseConflictSession({FirebaseAuth? auth}) : _providedAuth = auth;
  final FirebaseAuth? _providedAuth;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  @override
  Future<String> reporterId() async =>
      (_auth.currentUser ?? (await _auth.signInAnonymously()).user)!.uid;

  @override
  Future<bool> isClo() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    return (await user.getIdTokenResult()).claims?['role'] == 'clo';
  }

  @override
  Future<bool> isDemo() async =>
      (await _auth.currentUser?.getIdTokenResult())?.claims?['isDemo'] == true;

  @override
  Future<void> signInClo(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if ((await result.user!.getIdTokenResult(true)).claims?['role'] != 'clo') {
      throw const CloAccessDenied();
    }
  }
}

class CloAccessDenied implements Exception {
  const CloAccessDenied();
}
