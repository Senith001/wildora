import 'dart:async';

import 'package:flutter/material.dart';

import '../application/conflict_report_repository.dart';

class ConflictReportingHome extends StatefulWidget {
  const ConflictReportingHome({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  State<ConflictReportingHome> createState() => _ConflictReportingHomeState();
}

class _ConflictReportingHomeState extends State<ConflictReportingHome> {
  ConflictReportRepository get repository => widget.repository;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await repository.initialize();
    } on Object {
      // Repository exposes a recoverable loading error in its status banner.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          foregroundColor: Theme.of(context).colorScheme.primary,
          title: const Text('Community Conservation'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Protecting people.\nProtecting wildlife.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Report incidents quickly so our community liaison team can respond.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _statusBanner(context, repository),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.primary,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(context, '/conflict/report'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report a conflict',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Elephant sightings, crop raids and safety concerns',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: .82),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Text(
                                  'Start report',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.campaign_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.onPrimary
                            .withValues(alpha: .9),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: Text('My Reports (${repository.reports.length})'),
              onPressed: () =>
                  Navigator.pushNamed(context, '/conflict/reports'),
            ),
            const SizedBox(height: 24),
            Text(
              'More options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 10),
              child: ListTile(
                leading: Icon(
                  Icons.dashboard_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('CLO Dashboard'),
                subtitle: const Text('Review synchronized community reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/conflict/clo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner(
    BuildContext context,
    ConflictReportRepository repository,
  ) {
    final colors = Theme.of(context).colorScheme;
    final ready = repository.initialized;
    return Card(
      margin: EdgeInsets.zero,
      color: ready ? colors.primaryContainer : colors.tertiaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          ready ? Icons.cloud_upload_outlined : Icons.hourglass_empty,
          color: ready ? colors.primary : colors.tertiary,
        ),
        title: Text(
          ready ? 'Report delivery status' : 'Loading saved reports',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          repository.errorMessage ??
              (repository.pendingCount == 0
                  ? 'Reports are confirmed only after server receipt.'
                  : '${repository.pendingCount} report(s) waiting to sync.'),
        ),
        trailing: repository.pendingCount > 0
            ? TextButton(
                onPressed: () async {
                  try {
                    await repository.syncPending();
                  } on Object {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not load reports. Please retry.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Sync'),
              )
            : (!ready
                  ? TextButton(
                      onPressed: _initialize,
                      child: const Text('Retry'),
                    )
                  : null),
      ),
    );
  }
}
