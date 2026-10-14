import 'package:flutter/material.dart';

import 'dart:typed_data';

import '../domain/conflict_report.dart';
import '../domain/conflict_report_ports.dart';
import '../application/conflict_photo_settings.dart';
import 'conflict_photo_scope.dart';

/// Shows evidence consistently for reporter details and CLO review. A synced
/// report does not imply that a device-only attachment was delivered remotely.
class ConflictReportPhoto extends StatelessWidget {
  const ConflictReportPhoto({
    super.key,
    required this.report,
    this.photoRemote,
  });

  final ConflictReport report;
  final ConflictPhotoDownloader? photoRemote;

  @override
  Widget build(BuildContext context) {
    final bytes = report.photoBytes;
    final url = report.photoUrl?.trim();
    final localOnly = report.photoDeliveryStatus == 'deviceOnly';
    final privateRemote = photoRemote ?? ConflictPhotoScope.readerOf(context);
    Widget unavailable(BuildContext context, Object error, StackTrace? stack) =>
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Photo unavailable. The report details are still available.',
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident photo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (bytes != null)
              Image.memory(
                bytes,
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
                semanticLabel: 'Incident photograph',
                errorBuilder: unavailable,
              )
            else if (url != null && url.isNotEmpty)
              if (privateRemote != null && privateRemote.canDownload(url))
                _PrivatePhoto(url: url, remote: privateRemote)
              else
                Image.network(
                  url,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  semanticLabel: 'Incident photograph',
                  errorBuilder: unavailable,
                )
            else if (!localOnly)
              const Text('No photo attached.'),
            if (localOnly) ...[
              const SizedBox(height: 8),
              Text(
                ConflictPhotoSettings.enabled
                    ? (bytes == null
                          ? 'The photo is still on the reporter’s device and is not available here. It will be visible after the reporter uploads it.'
                          : 'Photo saved on this device. It has not been delivered to other devices yet. Use Upload saved photo to deliver it securely to the CLO.')
                    : bytes == null
                    ? 'The photo is saved only on the reporter’s device and is not available here. Cloud photo delivery is not enabled.'
                    : 'Photo saved on this device. It has not been delivered to other devices because cloud photo delivery is not enabled.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Retains a single authenticated request across parent rebuilds. Retry starts
/// a fresh request without putting bearer tokens in URLs or public caches.
class _PrivatePhoto extends StatefulWidget {
  const _PrivatePhoto({required this.url, required this.remote});
  final String url;
  final ConflictPhotoDownloader remote;

  @override
  State<_PrivatePhoto> createState() => _PrivatePhotoState();
}

class _PrivatePhotoState extends State<_PrivatePhoto> {
  late Future<List<int>> _image = widget.remote.download(widget.url);

  @override
  void didUpdateWidget(covariant _PrivatePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.remote != widget.remote) {
      _image = widget.remote.download(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
    future: _image,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text('Photo unavailable. Check your sign-in and connection.'),
            TextButton(
              onPressed: () {
                final nextImage = widget.remote.download(widget.url);
                setState(() {
                  _image = nextImage;
                });
              },
              child: const Text('Retry photo'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Image.memory(
        Uint8List.fromList(snapshot.data!),
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
        semanticLabel: 'Incident photograph',
        errorBuilder: (_, _, _) =>
            const Text('Photo unavailable. The image could not be displayed.'),
      );
    },
  );
}
