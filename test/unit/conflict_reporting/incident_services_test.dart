import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wildora/src/features/conflict_reporting/application/incident_location_service.dart';
import 'package:wildora/src/features/conflict_reporting/application/incident_photo_service.dart';

class FakeLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  bool timeout = false;
  int requests = 0;
  int fixes = 0;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    fixes++;
    settings = locationSettings;
    if (timeout) throw TimeoutException('No satellite fix');
    return Position(
      latitude: 7.291,
      longitude: 80.635,
      timestamp: DateTime.utc(2026, 10, 9),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class FakeImagePicker extends ImagePicker {
  XFile? result;
  ImageSource? source;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    return result;
  }
}

void main() {
  test(
    'GPS result includes source coordinates and accuracy with a time limit',
    () async {
      final platform = FakeLocationPlatform();
      final result = await DeviceIncidentLocationService(platform: platform)
          .currentLocation();
      expect(result.latitude, 7.291);
      expect(result.longitude, 80.635);
      expect(result.accuracy, 12);
      expect(platform.settings!.timeLimit, const Duration(seconds: 15));
      expect(platform.requests, 0);
    },
  );
  test('requests permission only when initially denied', () async {
    final platform = FakeLocationPlatform()
      ..permission = LocationPermission.denied;
    await DeviceIncidentLocationService(platform: platform).currentLocation();
    expect(platform.requests, 1);
    expect(platform.fixes, 1);
  });
  test(
    'disabled services return recovery guidance without a fake GPS fix',
    () async {
      final platform = FakeLocationPlatform()..enabled = false;
      await expectLater(
        DeviceIncidentLocationService(platform: platform).currentLocation(),
        throwsA(
          isA<LocationUnavailable>().having(
            (e) => e.message,
            'message',
            contains('Enable'),
          ),
        ),
      );
      expect(platform.fixes, 0);
    },
  );
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test(
      'unavailable permission $permission cannot fetch coordinates',
      () async {
        final platform = FakeLocationPlatform()
          ..permission = permission
          ..requested = permission;
        await expectLater(
          DeviceIncidentLocationService(platform: platform).currentLocation(),
          throwsA(isA<LocationUnavailable>()),
        );
        expect(platform.fixes, 0);
        if (permission == LocationPermission.deniedForever) {
          expect(platform.requests, 0);
        }
      },
    );
  }
  test('GPS timeout gives recoverable guidance', () async {
    final platform = FakeLocationPlatform()..timeout = true;
    await expectLater(
      DeviceIncidentLocationService(platform: platform).currentLocation(),
      throwsA(
        isA<LocationUnavailable>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
  test('picker cancellation leaves the optional attachment absent', () async {
    expect(
      await DeviceIncidentPhotoService(picker: FakeImagePicker())
          .select(ImageSource.gallery),
      isNull,
    );
  });
  test(
    'select returns actual JPEG bytes and forwards the selected source',
    () async {
      final bytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
      final picker = FakeImagePicker()
        ..result = XFile.fromData(bytes, name: 'capture.jpg');
      final photo = await DeviceIncidentPhotoService(picker: picker)
          .select(ImageSource.camera);
      expect(photo!.contentType, 'image/jpeg');
      expect(photo.bytes, bytes);
      expect(picker.source, ImageSource.camera);
    },
  );
  test('detects PNG and WebP using their bytes rather than extensions', () {
    expect(
      DeviceIncidentPhotoService.validate(
        'wrong.txt',
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10]),
      ).contentType,
      'image/png',
    );
    expect(
      DeviceIncidentPhotoService.validate(
        'wrong.txt',
        Uint8List.fromList('RIFFxxxxWEBP'.codeUnits),
      ).contentType,
      'image/webp',
    );
  });
  test('rejects empty, oversized and unsupported attachments', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List(5 * 1024 * 1024 + 1),
      Uint8List.fromList('not a photo'.codeUnits),
    ]) {
      expect(
        () => DeviceIncidentPhotoService.validate('test.jpg', bytes),
        throwsFormatException,
      );
    }
  });
}
