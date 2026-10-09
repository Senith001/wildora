import 'package:flutter/material.dart';

enum SyncStatus { pending, syncing, synced, failed }

enum ReportStatus { savedOffline, submitted, underReview, resolved }

enum WildlifeType { elephant, leopard, wildBoar, other }

enum ConflictType {
  cropRaiding,
  animalSighting,
  propertyDamage,
  threatToPeople,
  other,
}

extension _Labels on Enum {
  String get label {
    switch (this) {
      case WildlifeType.elephant:
        return 'Elephant';
      case WildlifeType.leopard:
        return 'Leopard';
      case WildlifeType.wildBoar:
        return 'Wild Boar';
      case WildlifeType.other:
        return 'Other';
      case ConflictType.cropRaiding:
        return 'Crop Raiding';
      case ConflictType.animalSighting:
        return 'Animal Sighting';
      case ConflictType.propertyDamage:
        return 'Property Damage';
      case ConflictType.threatToPeople:
        return 'Threat to People';
      case ConflictType.other:
        return 'Other';
      case SyncStatus.pending:
        return 'Pending Sync';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.failed:
        return 'Sync Failed';
      case ReportStatus.savedOffline:
        return 'Saved Offline';
      case ReportStatus.submitted:
        return 'Submitted';
      case ReportStatus.underReview:
        return 'Under Review';
      case ReportStatus.resolved:
        return 'Resolved';
      default:
        return name;
    }
  }
}

extension ConflictThemeColors on BuildContext {
  Color syncStatusColor(SyncStatus status) {
    final colors = Theme.of(this).colorScheme;
    return switch (status) {
      SyncStatus.synced => colors.primary,
      SyncStatus.syncing => colors.secondary,
      SyncStatus.failed => colors.error,
      SyncStatus.pending => colors.tertiary,
    };
  }

  Color reportStatusColor(ReportStatus status) {
    final colors = Theme.of(this).colorScheme;
    return switch (status) {
      ReportStatus.resolved => colors.primary,
      ReportStatus.underReview => colors.secondary,
      ReportStatus.submitted => colors.tertiary,
      ReportStatus.savedOffline => colors.error,
    };
  }
}

class ConflictReport {
  ConflictReport({
    required this.id,
    required this.referenceNumber,
    required this.wildlifeType,
    required this.conflictType,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.locationDescription,
    required this.createdAt,
    this.photoPath,
    this.reportStatus = ReportStatus.savedOffline,
    this.syncStatus = SyncStatus.pending,
    this.responseNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.resolvedAt,
  }) : updatedAt = createdAt;

  final String id;
  final String referenceNumber;
  final WildlifeType wildlifeType;
  final ConflictType conflictType;
  final String description;
  final String? photoPath;
  final double latitude;
  final double longitude;
  final String locationDescription;
  final DateTime createdAt;
  DateTime updatedAt;
  ReportStatus reportStatus;
  SyncStatus syncStatus;
  String? responseNotes;
  String? reviewedBy;
  DateTime? reviewedAt;
  DateTime? resolvedAt;
}

class ConflictReportRepository extends ChangeNotifier {
  final List<ConflictReport> _reports = [];
  int _sequence = 240;
  bool simulateOnline = true;
  bool simulateSyncFailure = false;

  List<ConflictReport> get reports => List.unmodifiable(_reports);
  int get pendingCount =>
      _reports.where((r) => r.syncStatus != SyncStatus.synced).length;
  List<ConflictReport> get synchronizedReports =>
      _reports.where((r) => r.syncStatus == SyncStatus.synced).toList();

  ConflictReport create({
    required WildlifeType wildlifeType,
    required ConflictType conflictType,
    required String description,
    required double latitude,
    required double longitude,
    required String locationDescription,
    String? photoPath,
  }) {
    final now = DateTime.now();
    final report = ConflictReport(
      id: now.microsecondsSinceEpoch.toString(),
      referenceNumber: 'HWC-${++_sequence}',
      wildlifeType: wildlifeType,
      conflictType: conflictType,
      description: description.trim(),
      latitude: latitude,
      longitude: longitude,
      locationDescription: locationDescription,
      createdAt: now,
      photoPath: photoPath,
    );
    _reports.insert(0, report);
    notifyListeners();
    return report;
  }

  Future<bool> sync(ConflictReport report) async {
    report.syncStatus = SyncStatus.syncing;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final success = simulateOnline && !simulateSyncFailure;
    report.syncStatus = success ? SyncStatus.synced : SyncStatus.failed;
    if (success) report.reportStatus = ReportStatus.submitted;
    report.updatedAt = DateTime.now();
    notifyListeners();
    return success;
  }

  Future<void> syncPending() async {
    for (final report in _reports.where(
      (r) => r.syncStatus != SyncStatus.synced,
    )) {
      await sync(report);
    }
  }

  void markUnderReview(ConflictReport report) {
    report.reportStatus = ReportStatus.underReview;
    report.reviewedBy = 'Community Liaison Officer';
    report.reviewedAt = DateTime.now();
    report.updatedAt = DateTime.now();
    notifyListeners();
  }

  void resolve(ConflictReport report, String notes) {
    report.reportStatus = ReportStatus.resolved;
    report.responseNotes = notes.trim();
    report.resolvedAt = DateTime.now();
    report.updatedAt = DateTime.now();
    notifyListeners();
  }
}

class ConflictReportingHome extends StatelessWidget {
  const ConflictReportingHome({super.key, required this.repository});
  final ConflictReportRepository repository;

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
    final online = repository.simulateOnline;
    return Card(
      margin: EdgeInsets.zero,
      color: online ? colors.primaryContainer : colors.tertiaryContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(
          online ? Icons.wifi : Icons.wifi_off,
          color: online ? colors.primary : colors.tertiary,
        ),
        title: Text(
          online ? 'You are online' : 'You are offline',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          repository.pendingCount == 0
              ? 'Reports can be submitted now.'
              : '${repository.pendingCount} report(s) waiting to sync.',
        ),
        trailing: repository.pendingCount > 0
            ? TextButton(
                onPressed: online ? repository.syncPending : null,
                child: const Text('Sync'),
              )
            : null,
      ),
    );
  }
}

class ConflictReportFormScreen extends StatefulWidget {
  const ConflictReportFormScreen({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  State<ConflictReportFormScreen> createState() =>
      _ConflictReportFormScreenState();
}

class _ConflictReportFormScreenState extends State<ConflictReportFormScreen> {
  WildlifeType? wildlife;
  ConflictType? conflict;
  String location = '';
  double latitude = 6.9271;
  double longitude = 79.8612;
  bool hasPhoto = false;
  bool submitting = false;
  final description = TextEditingController();

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _chooseLocation() async {
    final controller = TextEditingController(text: location);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter incident location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Village, road or landmark',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) setState(() => location = result);
  }

  Future<void> _submit() async {
    if (wildlife == null ||
        conflict == null ||
        description.text.trim().isEmpty ||
        location.isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }
    setState(() => submitting = true);
    final report = widget.repository.create(
      wildlifeType: wildlife!,
      conflictType: conflict!,
      description: description.text,
      latitude: latitude,
      longitude: longitude,
      locationDescription: location,
      photoPath: hasPhoto
          ? 'demo-photo-${DateTime.now().millisecondsSinceEpoch}.jpg'
          : null,
    );
    if (widget.repository.simulateOnline) await widget.repository.sync(report);
    if (!mounted) return;
    setState(() => submitting = false);
    await Navigator.pushReplacementNamed(
      context,
      '/conflict/confirmation',
      arguments: report,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        foregroundColor: Theme.of(context).colorScheme.primary,
        leading: const BackButton(),
        title: const Text(
          'Report Conflict',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _departmentBanner(context),
          const SizedBox(height: 20),
          _sectionLabel(context, 'CONFLICT TYPE'),
          DropdownButtonFormField<ConflictType>(
            initialValue: conflict,
            decoration: InputDecoration(
              hintText: 'Select conflict type',
              prefixIcon: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            items: ConflictType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => conflict = value),
          ),
          const SizedBox(height: 14),
          _sectionLabel(context, 'WILDLIFE TYPE'),
          DropdownButtonFormField<WildlifeType>(
            initialValue: wildlife,
            decoration: const InputDecoration(hintText: 'Select wildlife type'),
            items: WildlifeType.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) => setState(() => wildlife = value),
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'INCIDENT LOCATION'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  tileColor: Theme.of(context).colorScheme.primaryContainer,
                  leading: Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    location.isEmpty ? 'Current Location' : location,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: TextButton(
                    onPressed: _chooseLocation,
                    child: const Text('Change'),
                  ),
                ),
                _LocationPreview(latitude: latitude, longitude: longitude),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              location = 'Current Location';
              latitude = 6.9271;
              longitude = 79.8612;
            }),
            icon: const Icon(Icons.my_location),
            label: const Text('Use Current Location'),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'DESCRIPTION'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: TextField(
                controller: description,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened and when...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionLabel(context, 'PHOTO (OPTIONAL)'),
          Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => setState(() => hasPhoto = !hasPhoto),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 74,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPhoto ? Icons.delete_outline : Icons.add_a_photo,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasPhoto ? 'Remove Photo' : '+ Add Photo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasPhoto)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Demo photo attached',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: submitting ? null : _submit,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              submitting ? 'Saving report...' : 'Submit Conflict Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .35,
      ),
    ),
  );

  Widget _departmentBanner(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        'DEPARTMENT OF WILDLIFE CONSERVATION',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('Sri Lanka • Smart Monitoring Network'),
    ),
  );
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 116,
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _MapPreviewPainter(
            lineColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
        Center(
          child: Icon(
            Icons.location_pin,
            size: 34,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 8,
          child: Text(
            '${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              backgroundColor: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .8),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter({required this.lineColor});
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF7C956B);
    canvas.drawRect(Offset.zero & size, background);
    final contour = Paint()
      ..color = lineColor.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var offset = -size.height; offset < size.width; offset += 38) {
      final path = Path()
        ..moveTo(offset, size.height)
        ..quadraticBezierTo(offset + 42, size.height * .45, offset + 90, 0);
      canvas.drawPath(path, contour);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) => false;
}

class ConflictConfirmationScreen extends StatelessWidget {
  const ConflictConfirmationScreen({super.key, required this.report});
  final ConflictReport report;

  @override
  Widget build(BuildContext context) {
    final pending = report.syncStatus != SyncStatus.synced;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 28),
          children: [
            Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  pending ? Icons.cloud_off : Icons.check,
                  size: 38,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              pending ? 'Report Saved' : 'Report Submitted',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              pending
                  ? 'Your report is saved on this device and will be sent when connectivity is available.'
                  : 'Your report has been received and is currently being processed by dispatch.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'REPORT REFERENCE ID',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Chip(
                          label: Text(
                            pending ? 'Pending Sync' : 'Pending Response',
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          side: BorderSide(color: colors.error),
                          backgroundColor: colors.surface,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      '#${report.referenceNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    _summaryRow(
                      context,
                      Icons.info_outline,
                      'CONFLICT TYPE',
                      report.conflictType.label,
                    ),
                    const SizedBox(height: 14),
                    _summaryRow(
                      context,
                      Icons.location_on_outlined,
                      'LOCATION',
                      report.locationDescription,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              color: colors.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.shield_outlined, color: colors.primary),
                title: const Text(
                  'A nearby wildlife ranger and community liaison officer have been notified.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/conflict',
                  (route) => route.isFirst,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}

class MyConflictReportsScreen extends StatelessWidget {
  const MyConflictReportsScreen({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: repository.reports.isEmpty
          ? const Center(child: Text('No reports yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: repository.reports.length,
              itemBuilder: (context, index) {
                final report = repository.reports[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      report.syncStatus == SyncStatus.synced
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      color: context.syncStatusColor(report.syncStatus),
                    ),
                    title: Text(report.referenceNumber),
                    subtitle: Text(
                      '${report.wildlifeType.label} • ${report.conflictType.label}\n'
                      '${report.reportStatus.label} • ${report.syncStatus.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.reportStatusColor(report.reportStatus),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/conflict/details',
                      arguments: report,
                    ),
                  ),
                );
              },
            ),
    ),
  );
}

class ConflictDetailsScreen extends StatelessWidget {
  const ConflictDetailsScreen({
    super.key,
    required this.report,
    required this.repository,
  });
  final ConflictReport report;
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(report.referenceNumber)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              Icons.info_outline,
              color: context.reportStatusColor(report.reportStatus),
            ),
            title: Text(report.reportStatus.label),
            subtitle: Text(
              report.syncStatus.label,
              style: TextStyle(
                color: context.syncStatusColor(report.syncStatus),
              ),
            ),
          ),
        ),
        _detail(context, 'Wildlife', report.wildlifeType.label),
        _detail(context, 'Conflict', report.conflictType.label),
        _detail(context, 'Location', report.locationDescription),
        _detail(context, 'Description', report.description),
        _detail(
          context,
          'Reported',
          report.createdAt.toLocal().toString().split('.').first,
        ),
        if (report.responseNotes != null)
          _detail(context, 'Officer response', report.responseNotes!),
        if (report.syncStatus != SyncStatus.synced)
          FilledButton.icon(
            onPressed: () => repository.sync(report),
            icon: const Icon(Icons.sync),
            label: const Text('Retry Sync'),
          ),
      ],
    ),
  );

  Widget _detail(BuildContext context, String title, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    ),
  );
}

class CloDashboardScreen extends StatelessWidget {
  const CloDashboardScreen({super.key, required this.repository});
  final ConflictReportRepository repository;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) {
      final reports = repository.synchronizedReports;
      int count(ReportStatus status) =>
          reports.where((report) => report.reportStatus == status).length;
      return Scaffold(
        appBar: AppBar(title: const Text('CLO Dashboard')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _stat(context, 'Pending', count(ReportStatus.submitted)),
                _stat(context, 'Review', count(ReportStatus.underReview)),
                _stat(context, 'Resolved', count(ReportStatus.resolved)),
              ],
            ),
            const SizedBox(height: 20),
            if (reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No synchronized reports are available for review.',
                  ),
                ),
              ),
            ...reports.map(
              (report) => Card(
                child: ListTile(
                  leading: Icon(
                    Icons.assignment,
                    color: context.reportStatusColor(report.reportStatus),
                  ),
                  title: Text(report.referenceNumber),
                  subtitle: Text(
                    '${report.wildlifeType.label} • ${report.conflictType.label}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/conflict/clo/review',
                    arguments: report,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _stat(BuildContext context, String label, int value) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class CloReviewScreen extends StatefulWidget {
  const CloReviewScreen({
    super.key,
    required this.report,
    required this.repository,
  });
  final ConflictReport report;
  final ConflictReportRepository repository;

  @override
  State<CloReviewScreen> createState() => _CloReviewScreenState();
}

class _CloReviewScreenState extends State<CloReviewScreen> {
  late final notes = TextEditingController(text: widget.report.responseNotes);

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review Report')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.report.referenceNumber,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Chip(
          avatar: Icon(
            Icons.circle,
            size: 12,
            color: context.reportStatusColor(widget.report.reportStatus),
          ),
          label: Text(widget.report.reportStatus.label),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.report.wildlifeType.label} • ${widget.report.conflictType.label}',
        ),
        const SizedBox(height: 8),
        Text(widget.report.description),
        const SizedBox(height: 8),
        Text('Location: ${widget.report.locationDescription}'),
        const SizedBox(height: 24),
        if (widget.report.reportStatus == ReportStatus.submitted)
          FilledButton(
            onPressed: () => setState(
              () => widget.repository.markUnderReview(widget.report),
            ),
            child: const Text('Mark Under Review'),
          ),
        TextField(
          controller: notes,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Response notes',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            if (notes.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter response notes first.')),
              );
              return;
            }
            widget.repository.resolve(widget.report, notes.text);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Report resolved.')));
          },
          icon: const Icon(Icons.check),
          label: const Text('Record Response & Resolve'),
        ),
      ],
    ),
  );
}
