import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/incident_location_map.dart';
import 'package:wildora/src/features/conflict_reporting/presentation/manual_location_dialog.dart';

import 'map_test_tiles.dart';

void main() {
  testWidgets('initial viewport does not invent a selected incident', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentLocationMap(
            tileProvider: MapTestTiles(),
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsNothing);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('GPS pin uses the fetched coordinates and preview cannot drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentLocationMap(
            latitude: 7.291,
            longitude: 80.635,
            tileProvider: MapTestTiles(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, closeTo(7.291, 0.000001));
    expect(
      map.mapController!.camera.center.longitude,
      closeTo(80.635, 0.000001),
    );
    final marker = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .single;
    expect(marker.point, const LatLng(7.291, 80.635));
    await tester.drag(find.byType(FlutterMap), const Offset(100, 50));
    await tester.pumpAndSettle();
    expect(map.mapController!.camera.center, marker.point);
  });

  testWidgets('tap selects actual map coordinates and confirm returns them', (
    tester,
  ) async {
    ManualIncidentLocation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<ManualIncidentLocation>(
                  context: context,
                  builder: (_) => ManualLocationDialog(
                    description: '',
                    tileProvider: MapTestTiles(),
                  ),
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    final center = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera
        .center;
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    final latitude = double.parse(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
    );
    final longitude = double.parse(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
    );
    expect(latitude, closeTo(center.latitude, 0.000001));
    expect(longitude, closeTo(center.longitude, 0.000001));
    expect(find.byType(MarkerLayer), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result!.description, 'Selected incident location');
    expect(result!.latitude, latitude);
    expect(result!.longitude, longitude);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel discards map selection', (tester) async {
    ManualIncidentLocation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<ManualIncidentLocation>(
                  context: context,
                  builder: (_) => ManualLocationDialog(
                    description: '',
                    tileProvider: MapTestTiles(),
                  ),
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('tile errors retain coordinates and retry recovers', (
    tester,
  ) async {
    final tiles = MapTestTiles(fail: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentLocationMap(
            latitude: 7.291,
            longitude: 80.635,
            tileProvider: tiles,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Map unavailable.'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.point,
      const LatLng(7.291, 80.635),
    );
    tiles.fail = false;
    await tester.tap(find.text('Retry map'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Map unavailable.'), findsNothing);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
