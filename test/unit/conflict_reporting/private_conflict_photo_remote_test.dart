import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wildora/src/features/conflict_reporting/data/private_conflict_photo_remote.dart';
import 'package:wildora/src/features/conflict_reporting/domain/conflict_report.dart';

const endpoint = 'https://photos.example';
final url = '$endpoint/reports/photo-1/photo/${'a' * 64}.jpg';
ConflictReport photoReport({
  String? reporter = 'owner',
  String? mime = 'image/jpeg',
  Uint8List? bytes,
}) => ConflictReport(
  id: 'photo-1',
  referenceNumber: 'HWC-photo-1',
  wildlifeType: WildlifeType.elephant,
  conflictType: ConflictType.cropRaiding,
  description: 'Test',
  latitude: 7,
  longitude: 80,
  locationDescription: 'Test',
  createdAt: DateTime.utc(2026),
  reporterId: reporter,
  photoBytes: bytes ?? Uint8List.fromList([255, 216, 255, 1]),
  photoContentType: mime,
);
PrivateConflictPhotoRemote remote(
  Future<http.Response> Function(http.Request) handler, {
  Duration timeout = const Duration(seconds: 20),
  Future<String> Function()? token,
}) => PrivateConflictPhotoRemote(
  endpoint: Uri.parse(endpoint),
  tokenProvider: token ?? () async => 'test-token',
  clientFactory: () => MockClient(handler),
  timeout: timeout,
);

void main() {
  for (final value in [
    'http://photos.example',
    'https://user:pass@photos.example',
    'https://photos.example/path',
    'https://photos.example?q=1',
    'https://photos.example#fragment',
  ]) {
    test('rejects unsafe endpoint $value', () {
      expect(
        () => PrivateConflictPhotoRemote(endpoint: Uri.parse(value)),
        throwsArgumentError,
      );
    });
  }
  test('uploads binary photo with authorization and accepts only its own report acknowledgement', () async {
    final service = remote((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), '$endpoint/reports/photo-1/photo');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], 'image/jpeg');
      expect(request.bodyBytes, orderedEquals([255, 216, 255, 1]));
      return http.Response(
        jsonEncode({'photoUrl': url, 'reporterId': 'owner'}),
        200,
      );
    });
    expect(await service.upload(photoReport()), url);
  });
  for (final invalid in [
    'https://evil.example/photo.jpg',
    '$endpoint/reports/other/photo/${'a' * 64}.jpg',
    'file:///private/photo.jpg',
  ]) {
    test('rejects acknowledgement URL $invalid', () async {
      final service = remote(
        (_) async => http.Response(
          jsonEncode({'photoUrl': invalid, 'reporterId': 'owner'}),
          200,
        ),
      );
      await expectLater(
        service.upload(photoReport()),
        throwsA(isA<PhotoDeliveryFailed>()),
      );
    });
  }
  test('rejects another reporter in upload acknowledgement', () async {
    final service = remote(
      (_) async => http.Response(
        jsonEncode({'photoUrl': url, 'reporterId': 'other'}),
        200,
      ),
    );
    await expectLater(
      service.upload(photoReport()),
      throwsA(isA<PhotoDeliveryFailed>()),
    );
  });
  test(
    'missing reporter or unsupported image type does not send a request',
    () async {
      var requests = 0;
      final service = remote((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      await expectLater(
        service.upload(photoReport(reporter: null)),
        throwsA(isA<PhotoDeliveryFailed>()),
      );
      await expectLater(
        service.upload(photoReport(mime: 'image/svg+xml')),
        throwsA(isA<PhotoDeliveryFailed>()),
      );
      expect(requests, 0);
    },
  );
  test('untrusted download URLs never receive a bearer token', () async {
    var tokens = 0;
    final service = remote(
      (_) async => http.Response('', 200),
      token: () async {
        tokens++;
        return 'test-token';
      },
    );
    for (final value in [
      'https://evil.example/image.png',
      'file:///private',
      '$url?token=anything',
      '$url#fragment',
    ]) {
      await expectLater(
        service.download(value),
        throwsA(isA<PhotoDeliveryFailed>()),
      );
    }
    expect(tokens, 0);
  });
  test('downloads authenticated image bytes', () async {
    final service = remote((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), url);
      expect(request.headers['Authorization'], 'Bearer test-token');
      return http.Response.bytes(
        [255, 216, 255, 1],
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    });
    expect(await service.download(url), orderedEquals([255, 216, 255, 1]));
  });
  for (final status in [401, 403, 413, 415, 429, 500]) {
    test('upload HTTP $status cannot acknowledge success', () async {
      final service = remote((_) async => http.Response('{}', status));
      await expectLater(
        service.upload(photoReport()),
        throwsA(isA<PhotoDeliveryFailed>()),
      );
    });
  }
  test('empty authentication prevents network access', () async {
    var requests = 0;
    final service = remote((_) async {
      requests++;
      return http.Response('{}', 200);
    }, token: () async => '');
    await expectLater(
      service.upload(photoReport()),
      throwsA(isA<PhotoDeliveryFailed>()),
    );
    expect(requests, 0);
  });
  test('upload timeout remains an error', () async {
    final service = remote(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      service.upload(photoReport()),
      throwsA(isA<TimeoutException>()),
    );
  });
  test('download timeout remains an error', () async {
    final service = remote(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(service.download(url), throwsA(isA<TimeoutException>()));
  });
  test('malformed upload JSON cannot become a photo URL', () async {
    final service = remote((_) async => http.Response('invalid json', 200));
    await expectLater(service.upload(photoReport()), throwsFormatException);
  });
  test(
    'non-image, empty and oversized download responses are rejected',
    () async {
      for (final response in [
        http.Response('html', 200, headers: {'content-type': 'text/html'}),
        http.Response.bytes([], 200, headers: {'content-type': 'image/png'}),
        http.Response.bytes(
          Uint8List(5 * 1024 * 1024 + 1),
          200,
          headers: {'content-type': 'image/png'},
        ),
      ]) {
        final service = remote((_) async => response);
        await expectLater(
          service.download(url),
          throwsA(isA<PhotoDeliveryFailed>()),
        );
      }
    },
  );
}
