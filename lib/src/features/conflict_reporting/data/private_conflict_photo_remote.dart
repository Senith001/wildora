import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../domain/conflict_report.dart';
import '../application/conflict_photo_settings.dart';
import '../domain/conflict_report_ports.dart';

class ConflictPhotoConfiguration {
  static String get endpoint => ConflictPhotoSettings.endpoint;
  static bool get enabled => ConflictPhotoSettings.enabled;

  static PrivateConflictPhotoRemote? create() => enabled
      ? PrivateConflictPhotoRemote(endpoint: Uri.parse(endpoint))
      : null;
}

class PhotoDeliveryFailed implements Exception {
  const PhotoDeliveryFailed(this.message);
  final String message;
}

/// Firebase credentials are sent only to the configured HTTPS photo backend.
/// Cloudinary API secrets and download signatures are never part of the app.
class PrivateConflictPhotoRemote implements ConflictPhotoRemote {
  PrivateConflictPhotoRemote({
    required this.endpoint,
    Future<String> Function()? tokenProvider,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
  }) : _tokenProvider = tokenProvider ?? _firebaseToken,
       _clientFactory = clientFactory ?? http.Client.new {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        (endpoint.path.isNotEmpty && endpoint.path != '/')) {
      throw ArgumentError(
        'The private photo endpoint must be an HTTPS origin.',
      );
    }
  }

  final Uri endpoint;
  final Duration timeout;
  final Future<String> Function() _tokenProvider;
  final http.Client Function() _clientFactory;

  static Future<String> _firebaseToken() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const PhotoDeliveryFailed('Sign in again to access report photos.');
    }
    return token;
  }

  @override
  bool canDownload(String url) => ownsUrl(url);

  bool ownsUrl(String url) {
    final parsed = Uri.tryParse(url);
    return parsed != null &&
        parsed.scheme == 'https' &&
        parsed.origin == endpoint.origin &&
        parsed.userInfo.isEmpty &&
        !parsed.hasQuery &&
        !parsed.hasFragment &&
        RegExp(
          r'^/reports/[A-Za-z0-9_-]{1,128}/photo/[a-f0-9]{64}\.(jpg|jpeg|png|webp)$',
        ).hasMatch(parsed.path);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenProvider();
    if (token.isEmpty) {
      throw const PhotoDeliveryFailed('Sign in again to access photos.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final message = switch (response.statusCode) {
      401 => 'Sign in again to access report photos.',
      403 => 'You do not have permission to access this report photo.',
      413 => 'Choose a photo smaller than 5 MB.',
      415 => 'Choose a JPEG, PNG or WebP photo.',
      429 => 'Too many photo uploads. Please try again later.',
      _ =>
        'Photo service unavailable. Your report remains saved; please retry.',
    };
    throw PhotoDeliveryFailed(message);
  }

  @override
  Future<String> upload(ConflictReport report) async {
    report.validate();
    final bytes = report.photoBytes;
    if (bytes == null ||
        bytes.isEmpty ||
        report.reporterId == null ||
        !{
          'image/jpeg',
          'image/png',
          'image/webp',
        }.contains(report.photoContentType)) {
      throw const PhotoDeliveryFailed(
        'A valid photo and reporter are required.',
      );
    }
    final client = _clientFactory();
    try {
      final response = await client
          .post(
            endpoint.resolve('/reports/${report.id}/photo'),
            headers: {
              ...await _headers(),
              'Content-Type': report.photoContentType!,
            },
            body: bytes,
          )
          .timeout(timeout);
      _check(response);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['photoUrl'];
      if (url is! String ||
          !ownsUrl(url) ||
          Uri.parse(url).pathSegments[1] != report.id ||
          data['reporterId'] != report.reporterId) {
        throw const PhotoDeliveryFailed(
          'Photo upload acknowledgement is invalid.',
        );
      }
      return url;
    } finally {
      client.close();
    }
  }

  @override
  Future<List<int>> download(String url) async {
    if (!ownsUrl(url)) {
      throw const PhotoDeliveryFailed('Untrusted photo address.');
    }
    final client = _clientFactory();
    try {
      final response = await client
          .get(Uri.parse(url), headers: await _headers())
          .timeout(timeout);
      _check(response);
      if (!{
            'image/jpeg',
            'image/png',
            'image/webp',
          }.contains(response.headers['content-type']?.split(';').first) ||
          response.bodyBytes.isEmpty ||
          response.bodyBytes.length > 5 * 1024 * 1024) {
        throw const PhotoDeliveryFailed('The photo response is invalid.');
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }
}
