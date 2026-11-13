part of 'main.dart';

bool matchesEventDate(MontasEvent event, String filter, DateTime today) {
  final raw = event.startsAt ?? DateTime(2026, 10, event.day);
  final date = DateTime(raw.year, raw.month, raw.day);
  final anchor = DateTime(today.year, today.month, today.day);
  if (filter == 'Сегодня') return date == anchor;
  if (filter == 'Завтра') return date == anchor.add(const Duration(days: 1));
  if (filter == 'Выходные') {
    final start = anchor
        .subtract(Duration(days: anchor.weekday == 7 ? 1 : 0))
        .add(Duration(days: anchor.weekday < 6 ? 6 - anchor.weekday : 0));
    return date == start || date == start.add(const Duration(days: 1));
  }
  return true;
}

class OrganizerEventWorkspace extends StatefulWidget {
  const OrganizerEventWorkspace({
    required this.store,
    required this.eventId,
    required this.onBack,
    required this.onEdit,
    required this.onCancel,
    this.onPublic,
    super.key,
  });
  final EventsStore store;
  final String eventId;
  final VoidCallback onBack;
  final ValueChanged<MontasEvent> onEdit, onCancel;
  final ValueChanged<MontasEvent>? onPublic;
  @override
  State<OrganizerEventWorkspace> createState() =>
      _OrganizerEventWorkspaceState();
}

class _OrganizerEventWorkspaceState extends State<OrganizerEventWorkspace> {
  int tab = 0;
  @override
  void didUpdateWidget(OrganizerEventWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) tab = 0;
  }

  Future<void> addFormat(MontasEvent event) async {
    final ticket = await editTicketDialog(
      context,
      'format-${event.tickets.length + 1}',
    );
    if (ticket == null || !mounted) return;
    final ok = widget.store.addTicket(event, ticket);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Формат опубликован. Уже оформленные билеты сохранены.'
              : 'Событие изменилось или есть черновик. Сначала завершите редактирование.',
        ),
      ),
    );
  }

  Widget metric(String title, String value, String caption) => Surface(
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tx(13, color: C.muted)),
        const SizedBox(height: 10),
        Text(value, style: tx(30, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(caption, style: tx(12, color: C.muted)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final event = store.byId(widget.eventId)!;
      final cancelled = store.isCancelled(event.id);
      final active = store.attendees(event.id);
      final records = store.registrations
          .where((r) => r.event.id == event.id)
          .toList();
      final capacity = event.tickets.fold<int>(0, (sum, t) => sum + t.capacity);
      final materials = store.materialsFor(event.id);
      final tabs = [
        'Обзор',
        'Страница события',
        'Билеты',
        'Участники',
        'Материалы',
        'Уведомления',
        'Статистика',
        'Партнёрства',
      ];
      Widget body;
      if (tab == 7) {
        body = PartnershipsScreen(store: store, eventId: event.id);
      } else if (tab == 4) {
        body = EventOperationsPanel(
          key: ValueKey(event.id),
          store: store,
          eventId: event.id,
          embedded: true,
          onBack: () => setState(() => tab = 0),
        );
      } else {
        body = DiscoveryLayout(
          id: 'event-workspace-${event.id}-$tab',
          children: [
            if (tab == 0) ...[
              DiscoveryGrid(
                children: [
                  metric(
                    'Регистрации',
                    '${active.length} / $capacity',
                    'Действующие записи / места',
                  ),
                  metric(
                    'Форматы участия',
                    '${event.tickets.length}',
                    'Доступные варианты билетов',
                  ),
                  metric(
                    'Материалы',
                    '${materials.where((m) => m.published).length}',
                    'Опубликовано для участников',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Проведение встречи',
                      style: tx(22, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    discoveryFact(Icons.event_outlined, event.date),
                    discoveryFact(Icons.place_outlined, event.venue),
                    discoveryFact(Icons.people_outline, event.speakers),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!cancelled)
                          OutlinedButton.icon(
                            key: const ValueKey('workspace-partners'),
                            onPressed: () => setState(() => tab = 7),
                            icon: const Icon(Icons.handshake_outlined),
                            label: const Text('Нужны партнёры'),
                          ),
                        FilledButton(
                          onPressed: () => setState(() => tab = 3),
                          child: const Text('Список участников'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() => tab = 4),
                          child: const Text('Материалы встречи'),
                        ),
                        OutlinedButton(
                          onPressed: () => setState(() => tab = 1),
                          child: const Text('Предпросмотр страницы'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('История события', style: tx(22, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Опубликовано в афише', style: tx(14)),
                    for (final change in store.changesFor(event.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(change.summary.join('\n'), style: tx(14)),
                      ),
                    if (cancelled)
                      Text(
                        'Отменено: ${store.cancellationReason(event.id)}',
                        style: tx(14),
                      ),
                  ],
                ),
              ),
              if (!cancelled)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('workspace-cancel-event'),
                    onPressed: () => widget.onCancel(event),
                    child: const Text('Отменить событие'),
                  ),
                ),
            ],
            if (tab == 1) ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  const Tag('Предпросмотр страницы участника'),
                  if (!cancelled)
                    OutlinedButton(
                      onPressed: () => widget.onEdit(event),
                      child: const Text('Редактировать страницу'),
                    ),
                  if (widget.onPublic != null)
                    OutlinedButton(
                      onPressed: () => widget.onPublic!(event),
                      child: const Text('Открыть как пользователь'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              DiscoveryColumns(
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.asset(
                          'assets/events/${event.coverId ?? event.id}-v1.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(event.description, style: tx(16)),
                    const SizedBox(height: 20),
                    EventAudienceInfo(event: event),
                  ],
                ),
                aside: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.date, style: tx(20, weight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(event.venue, style: tx(14)),
                      const Divider(height: 32),
                      Text('Программа', style: tx(20, weight: FontWeight.w600)),
                      for (final item in event.agenda)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(item, style: tx(14)),
                        ),
                      const Divider(height: 32),
                      Text(event.speakers, style: tx(14)),
                    ],
                  ),
                ),
              ),
            ],
            if (tab == 2) ...[
              Text('Форматы участия', style: tx(24, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'У каждого формата своя вместимость. Условия оформленных билетов сохраняются; новые форматы публикуются сразу.',
                style: tx(14, color: C.muted),
              ),
              const SizedBox(height: 20),
              for (final t in event.tickets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tag(t.online ? 'Онлайн' : 'Очно'),
                        const SizedBox(height: 12),
                        Text(t.name, style: tx(22, weight: FontWeight.w600)),
                        Text(
                          discoveryMoney(t.price),
                          style: tx(20, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Text(t.includes, style: tx(14)),
                        const SizedBox(height: 8),
                        Text(
                          'Занято: ${t.capacity - store.remaining(event, t)} из ${t.capacity} · свободно: ${store.remaining(event, t)}',
                          style: tx(14),
                        ),
                        Text(
                          'Отмена: ${t.cancelUntil}',
                          style: tx(13, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!cancelled && event.tickets.length < 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('workspace-add-ticket'),
                    onPressed: () => addFormat(event),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить формат'),
                  ),
                ),
            ],
            if (tab == 3) EventRoster(store: store, eventId: event.id),
            if (tab == 5)
              EventNoticeList(store: store, organizer: true, eventId: event.id),
            if (tab == 6) ...[
              Text('Участие в цифрах', style: tx(24, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Показатели рассчитаны по действиям в этой вкладке. Стоимость билетов не считается выручкой.',
                style: tx(14, color: C.muted),
              ),
              const SizedBox(height: 20),
              DiscoveryGrid(
                children: [
                  metric(
                    'Зарегистрировано',
                    '${active.length}',
                    'Действующие записи',
                  ),
                  metric(
                    'Отменено',
                    '${records.where((r) => r.cancelled).length}',
                    'Записи сохранены в истории',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Заполненность · ${active.length} из $capacity',
                      style: tx(18, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: capacity == 0 ? 0 : active.length / capacity,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 24),
                    for (final t in event.tickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${t.name}\nЗаписано: ${active.where((r) => r.ticket.id == t.id).length} · мест: ${t.capacity}',
                          style: tx(14),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      }
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: C.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('workspace-event-back'),
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Мои мероприятия'),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx(23, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tag(
                      cancelled ? 'Отменено' : 'Опубликовано',
                      green: !cancelled,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 12),
                          child: ChoiceChip(
                            key: ValueKey('event-workspace-tab-$i'),
                            label: Text(tabs[i]),
                            selected: tab == i,
                            selectedColor: C.dark,
                            labelStyle: tx(
                              13,
                              color: tab == i ? Colors.white : C.ink,
                            ),
                            showCheckmark: false,
                            onSelected: (_) => setState(() => tab = i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    },
  );
}

class EventRoster extends StatefulWidget {
  const EventRoster({required this.store, required this.eventId, super.key});
  final EventsStore store;
  final String eventId;
  @override
  State<EventRoster> createState() => _EventRosterState();
}

class _EventRosterState extends State<EventRoster> {
  String query = '', status = 'Все';
  @override
  Widget build(BuildContext context) {
    final records = widget.store.registrations
        .where(
          (r) =>
              r.event.id == widget.eventId &&
              '${r.participantName} ${r.participantEmail} ${r.id}'
                  .toLowerCase()
                  .contains(query.toLowerCase()) &&
              (status == 'Все' ||
                  (status == 'Записались' && !r.cancelled) ||
                  (status == 'Отменили' && r.cancelled)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Участники', style: tx(24, weight: FontWeight.w600)),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('event-roster-search'),
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Имя, почта или номер записи',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in ['Все', 'Записались', 'Отменили'])
              ChoiceChip(
                label: Text(v),
                selected: status == v,
                onSelected: (_) => setState(() => status = v),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (records.isEmpty)
          const Surface(child: Text('Участников по этим условиям пока нет.')),
        for (final r in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              key: ValueKey('event-roster-${r.id}'),
              padding: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(
                    r.cancelledByEvent
                        ? 'Событие отменено'
                        : r.cancelled
                        ? 'Отменена'
                        : 'Записан',
                    green: !r.cancelled,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r.participantName,
                    style: tx(20, weight: FontWeight.w600),
                  ),
                  Text(r.participantEmail, style: tx(13, color: C.muted)),
                  const SizedBox(height: 8),
                  Text('${r.id} · ${r.ticket.name}', style: tx(14)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
