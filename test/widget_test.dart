import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototype_flutter/main.dart';

void main() {
  testWidgets('Navigation and modal open/close', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // default tab is Scénario
    expect(find.text('Scénario'), findsOneWidget);
    // open popup media icon -> media not visible by default => snackbar shown
    await tester.tap(find.byIcon(Icons.perm_media));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });
}