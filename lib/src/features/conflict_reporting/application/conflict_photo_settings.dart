/// Public build settings; backend credentials remain outside the app.
class ConflictPhotoSettings {
  static const endpoint = String.fromEnvironment(
    'CONFLICT_PHOTO_API_URL',
    defaultValue: 'https://wildora-conflict-photos.wildora.workers.dev',
  );

  static bool get enabled => endpoint.isNotEmpty;
}
