import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/theme/app_theme.dart';
import 'package:wildora/src/data/models/alert.dart';
import 'package:wildora/src/features/high_risk_movement/presentation/widgets/alert_list_tile.dart';

void main() {
  group('AlertListTile riskLevel badge mapping', () {
    /// Build an unclaimed alert with the given optional riskLevel snapshot.
    Alert buildUnclaimedAlert({String? riskLevel}) {
      return Alert(
        alertId: 'alert-001',
        type: 'high_risk_movement',
        timestamp: Timestamp.now(),
        status: 'active',
        responseStatus: 'unclaimed',
        animalId: 'elephant-23-id',
        zoneId: 'zone-001',
        location: const AlertLocation(latitude: -1.2921, longitude: 36.8219),
        animalName: 'Elephant-23',
        locationLabel: 'Farmland Border',
        riskLevel: riskLevel,
      );
    }

    // MaterialApp with AppTheme.light() so the AlertColors extension resolves.
    Future<void> pumpTile(WidgetTester tester, Alert alert) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AlertListTile(alert: alert)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('High riskLevel renders HIGH badge', (tester) async {
      await pumpTile(tester, buildUnclaimedAlert(riskLevel: 'High'));

      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('Medium riskLevel renders MEDIUM badge', (tester) async {
      await pumpTile(tester, buildUnclaimedAlert(riskLevel: 'Medium'));

      expect(find.text('MEDIUM'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('Low riskLevel renders LOW badge', (tester) async {
      await pumpTile(tester, buildUnclaimedAlert(riskLevel: 'Low'));

      expect(find.text('LOW'), findsOneWidget);
      expect(find.text('URGENT'), findsNothing);
    });

    testWidgets('null riskLevel falls back to URGENT badge (legacy)', (
      tester,
    ) async {
      await pumpTile(tester, buildUnclaimedAlert(riskLevel: null));

      expect(find.text('URGENT'), findsOneWidget);
      expect(find.text('HIGH'), findsNothing);
      expect(find.text('MEDIUM'), findsNothing);
      expect(find.text('LOW'), findsNothing);
    });
  });
}
