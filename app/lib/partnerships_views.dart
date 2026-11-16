part of 'main.dart';

const partnerDemoNote =
    'Демо · октябрь 2026. Бренды и предложения вымышлены. '
    'Заявки и решения сохраняются в этой вкладке до перезагрузки; реальных отправок, договоров и оплаты нет.';

Widget partnerPanel(
  String title,
  List<Widget> children, {
  Color color = Colors.white,
}) => Surface(
  color: color,
  child: Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: tx(22, weight: FontWeight.w600)),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  ),
);
Widget partnerCopy(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(value, style: tx(14, color: C.muted)),
);
Widget partnerAction(String key, String label, VoidCallback? onTap) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: OutlinedButton(
    key: ValueKey(key),
    onPressed: onTap,
    child: Text(label, textAlign: TextAlign.center),
  ),
);

class PartnershipsScreen extends StatefulWidget {
  const PartnershipsScreen({
    required this.store,
    this.eventId,
    this.request,
    super.key,
  });
  final EventsStore store;
  final String? eventId;
  final PartnerRequest? request;
  @override
  State<PartnershipsScreen> createState() => _PartnershipsScreenState();
}

class _PartnershipsScreenState extends State<PartnershipsScreen> {
  late PartnerRequest? selected =
      widget.request ??
      (widget.eventId == null ? null : store.partnerFor(widget.eventId!));
  String filter = 'Все';
  EventsStore get store => widget.store;
  @override
  void didUpdateWidget(PartnershipsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.eventId != oldWidget.eventId ||
        widget.request != oldWidget.request) {
      selected =
          widget.request ??
          (widget.eventId == null ? null : store.partnerFor(widget.eventId!));
    }
  }

  void result(bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Изменения сохранены в демо'
              : 'Состояние изменилось. Проверьте событие и актуальные условия запроса.',
        ),
      ),
    );
  }

  Future<bool> confirm(String title, String text, String label) async =>
      await discoveryDialog<bool>(
        context,
        title,
        (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text, style: tx(15)),
            const SizedBox(height: 20),
            PrimaryButton(
              label,
              () => Navigator.pop(ctx, true),
              key: const ValueKey('partner-confirm'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> create() async {
    final candidates = store.events
        .where((e) => !store.isCancelled(e.id))
        .toList();
    final event = widget.eventId == null
        ? await discoveryDialog<MontasEvent>(
            context,
            'Для какого мероприятия нужны партнёры?',
            (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (candidates.isEmpty)
                  partnerCopy(
                    'Сначала опубликуйте мероприятие в «Моих мероприятиях».',
                  ),
                for (final e in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      key: ValueKey('partner-event-${e.id}'),
                      onPressed: () => Navigator.pop(ctx, e),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              e.title,
                              style: tx(17, weight: FontWeight.w600),
                            ),
                            Text(e.date, style: tx(12)),
                            if (store.partnerFor(e.id) != null)
                              const Text('Открыть существующий запрос'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : store.byId(widget.eventId!);
    if (event == null || !mounted) return;
    final request = store.createPartnerRequest(event);
    if (request == null) {
      result(false);
      return;
    }
    setState(() => selected = request);
    if (request.stage == PartnerStage.draft) await edit(request);
  }

  Future<void> edit(PartnerRequest r) async {
    final version = r.version;
    final value = await discoveryDialog<PartnerBrief>(
      context,
      'Запрос партнёров',
      (ctx) => PartnerBriefEditor(brief: r.brief, event: r.event),
    );
    if (value != null && mounted) {
      result(store.savePartnerBrief(r, version, value));
    }
  }

  Future<void> submit(PartnerRequest r) async {
    final version = r.version;
    if (await confirm(
          'Передать запрос MONTAS?',
          '${r.event.title}\n${r.event.date}\n'
              'Нужны: ${r.brief.need}\nКатегории: ${r.brief.categories}\nПакет: ${r.brief.packageName}\n'
              'Стоимость: ${discoveryMoney(int.parse(r.brief.price))}\nСрок подбора: ${r.brief.deadline}\n'
              'Контакт: ${r.brief.contact}, ${r.brief.email}\n\nБудет создана демо-заявка. Реальное сообщение не отправляется.',
          'Подтвердить демо-заявку',
        ) &&
        mounted) {
      result(store.submitPartnerRequest(r, version));
    }
  }

  Future<void> decide(PartnerRequest r, PartnerOffer o) async {
    final version = r.version;
    if (await confirm(
          'Согласовать партнёра?',
          '${o.brand}\n${r.event.title}\nПакет «${r.brief.packageName}»\n'
              '${o.contribution}\n${o.terms}\n\nВ пакете одно место. Другие открытые предложения будут закрыты. '
              'Это демонстрационное согласование, без подписания договора и оплаты.',
          'Согласовать в демо',
        ) &&
        mounted) {
      result(store.decidePartnerOffer(r, o, version, accept: true));
    }
  }

  Future<void> offerMessage(
    PartnerRequest r,
    PartnerOffer o, {
    required bool decline,
  }) async {
    final version = r.version;
    final value = await discoveryDialog<String>(
      context,
      decline ? 'Почему предложение не подходит?' : 'Что нужно уточнить?',
      (ctx) => PartnerMessageEditor(decline: decline),
    );
    if (value == null || !mounted) return;
    result(
      decline
          ? store.decidePartnerOffer(
              r,
              o,
              version,
              accept: false,
              reason: value,
            )
          : store.clarifyPartnerOffer(r, o, version, value),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (ctx, _) => DiscoveryLayout(
      id: 'partners-${widget.eventId ?? 'all'}',
      note: partnerDemoNote,
      children: [
        DiscoveryHeading(
          'MONTAS EVENTS / ПАРТНЁРСТВА',
          selected == null ? 'Партнёрства' : 'Запрос ${selected!.id}',
          selected == null
              ? 'Найдите бренды для вашего события и согласуйте условия участия.'
              : selected!.event.title,
        ),
        if (selected == null) listing() else details(selected!),
      ],
    ),
  );

  Widget listing() {
    final records = store.partnerRequests
        .where(
          (r) =>
              (widget.eventId == null || r.event.id == widget.eventId) &&
              (filter == 'Все' ||
                  filter == 'Активные' &&
                      !r.terminal &&
                      r.stage != PartnerStage.agreed ||
                  filter == 'Согласованы' && r.stage == PartnerStage.agreed),
        )
        .toList();
    final event = widget.eventId == null ? null : store.byId(widget.eventId!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (event != null) ...[
          partnerPanel(event.title, [
            partnerCopy('${event.date}\n${event.venue}'),
            partnerCopy(
              'Действующих регистраций: ${store.attendees(event.id).length}. Ожидаемую аудиторию вы укажете в запросе.',
            ),
          ]),
          const SizedBox(height: 20),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const ValueKey('partners-create'),
              onPressed: event != null && store.isCancelled(event.id)
                  ? null
                  : create,
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Нужны партнёры'),
            ),
            for (final f in ['Все', 'Активные', 'Согласованы'])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (records.isEmpty)
          partnerPanel('Событие может стать точкой встречи с брендом', [
            partnerCopy(
              filter == 'Все'
                  ? 'Опишите, кого ищете: подарки для гостей, бренд-зону, спикера или финансового партнёра. '
                        'MONTAS предложит варианты, а решение останется за вами.'
                  : 'В этой группе запросов пока нет. Выберите другой фильтр.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final need in partnerNeeds) Tag(need)],
            ),
          ], color: C.mint),
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: partnerPanel(r.event.title, [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Tag(r.id),
                  Tag(r.label, green: r.stage == PartnerStage.agreed),
                  if (store.partnerEventChanged(r) && !r.terminal)
                    const Tag('Событие изменилось'),
                ],
              ),
              const SizedBox(height: 12),
              partnerCopy(
                '${r.brief.need} · ${r.brief.packageName.isEmpty ? 'Пакет не заполнен' : r.brief.packageName}',
              ),
              partnerAction(
                'partner-open-${r.id}',
                'Открыть запрос',
                () => setState(() => selected = r),
              ),
            ]),
          ),
      ],
    );
  }

  Widget details(PartnerRequest r) {
    final errors = r.brief.errors(r.event);
    final changed = store.partnerEventChanged(r),
        active = store.partnerAvailable(r);
    final pending = r.offers
        .where(
          (o) => [
            PartnerOfferStatus.pending,
            PartnerOfferStatus.clarification,
          ].contains(o.status),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('partner-back'),
            onPressed: () => setState(() => selected = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Все запросы'),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            Tag(r.label, green: r.stage == PartnerStage.agreed),
            const Tag('Одно партнёрское место'),
            if (r.offers.isNotEmpty) Tag('Открытых предложений: $pending'),
          ],
        ),
        const SizedBox(height: 20),
        if (changed && active) ...[
          partnerPanel('Условия мероприятия изменились', [
            partnerCopy(
              'В заявке сохранена прежняя версия события. До проверки новых данных согласование предложений недоступно.',
            ),
            partnerCopy(
              'Сейчас: ${store.byId(r.event.id)!.title}\n${store.byId(r.event.id)!.date}',
            ),
            if (r.stage == PartnerStage.agreed)
              partnerCopy(
                'Для пересмотра согласованного партнёрства отзовите этот запрос и создайте новый. История сохранится.',
              )
            else
              partnerAction(
                'partner-refresh',
                'Проверить и обновить данные',
                () async {
                  final version = r.version;
                  if (await confirm(
                        'Обновить заявку?',
                        'Сохранённые данные события будут заменены текущими. Открытые предложения закроются; отправленный запрос вернётся на подбор.',
                        'Обновить условия',
                      ) &&
                      mounted) {
                    result(store.refreshPartnerEvent(r, version));
                  }
                },
              ),
          ], color: C.soft),
          const SizedBox(height: 20),
        ],
        DiscoveryColumns(
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              partnerPanel('Кого ищем', [
                Text(r.brief.need, style: tx(19, weight: FontWeight.w600)),
                const SizedBox(height: 10),
                partnerCopy(
                  'Категории брендов: ${r.brief.categories.isEmpty ? 'Не заполнены' : r.brief.categories}',
                ),
                partnerCopy(
                  'Аудитория: ${r.brief.audience.isEmpty ? 'Не заполнена' : r.brief.audience}',
                ),
                partnerCopy(
                  'Ожидаем гостей: ${r.brief.guests.isEmpty ? 'Не указано' : r.brief.guests}\n'
                  'Действующих регистраций сейчас: ${store.attendees(r.event.id).length}',
                ),
                partnerCopy(
                  'Срок подбора: ${r.brief.deadline}\nОграничения: ${r.brief.restrictions.isEmpty ? 'Не указаны' : r.brief.restrictions}',
                ),
                if (r.stage == PartnerStage.draft && active) ...[
                  partnerAction(
                    'partner-edit',
                    'Заполнить / изменить запрос',
                    () => edit(r),
                  ),
                  if (errors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        'Перед отправкой:\n${errors.join('\n')}',
                        style: tx(12, color: C.muted),
                      ),
                    ),
                  partnerAction(
                    'partner-submit',
                    'Проверить и отправить',
                    errors.isEmpty && !changed ? () => submit(r) : null,
                  ),
                ],
              ]),
              const SizedBox(height: 20),
              if (r.stage == PartnerStage.submitted)
                partnerPanel('MONTAS подбирает варианты', [
                  partnerCopy(
                    'Заявка принята в демо-сеансе. Следующий шаг — предложения менеджера. Для демонстрации загрузите два тестовых варианта.',
                  ),
                  partnerAction(
                    'partner-demo-offers',
                    'Демо: получить два предложения',
                    !changed && active
                        ? () => result(store.receivePartnerOffers(r, r.version))
                        : null,
                  ),
                ], color: C.mint),
              if (r.stage == PartnerStage.agreed)
                partnerPanel('Партнёрство согласовано', [
                  partnerCopy(
                    'Следующий шаг — обсудить материалы и организационные детали с менеджером MONTAS. '
                    'Договоры и реальные платежи в этом прототипе не оформляются.',
                  ),
                ], color: C.mint),
              if (r.offers.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Предложения брендов',
                  style: tx(25, weight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (final offer in r.offers.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: offerCard(r, offer),
                  ),
                if (r.stage == PartnerStage.offers && pending == 0)
                  partnerCopy(
                    'Все предложения отклонены. Можно отозвать запрос и создать новый с другими условиями.',
                  ),
              ],
              const SizedBox(height: 20),
              Surface(
                child: Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    key: PageStorageKey('partner-history-${r.id}'),
                    title: const Text('История запроса'),
                    children: [
                      for (final text in r.history.reversed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.history,
                                size: 18,
                                color: C.green,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(text, style: tx(13))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              partnerPanel('Пакет партнёрства', [
                Text(
                  r.brief.packageName.isEmpty
                      ? 'Название не заполнено'
                      : r.brief.packageName,
                  style: tx(21, weight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  int.tryParse(r.brief.price) == null
                      ? 'Стоимость не указана'
                      : int.parse(r.brief.price) == 0
                      ? 'Без денежного взноса'
                      : discoveryMoney(int.parse(r.brief.price)),
                  style: tx(28, weight: FontWeight.w600),
                ),
                partnerCopy('Одно место для одного бренда'),
                const Divider(height: 24),
                partnerCopy(
                  r.brief.includes.isEmpty
                      ? 'Опишите, что получает партнёр.'
                      : r.brief.includes,
                ),
              ]),
              const SizedBox(height: 20),
              partnerPanel('Событие и контакт', [
                partnerCopy(
                  '${r.event.title}\n${r.event.date}\n${r.event.venue}\n${r.event.format}',
                ),
                partnerCopy(
                  'Контакт организатора:\n${r.brief.contact.isEmpty ? 'Не указан' : r.brief.contact}\n${r.brief.email}',
                ),
                if (active)
                  TextButton(
                    key: const ValueKey('partner-withdraw'),
                    onPressed: () async {
                      final version = r.version;
                      if (await confirm(
                            'Отозвать запрос?',
                            'Подбор и согласованное партнёрство, если оно есть, будут закрыты. История сохранится.',
                            'Отозвать запрос',
                          ) &&
                          mounted) {
                        result(store.withdrawPartnerRequest(r, version));
                      }
                    },
                    child: const Text('Отозвать запрос'),
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget offerCard(PartnerRequest r, PartnerOffer o) {
    final available =
        store.partnerAvailable(r) &&
        r.stage == PartnerStage.offers &&
        !store.partnerEventChanged(r);
    return partnerPanel(o.brand, [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Tag(o.statusLabel, green: o.status == PartnerOfferStatus.accepted),
          const Tag('Тестовое предложение'),
        ],
      ),
      const SizedBox(height: 14),
      partnerCopy(o.reason),
      Text('Что предлагает бренд', style: tx(15, weight: FontWeight.w600)),
      partnerCopy(o.contribution),
      Text('Условия', style: tx(15, weight: FontWeight.w600)),
      partnerCopy(o.terms),
      if (available && o.status == PartnerOfferStatus.pending) ...[
        partnerAction(
          'partner-accept-${o.id}',
          'Согласовать партнёра',
          () => decide(r, o),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              key: ValueKey('partner-clarify-${o.id}'),
              onPressed: () => offerMessage(r, o, decline: false),
              child: const Text('Запросить уточнение'),
            ),
            TextButton(
              key: ValueKey('partner-decline-${o.id}'),
              onPressed: () => offerMessage(r, o, decline: true),
              child: const Text('Отклонить'),
            ),
          ],
        ),
      ],
      if (available && o.status == PartnerOfferStatus.clarification) ...[
        partnerCopy('Вопрос сохранён в истории. Ожидаем уточнение менеджера.'),
        partnerAction(
          'partner-demo-reply-${o.id}',
          'Демо: получить ответ менеджера',
          () => result(store.replyToPartnerClarification(r, o, r.version)),
        ),
      ],
    ]);
  }
}

class PartnerBriefEditor extends StatefulWidget {
  const PartnerBriefEditor({
    required this.brief,
    required this.event,
    super.key,
  });
  final PartnerBrief brief;
  final MontasEvent event;
  @override
  State<PartnerBriefEditor> createState() => _PartnerBriefEditorState();
}

class _PartnerBriefEditorState extends State<PartnerBriefEditor> {
  late String need = widget.brief.need;
  late final fields = <String, TextEditingController>{
    'categories': TextEditingController(text: widget.brief.categories),
    'audience': TextEditingController(text: widget.brief.audience),
    'guests': TextEditingController(text: widget.brief.guests),
    'deadline': TextEditingController(text: widget.brief.deadline),
    'contact': TextEditingController(text: widget.brief.contact),
    'email': TextEditingController(text: widget.brief.email),
    'package': TextEditingController(text: widget.brief.packageName),
    'includes': TextEditingController(text: widget.brief.includes),
    'price': TextEditingController(text: widget.brief.price),
    'restrictions': TextEditingController(text: widget.brief.restrictions),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String id,
    String label, {
    int lines = 1,
    int max = 200,
    bool number = false,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: TextField(
      key: ValueKey('partner-field-$id'),
      controller: fields[id],
      maxLines: lines,
      maxLength: max,
      keyboardType: number
          ? TextInputType.number
          : email
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
  void fillDemo() {
    final values = {
      'categories': 'Wellness, товары для активного образа жизни',
      'guests': '80',
      'audience': widget.event.audience.isEmpty
          ? 'Гости, интересующиеся здоровьем и активным образом жизни.'
          : widget.event.audience,
      'contact': 'Наталья Орлова · демо',
      'email': 'organizer@example.com',
      'package': 'Партнёр встречи',
      'includes':
          'Логотип на странице события; представление бренда ведущим; место для материалов на площадке.',
      'price': '50000',
      'restrictions':
          'Макеты согласовать заранее. Без медицинских обещаний и сбора контактов гостей без согласия.',
    };
    for (final entry in values.entries) {
      fields[entry.key]!.text = entry.value;
    }
    setState(() => need = 'Подарки участникам');
  }

  PartnerBrief value() => PartnerBrief(
    categories: fields['categories']!.text.trim(),
    need: need,
    audience: fields['audience']!.text.trim(),
    guests: fields['guests']!.text.trim(),
    deadline: fields['deadline']!.text.trim(),
    contact: fields['contact']!.text.trim(),
    email: fields['email']!.text.trim(),
    packageName: fields['package']!.text.trim(),
    includes: fields['includes']!.text.trim(),
    price: fields['price']!.text.trim(),
    restrictions: fields['restrictions']!.text.trim(),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      partnerCopy(
        '${widget.event.title}\n${widget.event.date}\nДанные события подставлены автоматически.',
      ),
      OutlinedButton.icon(
        key: const ValueKey('partner-fill-demo'),
        onPressed: fillDemo,
        icon: const Icon(Icons.auto_fix_high_outlined),
        label: const Text('Заполнить примером'),
      ),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(
        key: ValueKey('partner-need-$need'),
        initialValue: need,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Какое партнёрство нужно'),
        items: [
          for (final item in partnerNeeds)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (v) => setState(() => need = v!),
      ),
      field('categories', 'Категории брендов *'),
      field('audience', 'Аудитория события *', lines: 3, max: 1000),
      field('guests', 'Ожидаемое число гостей *', number: true, max: 6),
      field('deadline', 'Подобрать до · ДД.ММ.ГГГГ *', max: 10),
      const Divider(height: 30),
      Text(
        'Пакет · одно партнёрское место',
        style: tx(18, weight: FontWeight.w600),
      ),
      field('package', 'Название пакета *', max: 100),
      field('includes', 'Что получает партнёр *', lines: 3, max: 1500),
      field(
        'price',
        'Стоимость, ₽ · 0 для обмена без взноса *',
        number: true,
        max: 8,
      ),
      field('restrictions', 'Ограничения и пожелания', lines: 3, max: 1000),
      const Divider(height: 30),
      Text('Контакт по мероприятию', style: tx(18, weight: FontWeight.w600)),
      field('contact', 'Контактное лицо *', max: 120),
      field('email', 'Email *', email: true),
      partnerCopy(
        'Сохранение создаёт только черновик. Перед отправкой вы проверите заявку целиком.',
      ),
      partnerAction(
        'partner-save-brief',
        'Сохранить черновик',
        () => Navigator.pop(context, value()),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отменить изменения'),
      ),
    ],
  );
}

class PartnerMessageEditor extends StatefulWidget {
  const PartnerMessageEditor({required this.decline, super.key});
  final bool decline;
  @override
  State<PartnerMessageEditor> createState() => _PartnerMessageEditorState();
}

class _PartnerMessageEditorState extends State<PartnerMessageEditor> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('partner-message'),
        controller: input,
        maxLength: 1000,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.decline ? 'Причина отказа' : 'Вопрос менеджеру',
        ),
      ),
      partnerCopy(
        'Текст сохранится в истории демо-заявки. Реальное сообщение не отправляется.',
      ),
      partnerAction(
        'partner-message-save',
        widget.decline ? 'Отклонить предложение' : 'Сохранить уточнение',
        input.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, input.text.trim()),
      ),
    ],
  );
}

class PartnerNoticeFeed extends StatelessWidget {
  const PartnerNoticeFeed({
    required this.store,
    required this.onOpen,
    super.key,
  });
  final EventsStore store;
  final ValueChanged<PartnerRequest> onOpen;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Партнёрства · новых: ${store.partnerUnread}',
        style: tx(23, weight: FontWeight.w600),
      ),
      const SizedBox(height: 14),
      if (store.partnerNotices.isEmpty)
        partnerCopy(
          'Здесь появятся статусы ваших запросов и предложения брендов.',
        ),
      for (final notice in store.partnerNotices)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: partnerPanel(notice.title, [
            Align(
              alignment: Alignment.centerLeft,
              child: Tag(
                notice.read ? 'Прочитано' : 'Новое',
                green: !notice.read,
              ),
            ),
            const SizedBox(height: 10),
            partnerCopy('${notice.request.id} · ${notice.request.event.title}'),
            Text(notice.body, style: tx(14)),
            TextButton(
              onPressed: () {
                store.readPartnerNotice(notice);
                onOpen(notice.request);
              },
              child: const Text('Открыть запрос'),
            ),
          ]),
        ),
      const SizedBox(height: 20),
    ],
  );
}
