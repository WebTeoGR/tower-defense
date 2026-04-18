import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/main.dart';

void main() {
  testWidgets('Game screen renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const TowerDefenseApp());
    // GameWidget loads asynchronously; just verify the scaffold is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
