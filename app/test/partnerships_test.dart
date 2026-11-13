import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montas_organizer/main.dart';
import 'test_helpers.dart';

Finder key(String id) => find.byKey(ValueKey(id));
const valid = PartnerBrief(
  categories: 'Wellness',
  audience: 'Взрослые гости встречи',
  guests: '80',
  deadline: '22.10.2026',
  contact: 'Тестовый организатор',
  email: 'demo@example.com',
  packageName: 'Партнёр встречи',
  includes: 'Логотип и представление бренда',
  price: '50000',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Onest',
    )..addFont(rootBundle.load('assets/Onest.ttf'))).load();
  });
  late EventsStore store;
  setUp(() {
    store = EventsStore();
  });
  tearDown(() {
    store.dispose();
  });
  PartnerRequest submitted() {
    final r = store.createPartnerRequest(store.events.first)!;
    store.savePartnerBrief(r, r.version, valid);
    expect(store.submitPartnerRequest(r, r.version), isTrue);
    return r;
  }

  PartnerRequest offered() {
    final r = submitted();
    store.receivePartnerOffers(r, r.version);
    return r;
  }

  test(
    'One request per event; incomplete, foreign and stale submissions rejected',
    () {
      final event = store.events.first;
      final r = store.createPartnerRequest(event)!;
      expect(store.createPartnerRequest(event), same(r));
      expect(store.submitPartnerRequest(r, r.version), isFalse);
      final oldVersion = r.version;
      expect(store.savePartnerBrief(r, oldVersion, valid), isTrue);
      expect(store.submitPartnerRequest(r, oldVersion), isFalse);
      expect(
        store.submitPartnerRequest(PartnerRequest('foreign', event, valid), 1),
        isFalse,
      );
      expect(store.submitPartnerRequest(r, r.version), isTrue);
      expect(store.submitPartnerRequest(r, r.version), isFalse);
      expect(store.savePartnerBrief(r, r.version, valid), isFalse);
      expect(store.partnerNotices, hasLength(1));
      expect(r.offers, isEmpty);
    },
  );
  test('Invalid dates, contact, amount and audience cannot be submitted', () {
    final r = store.createPartnerRequest(store.events.first)!;
    store.savePartnerBrief(
      r,
      r.version,
      const PartnerBrief(
        categories: 'Wellness',
        need: 'unknown',
        guests: '0',
        audience: '',
        deadline: '31.02.2026',
        contact: '',
        email: 'wrong',
        price: '-1',
      ),
    );
    expect(r.brief.errors(r.event).length, greaterThanOrEqualTo(8));
    expect(store.submitPartnerRequest(r, r.version), isFalse);
  });
  test(
    'Clarification blocks agreement until reply; one accepted brand closes remaining offers',
    () {
      final r = offered();
      final a = r.offers.first, b = r.offers.last;
      expect(store.receivePartnerOffers(r, r.version), isFalse);
      expect(r.offers, hasLength(2));
      expect(store.clarifyPartnerOffer(r, a, r.version, ''), isFalse);
      store.clarifyPartnerOffer(r, a, r.version, 'Уточните состав материалов.');
      expect(store.decidePartnerOffer(r, a, r.version, accept: true), isFalse);
      store.replyToPartnerClarification(r, a, r.version);
      final reviewed = r.version;
      store.clarifyPartnerOffer(r, b, r.version, 'Нужны макеты.');
      expect(store.decidePartnerOffer(r, a, reviewed, accept: true), isFalse);
      expect(store.decidePartnerOffer(r, a, r.version, accept: true), isTrue);
      expect(a.status, PartnerOfferStatus.accepted);
      expect(b.status, PartnerOfferStatus.closed);
      expect(store.decidePartnerOffer(r, b, r.version, accept: true), isFalse);
      expect(r.stage, PartnerStage.agreed);
      expect(store.partnerUnread, greaterThan(0));
    },
  );
  test(
    'Decline requires a reason; withdrawing retains history and permits a new request',
    () {
      final r = offered();
      final offer = r.offers.first;
      expect(
        store.decidePartnerOffer(r, offer, r.version, accept: false),
        isFalse,
      );
      store.decidePartnerOffer(
        r,
        offer,
        r.version,
        accept: false,
        reason: 'Не подходит формат',
      );
      expect(offer.status, PartnerOfferStatus.declined);
      expect(store.withdrawPartnerRequest(r, r.version), isTrue);
      expect(store.receivePartnerOffers(r, r.version), isFalse);
      final next = store.createPartnerRequest(r.event)!;
      expect(next, isNot(same(r)));
      expect(store.partnerRequests, hasLength(2));
      expect(r.history.any((s) => s.contains('Не подходит формат')), isTrue);
    },
  );
  test(
    'Changed event invalidates decisions and requires confirmed fresh selection',
    () {
      final r = offered();
      final offer = r.offers.first;
      final old = r.event;
      store.addTicket(
        old,
        const EventTicket('new', 'Онлайн', 0, true, 'Трансляция'),
      );
      expect(store.partnerEventChanged(r), isTrue);
      expect(
        store.decidePartnerOffer(r, offer, r.version, accept: true),
        isFalse,
      );
      expect(store.refreshPartnerEvent(r, r.version), isTrue);
      expect(r.event, same(store.byId(old.id)));
      expect(offer.status, PartnerOfferStatus.closed);
      expect(r.stage, PartnerStage.submitted);
      expect(store.receivePartnerOffers(r, r.version), isTrue);
      expect(
        r.offers.where((o) => o.status == PartnerOfferStatus.pending),
        hasLength(2),
      );
    },
  );
  test(
    'Cancelling an event closes requests and agreements without deleting history',
    () {
      final r = offered();
      store.decidePartnerOffer(r, r.offers.first, r.version, accept: true);
      expect(store.cancelEvent(r.event, 'Событие отменено', []), isTrue);
      expect(r.stage, PartnerStage.cancelled);
      expect(
        r.offers.every((o) => o.status == PartnerOfferStatus.closed),
        isTrue,
      );
      expect(store.createPartnerRequest(r.event), isNull);
      expect(
        store.decidePartnerOffer(r, r.offers.first, r.version, accept: true),
        isFalse,
      );
      expect(r.history.any((s) => s.contains('Согласован')), isTrue);
      final notice = store.partnerNotices.first;
      store.readPartnerNotice(notice);
      expect(notice.read, isTrue);
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Organizer partnership request, offer clarification and agreement at $width',
      (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(const MontasApp(seedDemo: true));
        await t.pumpAndSettle();
        await tapVisible(t, key('organizer-partners-sleep-lab'));
        await tapVisible(t, key('partners-create'));
        await tapVisible(t, key('partner-fill-demo'));
        await tapVisible(t, key('partner-save-brief'));
        await tapVisible(t, key('partner-submit'));
        expect(find.text('Передать запрос MONTAS?'), findsOneWidget);
        await tapVisible(t, key('partner-confirm'));
        await tapVisible(t, key('partner-demo-offers'));
        final events = t
            .widget<OrganizerWorkspace>(find.byType(OrganizerWorkspace))
            .store;
        final request = events.partnerRequests.single;
        expect(request.offers, hasLength(2));
        await tapVisible(t, key('partner-clarify-offer-1'));
        await t.enterText(
          key('partner-message'),
          'Уточните требования к материалам.',
        );
        await tapVisible(t, key('partner-message-save'));
        await tapVisible(t, key('partner-demo-reply-offer-1'));
        await tapVisible(t, key('partner-accept-offer-1'));
        await tapVisible(t, key('partner-confirm'));
        expect(request.stage, PartnerStage.agreed);
        expect(find.text('Партнёрство согласовано'), findsOneWidget);
        expect(key('partner-accept-offer-2'), findsNothing);
        await tapVisible(
          t,
          key(width < 1050 ? 'organizer-nav-tab-4' : 'organizer-nav-4'),
        );
        expect(find.text('Партнёр согласован'), findsOneWidget);
        await tapVisible(t, key('organizer-demo-catalog'));
        expect(find.text('События и встречи'), findsOneWidget);
        expect(find.text('VitaLab · демо'), findsNothing);
        await tapVisible(t, key('organizer-demo-workspace'));
        await tapVisible(
          t,
          key(width < 1050 ? 'organizer-nav-tab-5' : 'organizer-nav-5'),
        );
        await tapVisible(t, key('partner-open-${request.id}'));
        expect(find.text('Партнёрство согласовано'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Event workspace has a partnership tab and preserves request after navigation',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MontasApp(seedDemo: true));
      await t.pumpAndSettle();
      await tapVisible(t, key('organizer-manage-sleep-lab'));
      await tapVisible(t, key('workspace-partners'));
      await tapVisible(t, key('partners-create'));
      await tapVisible(t, key('partner-fill-demo'));
      await tapVisible(t, key('partner-save-brief'));
      await tapVisible(t, key('event-workspace-tab-0'));
      await tapVisible(t, key('event-workspace-tab-7'));
      expect(key('partner-submit'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
