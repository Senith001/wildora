import 'dart:async';

import 'package:flutter/material.dart';

import '../application/conflict_report_repository.dart';

/// Restores reports for direct routes as well as navigation from feature home.
/// A failed load is recoverable and is never presented as empty report history.
class ConflictRepositoryView extends StatefulWidget {
  const ConflictRepositoryView({
    super.key,
    required this.repository,
    required this.builder,
  });
  final ConflictReportRepository repository;
  final TransitionBuilder builder;

  @override
  State<ConflictRepositoryView> createState() => _ConflictRepositoryViewState();
}

class _ConflictRepositoryViewState extends State<ConflictRepositoryView> {
  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void didUpdateWidget(ConflictRepositoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    try {
      await widget.repository.initialize();
    } on Object {
      // The coordinator exposes the failure; the view provides a retry.
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.repository,
    builder: (context, child) {
      if (widget.repository.initialized) return widget.builder(context, child);
      return Scaffold(
        appBar: AppBar(title: const Text('Conflict reports')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: widget.repository.errorMessage == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.repository.errorMessage!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _initialize,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
