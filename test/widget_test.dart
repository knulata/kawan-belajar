import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kawabel/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const KawabelApp());
    expect(find.text('kawabel'), findsOneWidget);
  });
}
