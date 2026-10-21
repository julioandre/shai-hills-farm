import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/app/app_backend.dart';
import 'package:shai_hills_farm/app/farm_app.dart';
import 'package:shai_hills_farm/data/memory_store.dart';

void main() {
  testWidgets('a worker records a birth from the Today page', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FarmApp(backend: AppBackend.local(MemoryStore())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.enterText(find.byKey(const Key('phone-field')), '0244120008');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-field')), '123456');
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-birth')));
    await tester.pumpAndSettle();
    expect(find.text('Register animal'), findsWidgets);
    await tester.enterText(find.byKey(const Key('tag-field')), 'PIG-NEW');
    await tester.tap(find.byKey(const Key('species-pig')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('sex-female')));
    await tester.pump();
    final form = find
        .descendant(
          of: find.byKey(const Key('animal-form')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('breed-Large White')),
      300,
      scrollable: form,
    );
    await tester.tap(find.byKey(const Key('breed-Large White')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('origin-purchased')),
      300,
      scrollable: form,
    );
    await tester.tap(find.byKey(const Key('origin-purchased')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('source-farm')),
      300,
      scrollable: form,
    );
    await tester.enterText(find.byKey(const Key('source-farm')), 'Market');
    await tester.enterText(find.byKey(const Key('supplier-name')), 'Market');
    await tester.enterText(find.byKey(const Key('purchase-weight')), '12');
    await tester.enterText(find.byKey(const Key('purchase-price')), '200');
    await tester.enterText(find.byKey(const Key('transport-cost')), '0');
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-animal')),
      400,
      scrollable: form,
    );
    await tester.tap(find.byKey(const Key('save-animal')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('form-error')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('PIG-NEW'),
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('registry-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PIG-NEW'), findsWidgets);
  });

  testWidgets('Record keeps animal jobs and leaves feed and money alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FarmApp(backend: AppBackend.local(MemoryStore())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.enterText(find.byKey(const Key('phone-field')), '0244120008');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-field')), '123456');
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('record-birth')), findsOneWidget);
    expect(find.byKey(const Key('record-death')), findsOneWidget);
    expect(find.byKey(const Key('record-service')), findsNothing);
    expect(find.byKey(const Key('record-weight')), findsOneWidget);
    expect(find.byKey(const Key('record-vaccine')), findsOneWidget);
    expect(find.byKey(const Key('record-sickness')), findsOneWidget);
    expect(find.byKey(const Key('record-feed')), findsNothing);
    expect(find.byKey(const Key('record-purchase')), findsNothing);
    expect(find.byKey(const Key('record-sale')), findsNothing);
    expect(find.byKey(const Key('record-expense')), findsNothing);
  });
}
