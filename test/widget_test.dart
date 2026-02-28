import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wego_v1/main.dart';

void main() {
  testWidgets('Wego app builds smoke test', (WidgetTester tester) async {
    // Build the real app
    await tester.pumpWidget(const WegoApp());

    // Basic sanity check
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
