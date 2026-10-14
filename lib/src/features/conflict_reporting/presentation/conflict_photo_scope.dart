import 'package:flutter/widgets.dart';

import '../domain/conflict_report_ports.dart';

/// Shares the configured image reader with conflict-reporting screens.
class ConflictPhotoScope extends InheritedWidget {
  const ConflictPhotoScope({
    super.key,
    required this.downloader,
    required super.child,
  });

  final ConflictPhotoDownloader? downloader;

  static ConflictPhotoDownloader? readerOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ConflictPhotoScope>()
      ?.downloader;

  @override
  bool updateShouldNotify(ConflictPhotoScope oldWidget) =>
      downloader != oldWidget.downloader;
}
