import 'package:flutter_test/flutter_test.dart';

import 'package:usra_r3/main.dart';

void main() {
  testWidgets('renders the setup wizard', (tester) async {
    await tester.pumpWidget(const UsraR3App());

    expect(find.text('USRA R3'), findsOneWidget);
    expect(find.text('Configure seu perfil'), findsOneWidget);
    expect(find.text('Usar GPS'), findsOneWidget);
  });
}
