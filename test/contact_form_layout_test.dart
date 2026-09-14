import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/widgets/contact_form_layout.dart';

void main() {
  testWidgets('four columns align fields and put actions at opposite ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactFormLayout(
            fourColumns: true,
            fields: [
              for (var i = 0; i < 8; i++)
                TextFormField(key: ValueKey('field-$i')),
            ],
            message: const SizedBox(key: ValueKey('message'), height: 60),
            closeButton: OutlinedButton(
              onPressed: () {},
              child: const Text('Fechar rede'),
            ),
            submitButton: FilledButton(
              onPressed: () {},
              child: const Text('Adicionar log'),
            ),
          ),
        ),
      ),
    );
    Rect field(int i) => tester.getRect(find.byKey(ValueKey('field-$i')));
    for (var i = 0; i < 4; i++) {
      expect(field(i).top, field(0).top);
      expect(field(i + 4).top, field(4).top);
      expect(field(i).left, field(i + 4).left);
      expect(field(i).width, field(0).width);
      if (i > 0) expect(field(i).left, greaterThan(field(i - 1).right));
    }
    final close = tester.getRect(find.byType(OutlinedButton));
    final submit = tester.getRect(find.byType(FilledButton));
    expect(close.left, field(0).left);
    expect(close.width, field(0).width);
    expect(submit.left, field(3).left);
    expect(submit.width, field(3).width);
    expect(close.top, submit.top);
    final message = tester.getRect(find.byKey(const ValueKey('message')));
    expect(message.top, greaterThan(field(4).bottom));
    expect(message.left, field(0).left);
    expect(message.right, field(3).right);
    expect(close.top, greaterThan(message.bottom));
    expect(tester.takeException(), isNull);
  });
}
