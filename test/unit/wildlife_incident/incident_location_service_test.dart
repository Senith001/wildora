import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wildora/src/features/wildlife-incident/data/incident_location_service.dart';

void main() {
  final position = Position(
    latitude: 6.86,
    longitude: 79.86,
    timestamp: DateTime.utc(2020),
    accuracy: 12,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  test(
    'DIP: injected position reader provides the actual device result',
    () async {
      final service = IncidentLocationService(
        web: true,
        secureContext: true,
        positionReader: (settings) async {
          expect(settings.accuracy, LocationAccuracy.high);
          return position;
        },
      );
      expect(await service.capture(), same(position));
    },
  );
  test(
    'insecure browser context rejects capture before reading position',
    () async {
      var reads = 0;
      final service = IncidentLocationService(
        web: true,
        secureContext: false,
        positionReader: (_) async {
          reads++;
          return position;
        },
      );
      await expectLater(service.capture(), throwsStateError);
      expect(reads, 0);
    },
  );
  test(
    'OCP: a reader with timeout behavior can be injected without service changes',
    () async {
      final accuracies = <LocationAccuracy>[];
      final service = IncidentLocationService(
        web: true,
        secureContext: true,
        positionReader: (settings) async {
          accuracies.add(settings.accuracy);
          if (accuracies.length == 1) throw TimeoutException('no GPS fix');
          return position;
        },
      );
      expect(await service.capture(), same(position));
      expect(accuracies, [LocationAccuracy.high, LocationAccuracy.medium]);
    },
  );
  test('permission denial is propagated without an accuracy retry', () async {
    var reads = 0;
    final service = IncidentLocationService(
      web: true,
      secureContext: true,
      positionReader: (_) async {
        reads++;
        throw const PermissionDeniedException('blocked');
      },
    );
    await expectLater(
      service.capture(),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect(reads, 1);
  });
}
