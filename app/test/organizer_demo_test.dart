import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montas_organizer/main.dart';
import 'test_helpers.dart' show tapVisible;
import 'test_helpers.dart' show ready;

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Standalone catalog shares publications and registrations at $width',
      (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(const MontasApp(seedDemo: true));
        await t.pumpAndSettle();
        Finder key(String id) => find.byKey(ValueKey(id));
        final store = t
            .widget<OrganizerWorkspace>(find.byType(OrganizerWorkspace))
            .store;
        final draft = ready(
          store.createDraft().id,
          title: 'Встреча из кабинета',
        );
        store.saveDraft(draft);
        final event = store.publish(draft)!;
        await t.pumpAndSettle();
        await tapVisible(t, key('organizer-demo-catalog'));
        expect(find.text('События и встречи'), findsOneWidget);
        await tapVisible(t, key('event-open-${event.id}'));
        await tapVisible(t, key('event-register'));
        await tapVisible(t, key('event-continue'));
        await tapVisible(t, key('event-consent'));
        await tapVisible(t, key('event-confirm'));
        final registration = store.active(event.id)!;
        expect(find.text('Вы записаны · демо'), findsOneWidget);
        await tapVisible(t, key('organizer-demo-workspace'));
        await tapVisible(t, key('organizer-participants-${event.id}'));
        expect(
          key('organizer-registration-${registration.id}'),
          findsOneWidget,
        );
        await tapVisible(t, key('organizer-demo-catalog'));
        expect(find.text('События и встречи'), findsOneWidget);
        await tapVisible(t, key('event-open-${event.id}'));
        await tapVisible(t, key('event-cancel'));
        await tapVisible(t, key('event-cancel-confirm'));
        await tapVisible(t, key('organizer-demo-workspace'));
        expect(registration.cancelled, isTrue);
        expect(find.text('Отменена'), findsOneWidget);
        await tapVisible(
          t,
          key(width < 1050 ? 'organizer-nav-tab-0' : 'organizer-nav-0'),
        );
        await tapVisible(t, key('organizer-public-${event.id}'));
        expect(find.text(event.title), findsOneWidget);
        expect(key('event-register'), findsOneWidget);
        await tapVisible(t, key('event-back'));
        expect(find.text('События и встречи'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
    testWidgets('Standalone organizer stays isolated at $width', (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MontasApp(seedDemo: true));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('workspace-switcher')), findsNothing);
      expect(find.text('Сегодня организатора'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('organizer-demo-catalog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('organizer-public-sleep-lab')),
        findsOneWidget,
      );

      final workspace = t.widget<OrganizerWorkspace>(
        find.byType(OrganizerWorkspace),
      );
      final store = workspace.store;
      expect(store.attendees('sleep-lab'), hasLength(3));
      await tapVisible(
        t,
        find.byKey(const ValueKey('organizer-participants-sleep-lab')),
      );
      expect(t.takeException(), isNull);

      final event = store.byId('sleep-lab')!;
      final recipients = store.attendees(event.id).map((r) => r.id).toList();
      expect(store.cancelEvent(event, 'Перенос площадки', recipients), isTrue);
      await tapVisible(
        t,
        find.byKey(
          ValueKey(width < 1050 ? 'organizer-nav-tab-4' : 'organizer-nav-4'),
        ),
      );
      expect(find.byType(EventNoticeList), findsOneWidget);
      expect(find.text('Открыть мероприятие'), findsWidgets);
      expect(store.notices, hasLength(3));

      await tapVisible(
        t,
        find.byKey(
          ValueKey(width < 1050 ? 'organizer-nav-tab-0' : 'organizer-nav-0'),
        ),
      );
      await tapVisible(t, find.byKey(const ValueKey('organizer-create')));
      expect(find.byType(OrganizerEditor), findsOneWidget);
      expect(store.drafts, hasLength(1));
      expect(t.takeException(), isNull);
    });
  }
}
