import 'incident_hub_screen.dart';
import 'application/incident_submission_controller.dart';
import 'incident_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'data/incident_report.dart';
import 'application/incident_access.dart';
import 'data/incident_failure_policy.dart';
import 'incident_details_screen.dart';
import 'incident_location_screen.dart';
import 'incident_offline_screen.dart';
import 'incident_reports_screen.dart';
import 'incident_review_screen.dart';
import 'incident_success_screen.dart';
import 'incident_sync_screen.dart';
import 'incident_type_screen.dart';
import 'incident_theme.dart';
import 'wildlife_incident_bottom_nav.dart';

/// Real incident reporting entry point. The name preserves existing route imports.
class WildlifeIncidentDemo extends StatefulWidget {
  const WildlifeIncidentDemo({
    super.key,
    this.initialTab = 0,
    this.showBottomNav = true,
    this.startAtIncident = false,
    this.repository,
    this.onNavigate,
    this.tileProvider,
  }) : assert(initialTab >= 0 && initialTab <= 3);
  final int initialTab;
  final bool showBottomNav;
  final bool startAtIncident;
  final IncidentFeatureAccess? repository;
  final ValueChanged<int>? onNavigate;
  final TileProvider? tileProvider;
  @override
  State<WildlifeIncidentDemo> createState() => _WildlifeIncidentDemoState();
}

class _WildlifeIncidentDemoState extends State<WildlifeIncidentDemo> {
  late final IncidentFeatureAccess _repository;
  late Future<void> _loading;
  late int _tab;
  int _step = 1;
  IncidentDraft _draft = IncidentDraft();
  IncidentReport? _submitted;
  late final IncidentSubmissionController _submission;
  bool get _submitting => _submission.submitting;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? createIncidentRepository();
    _submission = IncidentSubmissionController(_repository);
    _submission.addListener(_submissionChanged);
    _tab = widget.initialTab;
    _loading = _repository.initialize();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);
  void _another() {
    if (widget.onNavigate != null && _tab != 0) {
      widget.onNavigate!(1);
    }
    setState(() {
      _draft = IncidentDraft();
      _submitted = null;
      _step = 1;
      _tab = 0;
    });
  }

  void _openReportFlow() {
    setState(() {
      _draft = IncidentDraft();
      _submitted = null;
      _step = 1;
      _tab = 3;
    });
  }

  void _openReports() => setState(() => _tab = 1);

  void _openSync() => setState(() => _tab = 2);

  Future<void> _submit() async {
    try {
      final report = await _submission.submit(_draft);
      if (report == null) return;
      if (mounted) setState(() => _submitted = report);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not complete report submission: ${incidentErrorMessage(error)}',
            ),
          ),
        );
      }
    }
  }

  void _submissionChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _submission.removeListener(_submissionChanged);
    _submission.dispose();
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Widget _screen() {
    if (_tab == 0) {
      return IncidentHubScreen(
        onReport: _openReportFlow,
        onReports: _openReports,
        onSync: _openSync,
      );
    }
    if (_tab == 1) {
      return IncidentReportsScreen(
        repository: _repository,
        onBack: () => setState(() => _tab = 0),
        onAnother: _openReportFlow,
      );
    }
    if (_tab == 2) {
      return IncidentSyncScreen(
        repository: _repository,
        onBack: () => setState(() => _tab = 0),
      );
    }
    if (_submitted != null) {
      final report = _repository.reports.firstWhere(
        (item) => item.id == _submitted!.id,
        orElse: () => _submitted!,
      );
      void onReports() {
        if (widget.onNavigate != null) {
          widget.onNavigate!(1);
        }
        setState(() {
          _submitted = null;
          _step = 1;
          _tab = 1;
        });
      }

      return report.status == IncidentSyncStatus.synchronized
          ? IncidentSuccessScreen(
              report: report,
              onReports: onReports,
              onAnother: _another,
            )
          : IncidentOfflineScreen(
              report: report,
              onReports: onReports,
              onAnother: _another,
            );
    }
    return switch (_step) {
      1 => IncidentTypeScreen(
        draft: _draft,
        onChanged: () => setState(() {}),
        onBack: () => setState(() => _tab = 0),
        onNext: _next,
      ),
      2 => IncidentLocationScreen(
        draft: _draft,
        onBack: _back,
        onNext: _next,
        tileProvider: widget.tileProvider,
      ),
      3 => IncidentDetailsScreen(draft: _draft, onBack: _back, onNext: _next),
      _ => IncidentReviewScreen(
        draft: _draft,
        onBack: _back,
        onSubmit: _submit,
        submitting: _submitting,
      ),
    };
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: incidentTheme(), child: _buildFeature(context));

  Widget _buildFeature(BuildContext context) => PopScope(
    canPop: !_submitting && (_step == 1 || _tab != 0 || _submitted != null),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_submitting && _step > 1) _back();
    },
    child: Scaffold(
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Unable to open reports: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _loading = _repository.initialize()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListenableBuilder(
            listenable: _repository,
            builder: (_, _) => _screen(),
          );
        },
      ),
      bottomNavigationBar: widget.showBottomNav
          ? WildlifeIncidentBottomNav(
              selectedIndex: _tab == 0 ? 1 : 0,
              onDestinationSelected: _submitting
                  ? (_) {}
                  : (index) {
                      if (index == 0) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                        return;
                      }
                      setState(() => _tab = 0);
                    },
              includeProfile: false,
            )
          : null,
    ),
  );
}
