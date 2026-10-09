import 'package:flutter/material.dart';

import 'data/incident_repository.dart';
import 'incident_sync_result_screen.dart';
import 'incident_widgets.dart';

class IncidentSyncScreen extends StatefulWidget {
  const IncidentSyncScreen({super.key, required this.repository, this.onBack});
  final IncidentRepository repository;
  final VoidCallback? onBack;
  @override
  State<IncidentSyncScreen> createState() => _IncidentSyncScreenState();
}

class _IncidentSyncScreenState extends State<IncidentSyncScreen> {
  IncidentSyncSummary? _summary;
  bool _starting = false;
  String? _error;
  Future<void> _sync() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final result = await widget.repository.syncPending();
      if (mounted) setState(() => _summary = result);
    } catch (error) {
      if (mounted) setState(() => _error = incidentErrorMessage(error));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final repo = widget.repository;
      if (_summary != null && !repo.syncing) {
        return IncidentSyncResultScreen(
          summary: _summary!,
          onDone: () => setState(() => _summary = null),
        );
      }
      final busy = repo.syncing || _starting;
      return IncidentPage(
        title: 'Sync Reports',
        onBack: widget.onBack,
        footer: SizedBox(
          width: double.infinity,
          child: IncidentActionButton(
            label: busy ? 'Uploading…' : 'Sync Now',
            onPressed: busy || repo.pendingCount == 0 ? null : _sync,
          ),
        ),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.cloud_upload, size: 90, color: incidentGreen),
          const SizedBox(height: 20),
          Text(
            busy ? 'Synchronizing' : 'Sync Pending Reports',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            '${repo.pendingCount} reports awaiting upload',
            textAlign: TextAlign.center,
          ),
          if (busy) ...[
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: repo.syncTotal == 0
                  ? null
                  : repo.syncCompleted / repo.syncTotal,
            ),
            const SizedBox(height: 8),
            Text(
              '${repo.syncCompleted} of ${repo.syncTotal} processed',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Keep the app open until synchronization finishes.',
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null)
            IncidentInfoCard(title: 'Sync error', value: _error!),
          if (repo.cloudError != null)
            IncidentInfoCard(
              title: 'Cloud connection',
              value: repo.cloudError!,
            ),
        ],
      );
    },
  );
}
