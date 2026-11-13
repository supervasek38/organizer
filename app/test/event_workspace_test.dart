import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montas_organizer/main.dart';
import 'test_helpers.dart' show tapVisible;

Finder k(String id) => find.byKey(ValueKey(id));
const extra = EventTicket(
  'online-extra',
  'С записью',
  500,
  true,
  'Трансляция и запись',
  capacity: 1,
);
EventDraft complete(String id, {List<EventTicket> tickets = const [extra]}) =>
    EventDraft(
      id: id,
      title: 'Практика восстановления',
      description: 'Описание встречи',
      speakers: 'Анна Волкова',
      program: '19:00 · Практика',
      extraTickets: tickets,
      audience: 'Для начинающих',
      outcomes: 'Практические примеры',
      preparation: 'Возьмите блокнот',
    );

void main() {
  test(
    'Multiple ticket publication preserves individual capacity and attendee snapshot',
    () {
      final store = EventsStore();
      final draft = complete(store.createDraft().id);
      store.saveDraft(draft);
      final event = store.publish(draft)!;
      expect(event.tickets.length, 2);
      final r = store.register(event, event.tickets.last)!;
      expect(store.remaining(event, event.tickets.last), 0);
      expect(store.remaining(event, event.tickets.first), 30);
      expect(
        store.addTicket(
          event,
          const EventTicket('onsite', 'Очно', 100, false, 'Встреча'),
        ),
        isTrue,
      );
      expect(identical(r.event, event), isTrue);
      expect(store.byId(event.id)!.tickets.length, 3);
      expect(store.byId(event.id)!.audience, 'Для начинающих');
      expect(store.addTicket(event, extra), isFalse);
      expect(store.register(event, event.tickets.first), isNull);
      store.cancel(r);
      expect(store.remaining(store.byId(event.id)!, extra), 1);
      store.dispose();
    },
  );
  test(
    'Invalid and duplicate ticket IDs cannot publish; editing draft blocks ticket additions',
    () {
      final store = EventsStore();
      final id = store.createDraft().id;
      final invalid = complete(id, tickets: [extra, extra]);
      store.saveDraft(invalid);
      expect(store.publish(invalid), isNull);
      expect(
        validEventTicket(const EventTicket('x', 'Bad', -1, true, 'Info')),
        isFalse,
      );
      final event = store.byId('analysis')!;
      store.editPublished(event);
      expect(store.addTicket(event, extra), isFalse);
      store.dispose();
    },
  );
  test('Date filters use demo anchor and the nearest weekend', () {
    final event = montasEvents[1]; // Saturday 24 October.
    expect(matchesEventDate(event, 'Выходные', DateTime(2026, 10, 20)), isTrue);
    expect(matchesEventDate(event, 'Сегодня', DateTime(2026, 10, 20)), isFalse);
    expect(matchesEventDate(event, 'Завтра', DateTime(2026, 10, 23)), isTrue);
    expect(matchesEventDate(event, 'Выходные', DateTime(2026, 10, 25)), isTrue);
    expect(
      matchesEventDate(event, 'Выходные', DateTime(2026, 10, 26)),
      isFalse,
    );
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Event workspace, registrations, materials and new format at $width',
      (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(const MontasApp(seedDemo: true));
        await t.pumpAndSettle();
        final store = t
            .widget<OrganizerWorkspace>(find.byType(OrganizerWorkspace))
            .store;
        await tapVisible(t, k('organizer-manage-sleep-lab'));
        expect(find.byType(OrganizerEventWorkspace), findsOneWidget);
        await tapVisible(t, k('event-workspace-tab-3'));
        final r = store.attendees('sleep-lab').first;
        expect(k('event-roster-${r.id}'), findsOneWidget);
        await tapVisible(t, find.widgetWithText(ChoiceChip, 'Отменили'));
        expect(
          find.text('Участников по этим условиям пока нет.'),
          findsOneWidget,
        );
        await tapVisible(t, find.widgetWithText(ChoiceChip, 'Записались'));
        expect(k('event-roster-${r.id}'), findsOneWidget);
        await t.enterText(k('event-roster-search'), 'нет такого участника');
        await t.pumpAndSettle();
        expect(
          find.text('Участников по этим условиям пока нет.'),
          findsOneWidget,
        );
        await tapVisible(t, k('event-workspace-tab-6'));
        expect(find.text('Участие в цифрах'), findsOneWidget);
        t.view.physicalSize = Size(width == 390 ? 1440 : 390, 1000);
        await t.pumpAndSettle();
        expect(find.text('Участие в цифрах'), findsOneWidget);
        t.view.physicalSize = Size(width, 1000);
        await t.pumpAndSettle();
        await tapVisible(t, k('event-workspace-tab-4'));
        expect(k('organizer-upload'), findsOneWidget);
        await tapVisible(t, k('event-workspace-tab-5'));
        expect(find.byType(EventNoticeList), findsOneWidget);
        await tapVisible(t, k('event-workspace-tab-2'));
        await tapVisible(t, k('workspace-add-ticket'));
        await t.enterText(k('ticket-input-name'), 'Дополнительная трансляция');
        await t.enterText(k('ticket-input-capacity'), '8');
        await tapVisible(t, k('ticket-save'));
        expect(store.byId('sleep-lab')!.tickets.length, 4);
        await tapVisible(t, k('event-workspace-tab-1'));
        expect(find.text('Для кого'), findsOneWidget);
        expect(find.text('Открыть как пользователь'), findsOneWidget);
        expect(t.takeException(), isNull);
        await tapVisible(t, k('workspace-event-back'));
        await tapVisible(t, k('organizer-create'));
        await tapVisible(t, k('organizer-editor-tab-2'));
        await tapVisible(t, k('organizer-add-ticket'));
        await tapVisible(t, k('ticket-save'));
        await tapVisible(t, k('organizer-save'));
        expect(store.drafts.single.extraTickets.length, 1);
        expect(t.takeException(), isNull);
      },
    );
  }
}
