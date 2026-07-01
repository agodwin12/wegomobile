// The previous default smoke test pumped the full WegoApp, which calls
// Firebase.initializeApp()/FirebaseMessaging at startup and therefore cannot
// run in a bare `flutter test` environment. Replaced with a self-contained
// widget test of the No-Drivers terminal screen (no Firebase/dotenv needed),
// so the suite is green and actually exercises real UI behaviour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wego_v1/screens/passenger/trip/no_drivers_screen.dart';

void main() {
  testWidgets('NoDriversScreen renders and Retry returns true', (tester) async {
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NoDriversScreen(message: 'Test message'),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Terminal state is shown — never an infinite spinner.
    expect(find.text('Aucun chauffeur disponible'), findsOneWidget);
    expect(find.text('Test message'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    // Retry pops with `true`.
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('NoDriversScreen Cancel returns false', (tester) async {
    bool? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const NoDriversScreen()),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, false);
  });
}
