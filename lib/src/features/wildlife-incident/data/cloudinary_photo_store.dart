import 'dart:convert';
import 'package:http/http.dart' as http;
import 'incident_report.dart';

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Public unsigned preset only; API secrets must never be shipped in the app.
class CloudinaryPhotoStore {
  CloudinaryPhotoStore({
    this.cloudName = const String.fromEnvironment(
      'CLOUDINARY_CLOUD_NAME',
      defaultValue: 'rhi5e0gz',
    ),
    this.uploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
      defaultValue: 'wildora_incidents',
    ),
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final String cloudName;
  final String uploadPreset;
  final http.Client Function() _clientFactory;

  Future<String> upload(IncidentPhoto photo) async {
    if (photo.bytes.isEmpty || photo.bytes.length > maxIncidentPhotoBytes) {
      throw const CloudinaryUploadException(
        'Each photo must be no larger than 5 MB.',
      );
    }
    final extension = switch (photo.contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => throw const CloudinaryUploadException(
        'Use JPEG, PNG or WebP photos.',
      ),
    };
    final client = _clientFactory();
    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload'),
            )
            ..fields['upload_preset'] = uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                photo.bytes,
                filename: 'incident.$extension',
              ),
            );
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 60));
      Object? body;
      try {
        body = jsonDecode(response.body);
      } on FormatException {
        body = null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body is Map ? body['error'] : null;
        final message = error is Map ? error['message'] : null;
        throw CloudinaryUploadException(
          'Photo upload failed: ${message is String ? message : 'Cloudinary HTTP ${response.statusCode}'}.',
          retryable:
              response.statusCode == 408 ||
              response.statusCode == 429 ||
              response.statusCode >= 500,
        );
      }
      final url = body is Map ? body['secure_url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'res.cloudinary.com') {
        throw const CloudinaryUploadException(
          'Cloudinary did not return a valid secure photo URL.',
        );
      }
      return url as String;
    } on http.ClientException {
      throw const CloudinaryUploadException(
        'Unable to reach the photo server. Your report remains saved on this device.',
        retryable: true,
      );
    } finally {
      client.close();
    }
  }
}
