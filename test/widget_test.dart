import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/app.dart';

void main() {
  testWidgets('App loads and displays Wildora text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WildoraApp());

    // Verify that the app displays the Wildora text.
    expect(find.text('Wildora'), findsOneWidget);
  });
}
