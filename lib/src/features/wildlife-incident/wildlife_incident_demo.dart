import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'data/incident_report.dart';
import 'data/incident_repository.dart';
import 'incident_details_screen.dart';
import 'incident_location_screen.dart';
import 'incident_offline_screen.dart';
import 'incident_reports_screen.dart';
import 'incident_review_screen.dart';
import 'incident_success_screen.dart';
import 'incident_sync_screen.dart';
import 'incident_type_screen.dart';
import 'incident_theme.dart';
import 'incident_widgets.dart';
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
  final IncidentRepository? repository;
  final ValueChanged<int>? onNavigate;
  final TileProvider? tileProvider;
  @override
  State<WildlifeIncidentDemo> createState() => _WildlifeIncidentDemoState();
}

class _WildlifeIncidentDemoState extends State<WildlifeIncidentDemo> {
  late final IncidentRepository _repository;
  late Future<void> _loading;
  late int _tab;
  int _step = 1;
  IncidentDraft _draft = IncidentDraft();
  IncidentReport? _submitted;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? IncidentRepository.firebase();
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

  Widget _hubActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F1EB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: incidentGreen, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF123B2D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF5F6B65),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: incidentGreen),
          ],
        ),
      ),
    ),
  );

  Widget _buildIncidentHub() => Scaffold(
    body: Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/landscape.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0x660F583F), BlendMode.darken),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Wildlife Incident',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Respond to wildlife issues quickly and keep reports synced.',
                style: TextStyle(
                  color: Color(0xFFE7F2ED),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 84),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        _hubActionCard(
                          title: 'Report Incident',
                          subtitle: 'Report wildlife or poaching incidents',
                          icon: Icons.pets_rounded,
                          onTap: _openReportFlow,
                        ),
                        _hubActionCard(
                          title: 'View My Reports',
                          subtitle: 'Check submitted reports',
                          icon: Icons.assignment_rounded,
                          onTap: _openReports,
                        ),
                        _hubActionCard(
                          title: 'Sync Pending Reports',
                          subtitle: 'Upload offline reports',
                          icon: Icons.sync_alt_rounded,
                          onTap: _openSync,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final validation = _draft.validate();
    if (validation != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(validation)));
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final report = await _repository.submit(_draft);
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
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Widget _screen() {
    if (_tab == 0) return _buildIncidentHub();
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
