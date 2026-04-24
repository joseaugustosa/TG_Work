// Smoke test: a app real (TGWorkApp) precisa de Firebase; evitar o template MyApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widget test: MaterialApp minimo', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('tg_work')),
        ),
      ),
    );
    expect(find.text('tg_work'), findsOneWidget);
  });
}
