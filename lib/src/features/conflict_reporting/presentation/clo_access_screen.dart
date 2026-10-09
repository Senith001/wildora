import 'package:flutter/material.dart';

import '../application/conflict_report_repository.dart';
import '../application/conflict_session.dart';

/// The server role claim is checked before constructing a CLO workflow screen.
class CloAccessScreen extends StatefulWidget {
  const CloAccessScreen({
    super.key,
    required this.repository,
    required this.child,
    this.session,
  });
  final ConflictReportRepository repository;
  final Widget child;
  final ConflictSession? session;
  @override
  State<CloAccessScreen> createState() => _CloAccessScreenState();
}

class _CloAccessScreenState extends State<CloAccessScreen> {
  late final _session = widget.session ?? FirebaseConflictSession();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _checking = true;
  bool _allowed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final allowed = await _session.isClo();
      if (mounted) setState(() => _allowed = allowed);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Could not check access. Please sign in.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signIn() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your CLO email and password.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await _session.signInClo(_email.text, _password.text);
      await widget.repository.refreshRemote();
      if (mounted) setState(() => _allowed = true);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Sign-in failed or this account has no CLO access.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('CLO sign-in')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Only an authorized Community Liaison Officer can review reports.',
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'CLO email'),
                ),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _checking ? null : _signIn,
                  child: Text(_checking ? 'Checking access...' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
