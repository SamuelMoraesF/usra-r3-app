import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra_r3/widgets/contact_workspace.dart';

void main() {
  testWidgets('form stays below map; only logs occupy right panel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContactWorkspace(
            map: const ColoredBox(key: ValueKey('map'), color: Colors.blue),
            form: const SizedBox(height: 460, child: Text('Formulário')),
            logs: const Text('Registros salvos'),
            formScrollController: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final form = find.byKey(const ValueKey('contact-form-panel'));
    final logs = find.byKey(const ValueKey('contact-logs-panel'));
    final map = find.byKey(const ValueKey('map'));
    expect(
      find.descendant(of: form, matching: find.text('Formulário')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: logs, matching: find.text('Formulário')),
      findsNothing,
    );
    expect(
      find.descendant(of: logs, matching: find.text('Registros salvos')),
      findsOneWidget,
    );
    expect(
      tester.getRect(form).top,
      greaterThanOrEqualTo(tester.getRect(map).bottom),
    );
    expect(tester.getRect(logs).left, greaterThan(tester.getRect(map).right));
    expect(tester.getRect(logs).top, 0);
    expect(find.byKey(const ValueKey('form-resize')), findsNothing);
    // 460 pixels of form plus the panel's 16 pixels of vertical padding.
    expect(tester.getSize(form).height, 476);
    expect(tester.getSize(map).height, greaterThan(0));
    final originalWidth = tester.getSize(logs).width;
    await tester.drag(
      find.byKey(const ValueKey('logs-resize')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(logs).width, greaterThan(originalWidth));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('form limit follows changing content and available height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Future<void> showForm(double height) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactWorkspace(
              map: const ColoredBox(color: Colors.blue),
              form: SizedBox(height: height),
              logs: const Text('Logs'),
              formScrollController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final form = find.byKey(const ValueKey('contact-form-panel'));
    await showForm(600);
    expect(tester.getSize(form).height, 616);
    await showForm(100);
    expect(tester.getSize(form).height, 116);
    tester.view.physicalSize = const Size(1200, 300);
    await tester.pumpAndSettle();
    expect(tester.getSize(form).height, lessThanOrEqualTo(116));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
