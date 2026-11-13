import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montas_organizer/main.dart';
import 'test_helpers.dart' show tapVisible;

void main() {
  testWidgets(
    'Today remains usable on narrow screens and reflects cancellation',
    (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MontasApp(seedDemo: true));
      await t.pumpAndSettle();
      expect(find.byType(OrganizerTodayScreen), findsOneWidget);
      expect(t.takeException(), isNull);
      final store = t
          .widget<OrganizerWorkspace>(find.byType(OrganizerWorkspace))
          .store;
      for (final event in store.events) {
        expect(
          store.cancelEvent(
            event,
            'Демо-отмена',
            store.attendees(event.id).map((r) => r.id).toList(),
          ),
          isTrue,
        );
      }
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-featured-manage')), findsNothing);
      expect(find.text('Ваша следующая встреча'), findsOneWidget);
      await tapVisible(t, find.byKey(const ValueKey('today-empty-create')));
      expect(find.byType(OrganizerEditor), findsOneWidget);
      expect(store.drafts, hasLength(1));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Branded Today opens management and returns through existing navigation',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MontasApp(seedDemo: true));
      await t.pumpAndSettle();
      await tapVisible(t, find.byKey(const ValueKey('today-featured-manage')));
      expect(find.byType(OrganizerEventWorkspace), findsOneWidget);
      expect(find.byType(OrganizerTodayScreen), findsNothing);
      await tapVisible(t, find.byKey(const ValueKey('organizer-nav-0')));
      expect(find.byType(OrganizerTodayScreen), findsOneWidget);
      await tapVisible(t, find.byKey(const ValueKey('organizer-demo-catalog')));
      expect(find.text('События и встречи'), findsOneWidget);
      await tapVisible(
        t,
        find.byKey(const ValueKey('organizer-demo-workspace')),
      );
      expect(find.byType(OrganizerTodayScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
