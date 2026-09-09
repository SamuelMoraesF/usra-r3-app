import 'package:flutter_test/flutter_test.dart';

import 'package:usra_r3/main.dart';

void main() {
  testWidgets('renders the USRA R3 dashboard', (tester) async {
    await tester.pumpWidget(const UsraR3App());

    expect(find.text('USRA R3'), findsOneWidget);
    expect(find.text('Resumo da operação'), findsOneWidget);
    expect(find.text('Modo offline pronto'), findsOneWidget);
  });
}
