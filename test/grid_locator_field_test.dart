import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/widgets/grid_locator_field.dart';

void main() {
  testWidgets('shows precision and normalizes a valid locator on blur', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GridLocatorField(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'gg30ch90nh');
    await tester.pump();
    expect(find.text('precisão de 40 m'), findsOneWidget);

    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pump();
    expect(controller.text, 'GG30CH90NH');
    controller.dispose();
  });

  testWidgets('allows free text when configured', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GridLocatorField(allowInvalid: true)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Santa Maria');
    await tester.pump();
    expect(find.text('Texto livre'), findsOneWidget);
    expect(find.text('Informe um grid Maidenhead válido'), findsNothing);
  });
}
