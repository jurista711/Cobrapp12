import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cobrapp_supabase/main.dart';

void main() {
  testWidgets('StatCard renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(label: 'Clientes', value: '0', icon: Icons.people),
        ),
      ),
    );

    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
