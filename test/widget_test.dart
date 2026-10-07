import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/app.dart';

void main() {
  testWidgets('App loads and displays HomeScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WildoraApp());

    // Verify that the app displays the AppBar title.
    expect(find.text('Wildora'), findsOneWidget);

    // Verify that the welcome text is displayed.
    expect(find.text('Welcome to Wildora'), findsOneWidget);

    // Verify that the status text is displayed.
    expect(find.text('Initial setup is working ✅'), findsOneWidget);
  });
}
