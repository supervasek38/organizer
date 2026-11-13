part of 'main.dart';

enum PartnerStage { draft, submitted, offers, agreed, withdrawn, cancelled }

enum PartnerOfferStatus { pending, clarification, accepted, declined, closed }

const partnerNeeds = [
  'Подарки участникам',
  'Бренд-зона',
  'Спикер',
  'Финансовое партнёрство',
];

class PartnerBrief {
  const PartnerBrief({
    this.categories = '',
    this.need = 'Подарки участникам',
    this.audience = '',
    this.guests = '',
    this.deadline = '',
    this.contact = '',
    this.email = '',
    this.packageName = '',
    this.includes = '',
    this.price = '',
    this.restrictions = '',
  });
  final String categories, need, audience, guests, deadline, contact, email;
  final String packageName, includes, price, restrictions;
  DateTime? get due {
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(deadline);
    if (match == null) return null;
    final d = int.parse(match[1]!),
        m = int.parse(match[2]!),
        y = int.parse(match[3]!);
    final value = DateTime(y, m, d);
    return value.day == d && value.month == m && value.year == y ? value : null;
  }

  List<String> errors(MontasEvent event) {
    final date = event.startsAt ?? DateTime(2026, 10, event.day);
    final people = int.tryParse(guests), amount = int.tryParse(price);
    return [
      if (categories.trim().isEmpty || categories.length > 200)
        'Укажите категории брендов: до 200 символов.',
      if (!partnerNeeds.contains(need)) 'Выберите формат партнёрства.',
      if (audience.trim().isEmpty || audience.length > 1000)
        'Опишите аудиторию: до 1000 символов.',
      if (people == null || people < 1 || people > 100000)
        'Ожидаемое число гостей: от 1 до 100 000.',
      if (due == null ||
          due!.isBefore(DateTime(2026, 10, 20)) ||
          due!.isAfter(date))
        'Срок подбора: от 20.10.2026 до даты мероприятия.',
      if (contact.trim().isEmpty || contact.length > 120)
        'Укажите контактное лицо: до 120 символов.',
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
          email.length > 200)
        'Проверьте email для связи.',
      if (packageName.trim().isEmpty || packageName.length > 100)
        'Укажите название пакета: до 100 символов.',
      if (includes.trim().isEmpty || includes.length > 1500)
        'Опишите, что получает партнёр: до 1500 символов.',
      if (amount == null || amount < 0 || amount > 10000000)
        'Стоимость пакета: целое число от 0 до 10 000 000 ₽; 0 — без денежного взноса.',
      if (restrictions.length > 1000) 'Ограничения: до 1000 символов.',
    ];
  }
}

class PartnerOffer {
  PartnerOffer(
    this.id,
    this.brand,
    this.category,
    this.reason,
    this.contribution,
    this.terms,
  );
  final String id, brand, category, reason, contribution;
  String terms;
  PartnerOfferStatus status = PartnerOfferStatus.pending;
  String get statusLabel => switch (status) {
    PartnerOfferStatus.pending => 'На рассмотрении',
    PartnerOfferStatus.clarification => 'Ждём уточнение',
    PartnerOfferStatus.accepted => 'Согласовано',
    PartnerOfferStatus.declined => 'Отклонено',
    PartnerOfferStatus.closed => 'Закрыто',
  };
}

class PartnerRequest {
  PartnerRequest(this.id, this.event, this.brief);
  final String id;
  MontasEvent event;
  PartnerBrief brief;
  PartnerStage stage = PartnerStage.draft;
  int version = 1;
  final offers = <PartnerOffer>[];
  final history = <String>['Создан черновик запроса'];
  String get label => switch (stage) {
    PartnerStage.draft => 'Черновик',
    PartnerStage.submitted => 'На подборе',
    PartnerStage.offers => 'Предложения получены',
    PartnerStage.agreed => 'Партнёр согласован',
    PartnerStage.withdrawn => 'Запрос отозван',
    PartnerStage.cancelled => 'Событие отменено',
  };
  bool get terminal =>
      [PartnerStage.withdrawn, PartnerStage.cancelled].contains(stage);
}

class PartnerNotice {
  PartnerNotice(this.request, this.title, this.body);
  final PartnerRequest request;
  final String title, body;
  bool read = false;
}

extension PartnershipOperations on EventsStore {
  List<PartnerRequest> get partnerRequests =>
      List.unmodifiable(_partnerRequests);
  List<PartnerNotice> get partnerNotices =>
      List.unmodifiable(_partnerNotices.reversed);
  int get partnerUnread => _partnerNotices.where((n) => !n.read).length;
  bool partnerEventChanged(PartnerRequest r) => byId(r.event.id) != r.event;
  bool partnerAvailable(PartnerRequest r) =>
      _partnerRequests.contains(r) && !isCancelled(r.event.id) && !r.terminal;
  PartnerRequest? partnerFor(String eventId) => _partnerRequests
      .where((r) => r.event.id == eventId && !r.terminal)
      .firstOrNull;
  PartnerRequest? createPartnerRequest(MontasEvent event) {
    if (byId(event.id) != event || isCancelled(event.id)) return null;
    final existing = partnerFor(event.id);
    if (existing != null) return existing;
    final date = event.startsAt ?? DateTime(2026, 10, event.day);
    final deadline = date.subtract(const Duration(days: 1));
    final safe = deadline.isBefore(DateTime(2026, 10, 20))
        ? DateTime(2026, 10, 20)
        : deadline;
    final r = PartnerRequest(
      'PR-${1001 + _partnerRequests.length}',
      event,
      PartnerBrief(
        audience: event.audience,
        deadline:
            '${safe.day.toString().padLeft(2, '0')}.${safe.month.toString().padLeft(2, '0')}.${safe.year}',
      ),
    );
    _partnerRequests.insert(0, r);
    _emit();
    return r;
  }

  bool _partnerCan(PartnerRequest r, int version, List<PartnerStage> stages) =>
      partnerAvailable(r) && r.version == version && stages.contains(r.stage);
  void _partnerRecord(PartnerRequest r, String text, {String? notice}) {
    r.version++;
    r.history.add(text);
    if (notice != null) _partnerNotices.add(PartnerNotice(r, notice, text));
    _emit();
  }

  bool savePartnerBrief(PartnerRequest r, int version, PartnerBrief brief) {
    if (!_partnerCan(r, version, [PartnerStage.draft])) return false;
    r.brief = brief;
    _partnerRecord(r, 'Черновик запроса сохранён');
    return true;
  }

  bool submitPartnerRequest(PartnerRequest r, int version) {
    if (!_partnerCan(r, version, [PartnerStage.draft]) ||
        partnerEventChanged(r) ||
        r.brief.errors(r.event).isNotEmpty) {
      return false;
    }
    r.stage = PartnerStage.submitted;
    _partnerRecord(
      r,
      'Запрос ${r.id} передан на подбор · демо. Пакет «${r.brief.packageName}», ${discoveryMoney(int.parse(r.brief.price))}.',
      notice: 'Запрос принят',
    );
    return true;
  }

  bool receivePartnerOffers(PartnerRequest r, int version) {
    if (!_partnerCan(r, version, [PartnerStage.submitted]) ||
        partnerEventChanged(r)) {
      return false;
    }
    final price = int.parse(r.brief.price) == 0
        ? 'Без денежного взноса'
        : 'Взнос ${discoveryMoney(int.parse(r.brief.price))}';
    final number = r.offers.length;
    r.offers.addAll([
      PartnerOffer(
        'offer-${number + 1}',
        'VitaLab · демо',
        r.brief.categories,
        'Вариант для формата «${r.brief.need}» и аудитории вашего события.',
        '$price. Представитель бренда и материалы для согласованного формата.',
        'Бренд принимает состав пакета «${r.brief.packageName}». Макеты и количество материалов согласуются до мероприятия.',
      ),
      PartnerOffer(
        'offer-${number + 2}',
        'MoveWell · демо',
        r.brief.categories,
        'Альтернативный вариант участия в том же пакете; нужно уточнить состав материалов.',
        '$price. Команда бренда готова обсудить участие.',
        'Предлагается пакет «${r.brief.packageName}» с предварительным согласованием формата. Попросите уточнение при необходимости.',
      ),
    ]);
    r.stage = PartnerStage.offers;
    _partnerRecord(
      r,
      'Демо-ответ MONTAS: получены два тестовых предложения. Автоматический AI-подбор не выполнялся.',
      notice: 'Есть предложения партнёров',
    );
    return true;
  }

  bool _offerCan(PartnerRequest r, PartnerOffer o, int version) =>
      _partnerCan(r, version, [PartnerStage.offers]) &&
      !partnerEventChanged(r) &&
      r.offers.contains(o);
  bool clarifyPartnerOffer(
    PartnerRequest r,
    PartnerOffer o,
    int version,
    String question,
  ) {
    if (!_offerCan(r, o, version) ||
        o.status != PartnerOfferStatus.pending ||
        question.trim().isEmpty ||
        question.length > 1000) {
      return false;
    }
    o.status = PartnerOfferStatus.clarification;
    _partnerRecord(
      r,
      'Уточнение для ${o.brand}: ${question.trim()}',
      notice: 'Уточнение передано менеджеру · демо',
    );
    return true;
  }

  bool replyToPartnerClarification(
    PartnerRequest r,
    PartnerOffer o,
    int version,
  ) {
    if (!_offerCan(r, o, version) ||
        o.status != PartnerOfferStatus.clarification) {
      return false;
    }
    o.status = PartnerOfferStatus.pending;
    o.terms +=
        '\nДемо-ответ менеджера: состав пакета подтверждён без изменений; детали размещения согласуем отдельно.';
    _partnerRecord(
      r,
      '${o.brand}: получен тестовый ответ менеджера. ${o.terms}',
      notice: 'Получено уточнение',
    );
    return true;
  }

  bool decidePartnerOffer(
    PartnerRequest r,
    PartnerOffer o,
    int version, {
    required bool accept,
    String reason = '',
  }) {
    if (!_offerCan(r, o, version) ||
        o.status != PartnerOfferStatus.pending ||
        (!accept && (reason.trim().isEmpty || reason.length > 1000))) {
      return false;
    }
    if (accept) {
      if (r.offers.any((x) => x.status == PartnerOfferStatus.accepted)) {
        return false;
      }
      o.status = PartnerOfferStatus.accepted;
      for (final other in r.offers.where(
        (x) =>
            x != o &&
            [
              PartnerOfferStatus.pending,
              PartnerOfferStatus.clarification,
            ].contains(x.status),
      )) {
        other.status = PartnerOfferStatus.closed;
      }
      r.stage = PartnerStage.agreed;
      _partnerRecord(
        r,
        'Согласован ${o.brand} для пакета «${r.brief.packageName}». Единственное место занято, другие открытые предложения закрыты. Это демо-согласование, без договора и оплаты.',
        notice: 'Партнёр согласован',
      );
    } else {
      o.status = PartnerOfferStatus.declined;
      _partnerRecord(
        r,
        '${o.brand} отклонён: ${reason.trim()}',
        notice: 'Решение по предложению сохранено',
      );
    }
    return true;
  }

  bool refreshPartnerEvent(PartnerRequest r, int version) {
    if (!partnerAvailable(r) ||
        r.version != version ||
        !partnerEventChanged(r) ||
        r.stage == PartnerStage.agreed) {
      return false;
    }
    final latest = byId(r.event.id);
    if (latest == null ||
        r.brief.errors(latest).isNotEmpty && r.stage != PartnerStage.draft) {
      return false;
    }
    r.event = latest;
    for (final offer in r.offers.where(
      (o) => [
        PartnerOfferStatus.pending,
        PartnerOfferStatus.clarification,
      ].contains(o.status),
    )) {
      offer.status = PartnerOfferStatus.closed;
    }
    if (r.stage != PartnerStage.draft) r.stage = PartnerStage.submitted;
    _partnerRecord(
      r,
      'Данные события обновлены по подтверждению организатора. Прежние открытые предложения закрыты; для отправленной заявки нужен новый подбор.',
      notice: 'Условия мероприятия обновлены',
    );
    return true;
  }

  bool withdrawPartnerRequest(PartnerRequest r, int version) {
    if (!partnerAvailable(r) || r.version != version) return false;
    r.stage = PartnerStage.withdrawn;
    for (final o in r.offers.where(
      (o) => o.status != PartnerOfferStatus.declined,
    )) {
      o.status = PartnerOfferStatus.closed;
    }
    _partnerRecord(
      r,
      'Запрос отозван организатором. Предложения и согласование закрыты; история сохранена.',
      notice: 'Запрос отозван',
    );
    return true;
  }

  void cancelEventPartnerships(String eventId) {
    for (final r in _partnerRequests.where(
      (r) => r.event.id == eventId && !r.terminal,
    )) {
      r.stage = PartnerStage.cancelled;
      for (final o in r.offers.where(
        (o) => o.status != PartnerOfferStatus.declined,
      )) {
        o.status = PartnerOfferStatus.closed;
      }
      _partnerRecord(
        r,
        'Мероприятие отменено. Подбор и согласования закрыты, история сохранена.',
        notice: 'Партнёрство закрыто: событие отменено',
      );
    }
  }

  void readPartnerNotice(PartnerNotice n) {
    if (!_partnerNotices.contains(n) || n.read) return;
    n.read = true;
    _emit();
  }
}
