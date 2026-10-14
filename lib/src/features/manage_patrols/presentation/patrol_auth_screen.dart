import 'package:flutter/material.dart';

import '../application/patrol_controller.dart';
import 'patrol_theme.dart';
import 'patrol_widgets.dart';

/// Real Firebase Authentication Screen for Ranger Patrol Operations.
///
/// Ensures only authenticated field personnel can access patrol routes,
/// start tracking, or dispatch assignments.
class PatrolAuthScreen extends StatefulWidget {
  const PatrolAuthScreen({
    super.key,
    required this.controller,
    this.onAuthenticated,
  });

  final PatrolController controller;
  final VoidCallback? onAuthenticated;

  @override
  State<PatrolAuthScreen> createState() => _PatrolAuthScreenState();
}

class _PatrolAuthScreenState extends State<PatrolAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (widget.onAuthenticated != null) {
          widget.onAuthenticated!();
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _cleanErrorMessage(e);
        });
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    final str = error.toString();
    if (str.contains('user-not-found')) {
      return 'No registered account found for this email address.';
    }
    if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Incorrect password or invalid credentials. Please try again.';
    }
    if (str.contains('invalid-email')) {
      return 'The email address is improperly formatted.';
    }
    if (str.contains('user-disabled')) {
      return 'This ranger account has been disabled by an administrator.';
    }
    if (str.contains('too-many-requests')) {
      return 'Access temporarily blocked due to multiple failed attempts. Try again later.';
    }
    if (str.contains('network-request-failed')) {
      return 'Network connection failed. Please check your internet connection.';
    }
    return 'Authentication failed: $str';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolTheme.background,
      appBar: AppBar(
        title: const Text('Ranger Station • Sign In'),
        backgroundColor: PatrolTheme.forestDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ResponsiveContentWrapper(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand / Station Icon
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: PatrolTheme.forestPrimary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PatrolTheme.forestPrimary.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 42,
                          color: PatrolTheme.forestPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header Text
                    const Text(
                      'Wildora Field Operations',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: PatrolTheme.forestDeep,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in with your verified Ranger or Park Manager Firebase credentials.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: PatrolTheme.charcoalMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Banner if present
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PatrolTheme.errorSurface,
                          borderRadius: PatrolTheme.radiusMd,
                          border: Border.all(color: PatrolTheme.errorBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: PatrolTheme.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: PatrolTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Sign In Form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Official Email Address',
                              hintText: 'e.g. ranger@wildora.example',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your account email.';
                              }
                              if (!v.contains('@')) {
                                return 'Please enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _handleSignIn,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(
                              _isLoading
                                  ? 'Authenticating…'
                                  : 'Sign In to Station',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: PatrolTheme.forestPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: PatrolTheme.radiusMd,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Provisioning Guidance Callout
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PatrolTheme.surfaceCard,
                        borderRadius: PatrolTheme.radiusMd,
                        border: Border.all(color: PatrolTheme.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: PatrolTheme.charcoalMuted),
                              SizedBox(width: 6),
                              Text(
                                'Role Authority & Setup',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: PatrolTheme.charcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '• Park Managers & Field Rangers are provisioned securely via Firebase Admin SDK with custom claims or Firestore officer mappings.\n'
                            '• To provision demo accounts, run the administrator script: node scripts/manage_patrols/provision_patrol_users.cjs',
                            style: TextStyle(
                              fontSize: 11,
                              color: PatrolTheme.charcoalMuted,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
