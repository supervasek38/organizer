part of 'main.dart';

/// An immutable saved revision. Publication copies it into the public catalog.
class EventDraft {
  const EventDraft({
    required this.id,
    this.title = '',
    this.description = '',
    this.dateText = '30.10.2026',
    this.start = '19:00',
    this.end = '20:30',
    this.online = true,
    this.venue = 'Онлайн · в MONTAS',
    this.category = 'Открытая встреча',
    this.speakers = '',
    this.program = '',
    this.ticketName = 'Участие во встрече',
    this.priceText = '0',
    this.capacityText = '30',
    this.includes = 'Участие в программе и ответы на вопросы',
    this.cancelUntil = 'До начала события',
    this.coverId = 'sleep-lab',
    this.baseEvent,
    this.extraTickets = const [],
    this.audience = '',
    this.outcomes = '',
    this.preparation = '',
  });
  final String id, title, description, dateText, start, end, venue, category;
  final String speakers, program, ticketName, priceText, capacityText;
  final String includes, cancelUntil, coverId;
  final bool online;
  final MontasEvent? baseEvent;
  final List<EventTicket> extraTickets;
  final String audience, outcomes, preparation;

  DateTime? get date {
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(dateText);
    if (match == null) return null;
    final day = int.parse(match[1]!), month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  static int? timeMinutes(String value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
    return hour < 24 && minute < 60 ? hour * 60 + minute : null;
  }

  List<String> get errors {
    final a = timeMinutes(start), b = timeMinutes(end);
    final price = int.tryParse(priceText),
        capacity = int.tryParse(capacityText);
    return [
      if (title.trim().isEmpty || title.length > 120)
        'Название: от 1 до 120 символов.',
      if (description.trim().isEmpty || description.length > 3000)
        'Добавьте описание до 3000 символов.',
      if (date == null ||
          date!.isBefore(DateTime(2026, 10, 20)) ||
          date!.year > 2100)
        'Укажите существующую дату не раньше 20.10.2026 (дата демо).',
      if (a == null || b == null || b <= a)
        'Время: ЧЧ:ММ, окончание позже начала в тот же день.',
      if (venue.trim().isEmpty) 'Укажите площадку или место онлайн-встречи.',
      if (speakers.trim().isEmpty) 'Укажите ведущего или спикеров.',
      if (program.trim().isEmpty) 'Добавьте хотя бы один пункт программы.',
      if (ticketName.trim().isEmpty ||
          includes.trim().isEmpty ||
          cancelUntil.trim().isEmpty)
        'Заполните название билета, состав участия и условия отмены.',
      if (price == null || price < 0 || price > 1000000)
        'Цена: целое число от 0 до 1 000 000 ₽.',
      if (capacity == null || capacity < 1 || capacity > 10000)
        'Количество мест: от 1 до 10 000.',
      if (!['sleep-lab', 'analysis', 'recovery'].contains(coverId))
        'Выберите обложку.',
      if (extraTickets.length > 5) 'Максимум шесть форматов участия.',
      if (extraTickets.any((t) => !validEventTicket(t)) ||
          extraTickets.any((t) => t.id == 'participation') ||
          extraTickets.map((t) => t.id).toSet().length != extraTickets.length)
        'Проверьте дополнительные форматы участия.',
      if ([audience, outcomes, preparation].any((s) => s.length > 1000))
        'Каждый дополнительный блок — до 1000 символов.',
    ];
  }

  MontasEvent toEvent() => MontasEvent(
    id: id,
    title: title.trim(),
    day: date!.day,
    startsAt: date,
    time: '$start–$end',
    category: category,
    description: description.trim(),
    speakers: speakers.trim(),
    venue: venue.trim(),
    icon: Icons.event_outlined,
    coverId: coverId,
    audience: audience.trim(),
    outcomes: outcomes.trim(),
    preparation: preparation.trim(),
    agenda: List.unmodifiable(
      program.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty),
    ),
    tickets:
        baseEvent?.tickets ??
        List.unmodifiable([
          EventTicket(
            'participation',
            ticketName.trim(),
            int.parse(priceText),
            online,
            includes.trim(),
            capacity: int.parse(capacityText),
            cancelUntil: cancelUntil.trim(),
          ),
          ...extraTickets,
        ]),
  );
}

class OrganizerWorkspace extends StatefulWidget {
  const OrganizerWorkspace({
    required this.store,
    this.onPublicEvent,
    this.onCatalog,
    this.onTodayChanged,
    super.key,
  });
  final EventsStore store;
  final ValueChanged<MontasEvent>? onPublicEvent;
  final VoidCallback? onCatalog;
  final ValueChanged<bool>? onTodayChanged;
  @override
  State<OrganizerWorkspace> createState() => OrganizerWorkspaceState();
}

class OrganizerWorkspaceState extends State<OrganizerWorkspace> {
  int section = 0;
  String? editingId, participantsEventId;
  String? materialsEventId;
  String? managedEventId;
  String? partnerEventId;
  PartnerRequest? partnerRequest;
  final editorKey = GlobalKey<OrganizerEditorState>();
  final managedKey = GlobalKey<_OrganizerEventWorkspaceState>();
  EventsStore get store => widget.store;
  void openToday() => openSection(0);
  void openSection(int value) {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    widget.onTodayChanged?.call(value == 0);
    editorKey.currentState?.save();
    setState(() {
      section = value;
      editingId = null;
      managedEventId = null;
      partnerEventId = null;
      partnerRequest = null;
    });
  }

  void edit(EventDraft draft) {
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    widget.onTodayChanged?.call(false);
    editorKey.currentState?.save();
    setState(() {
      section = 1;
      editingId = draft.id;
    });
  }

  void openPartnerships({String? eventId, PartnerRequest? request}) {
    widget.onTodayChanged?.call(false);
    editorKey.currentState?.save();
    setState(() {
      section = 5;
      editingId = null;
      managedEventId = null;
      partnerEventId = eventId;
      partnerRequest = request;
    });
  }

  void create() {
    editorKey.currentState?.save();
    edit(store.createDraft());
  }

  void participants(MontasEvent event) {
    widget.onTodayChanged?.call(false);
    setState(() {
      section = 2;
      editingId = null;
      participantsEventId = event.id;
    });
  }

  void manage(MontasEvent event) {
    widget.onTodayChanged?.call(false);
    setState(() {
      managedEventId = event.id;
      section = 1;
    });
  }

  Future<void> cancelEvent(MontasEvent event) async {
    final recipients = store.attendees(event.id).map((r) => r.id).toList();
    final reason = TextEditingController();
    String? validation;
    final yes = await discoveryDialog<bool>(
      context,
      'Отменить мероприятие?',
      (ctx) => StatefulBuilder(
        builder: (ctx, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(event.title, style: tx(21, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Запись закроется. Уведомление с причиной появится у ${recipients.length} участников. Событие и регистрации останутся в истории. Реальные письма и возвраты не выполняются.',
              style: tx(14),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('organizer-cancel-reason'),
              controller: reason,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: 'Причина отмены *',
                errorText: validation,
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton('Отменить и уведомить участников', () {
              if (reason.text.trim().isEmpty) {
                update(() => validation = 'Укажите причину отмены');
                return;
              }
              Navigator.pop(ctx, true);
            }, key: const ValueKey('organizer-confirm-cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Сохранить мероприятие'),
            ),
          ],
        ),
      ),
    );
    final text = reason.text;
    // The dialog's text field finishes its closing animation before disposal.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (yes != true || !mounted) return;
    final success = store.cancelEvent(event, text, recipients);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Событие отменено. Уведомления созданы в демо-кабинетах.'
              : 'Событие или список участников изменился. Откройте отмену заново.',
        ),
      ),
    );
  }

  Widget materialPicker() => DiscoveryLayout(
    id: 'organizer-material-picker',
    children: [
      const DiscoveryHeading(
        'Материалы',
        'Материалы мероприятий',
        'Презентации, записи и полезные файлы для ваших участников.',
      ),
      for (final event in store.events)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Surface(
            child: LayoutBuilder(
              builder: (context, box) {
                final info = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: C.mint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.folder_open_rounded,
                        color: C.ink,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: tx(20, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(event.date, style: tx(13, color: C.muted)),
                          const SizedBox(height: 8),
                          Text(
                            'Файлов: ${store.materialsFor(event.id).length}${store.isCancelled(event.id) ? " · событие отменено" : ""}',
                            style: tx(13, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final action = OutlinedButton.icon(
                  onPressed: () => setState(() => materialsEventId = event.id),
                  label: const Text('Открыть материалы'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                );
                if (box.maxWidth < 680) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [info, const SizedBox(height: 20), action],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 24),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, box) {
        if (section == 0 && editingId == null && managedEventId == null) {
          return OrganizerTodayScreen(
            store: store,
            onSection: openSection,
            onCreate: create,
            onManage: manage,
            onParticipants: participants,
            onPartners: (e) => openPartnerships(eventId: e.id),
            onPublic: widget.onPublicEvent,
            onCatalog: widget.onCatalog,
            onDraft: edit,
          );
        }
        final draft = store.drafts.where((d) => d.id == editingId).firstOrNull;
        final content = draft != null
            ? OrganizerEditor(
                key: editorKey,
                draft: draft,
                store: store,
                onBack: () => managedEventId == null
                    ? openSection(1)
                    : setState(() => editingId = null),
                onPublished: (event) {
                  setState(() {
                    editingId = null;
                    section = 1;
                  });
                },
              )
            : managedEventId != null
            ? OrganizerEventWorkspace(
                key: managedKey,
                store: store,
                eventId: managedEventId!,
                onBack: () => openSection(1),
                onEdit: (event) {
                  final draft = store.editPublished(event);
                  if (draft != null) edit(draft);
                },
                onCancel: cancelEvent,
                onPublic: widget.onPublicEvent,
              )
            : section == 5
            ? PartnershipsScreen(
                store: store,
                eventId: partnerEventId,
                request: partnerRequest,
              )
            : section == 2
            ? participantsView()
            : section == 3
            ? materialsEventId == null
                  ? materialPicker()
                  : EventOperationsPanel(
                      key: ValueKey(materialsEventId),
                      store: store,
                      eventId: materialsEventId!,
                      onBack: () => setState(() => materialsEventId = null),
                    )
            : section == 4
            ? DiscoveryLayout(
                id: 'organizer-notices',
                children: [
                  const DiscoveryHeading(
                    'ОРГАНИЗАТОР',
                    'Уведомления',
                    'Партнёрства и журнал уведомлений участникам. Письма и push-сообщения не отправляются.',
                  ),
                  PartnerNoticeFeed(
                    store: store,
                    onOpen: (r) => openPartnerships(request: r),
                  ),
                  Text(
                    'Уведомления участникам',
                    style: tx(23, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  EventNoticeList(
                    store: store,
                    organizer: true,
                    onOpen: widget.onPublicEvent,
                  ),
                ],
              )
            : overview(section == 0);
        return OrganizerShell(
          store: store,
          selected: section,
          title: draft != null
              ? 'Редактирование события'
              : managedEventId != null
              ? 'Управление событием'
              : OrganizerShell.menu[section].$1,
          onSection: openSection,
          onCatalog: widget.onCatalog,
          child: content,
        );
      },
    ),
  );

  Widget overview(bool today) => DiscoveryLayout(
    id: 'organizer-overview-$today',
    children: [
      DiscoveryHeading(
        'РАБОЧАЯ СРЕДА · ОРГАНИЗАТОР',
        today ? 'Сегодня организатора' : 'Мои мероприятия',
        today
            ? 'Ваши события, подготовка и регистрации в одном месте.'
            : 'От первого черновика до встречи с участниками.',
        action: FilledButton.icon(
          key: const ValueKey('organizer-create'),
          onPressed: create,
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Создать мероприятие'),
        ),
      ),
      if (store.drafts.isNotEmpty) ...[
        Text('Продолжить подготовку', style: tx(22, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final draft in store.drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              padding: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Tag('Черновик'),
                  const SizedBox(height: 10),
                  Text(
                    draft.title.isEmpty ? 'Новое мероприятие' : draft.title,
                    style: tx(20, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${draft.dateText} · ${draft.start} · МСК',
                    style: tx(13, color: C.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: ValueKey('organizer-edit-${draft.id}'),
                    onPressed: () => edit(draft),
                    child: const Text('Продолжить редактирование'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
      Text(
        'Опубликованные мероприятия',
        style: tx(22, weight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      for (final event in store.events)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Surface(
            padding: 20,
            child: LayoutBuilder(
              builder: (context, box) {
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tag(
                      store.isCancelled(event.id)
                          ? 'Событие отменено'
                          : 'Опубликовано',
                      green: !store.isCancelled(event.id),
                    ),
                    if (store.isCancelled(event.id))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          store.cancellationReason(event.id)!,
                          style: tx(14, color: C.muted),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(event.title, style: tx(21, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      '${event.date} · ${event.format}',
                      style: tx(13, color: C.muted),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Участников: ${store.attendees(event.id).length} · '
                      '${store.isCancelled(event.id) ? "Регистрация закрыта" : "Свободных мест: ${event.tickets.fold<int>(0, (n, t) => n + store.remaining(event, t))}"}',
                      style: tx(14),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          key: ValueKey('organizer-participants-${event.id}'),
                          onPressed: () => participants(event),
                          child: const Text('Участники'),
                        ),
                        if (!store.isCancelled(event.id))
                          TextButton.icon(
                            key: ValueKey('organizer-partners-${event.id}'),
                            onPressed: () =>
                                openPartnerships(eventId: event.id),
                            icon: const Icon(
                              Icons.handshake_outlined,
                              size: 18,
                            ),
                            label: Text(
                              store.partnerFor(event.id) == null
                                  ? 'Нужны партнёры'
                                  : 'Партнёрство',
                            ),
                          ),
                        if (widget.onPublicEvent != null)
                          TextButton(
                            key: ValueKey('organizer-public-${event.id}'),
                            onPressed: () => widget.onPublicEvent!(event),
                            child: const Text('Открыть как пользователь'),
                          ),
                        if (!store.isCancelled(event.id))
                          TextButton(
                            key: ValueKey('organizer-update-${event.id}'),
                            onPressed: () {
                              final draft = store.editPublished(event);
                              if (draft != null) edit(draft);
                            },
                            child: const Text('Редактировать'),
                          ),
                        TextButton(
                          key: ValueKey('organizer-materials-${event.id}'),
                          onPressed: () => setState(() {
                            section = 3;
                            editingId = null;
                            materialsEventId = event.id;
                          }),
                          child: const Text('Материалы и история'),
                        ),
                        if (!store.isCancelled(event.id))
                          TextButton(
                            key: ValueKey('organizer-cancel-${event.id}'),
                            onPressed: () => cancelEvent(event),
                            child: const Text('Отменить событие'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: ValueKey('organizer-manage-${event.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: C.lime,
                        foregroundColor: C.ink,
                      ),
                      onPressed: () => setState(() {
                        managedEventId = event.id;
                        section = 1;
                      }),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Управление событием'),
                    ),
                  ],
                );
                final photo = ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.asset(
                      'assets/events/${event.coverId ?? event.id}-v1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                );
                return box.maxWidth < 600
                    ? info
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: photo),
                          const SizedBox(width: 24),
                          Expanded(child: info),
                        ],
                      );
              },
            ),
          ),
        ),
    ],
  );

  Widget metric(String title, String value, String note) => Surface(
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tx(13, color: C.muted)),
        Text(value, style: tx(32, weight: FontWeight.w600)),
        Text(note, style: tx(12, color: C.muted)),
      ],
    ),
  );

  Widget participantsView() {
    final records = store.registrations
        .where(
          (r) =>
              participantsEventId == null || r.event.id == participantsEventId,
        )
        .toList();
    return DiscoveryLayout(
      id: 'organizer-participants',
      children: [
        const DiscoveryHeading(
          'ОРГАНИЗАТОР · РЕГИСТРАЦИИ',
          'Участники мероприятий',
          'Записи из личного кабинета появляются здесь сразу. Отменённые остаются в истории.',
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'organizer-event-filter-${participantsEventId ?? "all"}',
          ),
          initialValue: participantsEventId ?? 'all',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Мероприятие'),
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('Все мероприятия'),
            ),
            for (final event in store.events)
              DropdownMenuItem(
                value: event.id,
                child: Text(event.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) =>
              setState(() => participantsEventId = v == 'all' ? null : v),
        ),
        const SizedBox(height: 20),
        Text(
          'Активных: ${records.where((r) => !r.cancelled).length} · отменено: ${records.where((r) => r.cancelled).length}',
          style: tx(14, color: C.muted),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.people_outline, color: C.green, size: 36),
                const SizedBox(height: 16),
                Text(
                  'Первые участники ещё впереди',
                  style: tx(22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Откройте опубликованное мероприятие как пользователь и подтвердите запись. Затем вернитесь в кабинет организатора.',
                  style: tx(14, color: C.muted),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => openSection(1),
                  child: const Text('К мероприятиям'),
                ),
              ],
            ),
          ),
        for (final r in records.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              key: ValueKey('organizer-registration-${r.id}'),
              padding: 20,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final identity = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Tag(
                            r.cancelledByEvent
                                ? 'Событие отменено'
                                : r.cancelled
                                ? 'Отменена'
                                : 'Записан',
                            green: !r.cancelled,
                          ),
                          Text(r.id, style: tx(13, color: C.muted)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r.participantName,
                        style: tx(20, weight: FontWeight.w600),
                      ),
                      Text(r.participantEmail, style: tx(13, color: C.muted)),
                    ],
                  );
                  final participation = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (store.byId(r.event.id) ?? r.event).title,
                        style: tx(16, weight: FontWeight.w600),
                      ),
                      Text(
                        (store.byId(r.event.id) ?? r.event).date,
                        style: tx(13, color: C.muted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${r.ticket.name} · ${discoveryMoney(r.ticket.price)}',
                        style: tx(14),
                      ),
                      Text(
                        r.ticket.price == 0
                            ? 'Бесплатная регистрация'
                            : 'Демо-регистрация · оплата не проводилась',
                        style: tx(12, color: C.muted),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identity,
                        const SizedBox(height: 16),
                        participation,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: identity),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.only(left: 24),
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: C.line)),
                          ),
                          child: participation,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class OrganizerEditor extends StatefulWidget {
  const OrganizerEditor({
    required this.draft,
    required this.store,
    required this.onBack,
    required this.onPublished,
    super.key,
  });
  final EventDraft draft;
  final EventsStore store;
  final VoidCallback onBack;
  final ValueChanged<MontasEvent> onPublished;
  @override
  State<OrganizerEditor> createState() => OrganizerEditorState();
}

class OrganizerEditorState extends State<OrganizerEditor> {
  final fields = <String, TextEditingController>{};
  List<EventTicket> extraTickets = [];
  int nextTicketId = 1;
  int step = 0;
  late bool online;
  late String cover, category;
  String? notice;
  @override
  void initState() {
    super.initState();
    loadDraft();
  }

  @override
  void didUpdateWidget(OrganizerEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.id != widget.draft.id) {
      releaseFields();
      loadDraft();
      step = 0;
      notice = null;
    }
  }

  void loadDraft() {
    final d = widget.draft;
    extraTickets = List.of(d.extraTickets);
    nextTicketId = 1;
    online = d.online;
    cover = d.coverId;
    category = d.category;
    final values = {
      'title': d.title,
      'description': d.description,
      'date': d.dateText,
      'start': d.start,
      'end': d.end,
      'venue': d.venue,
      'speakers': d.speakers,
      'program': d.program,
      'ticket': d.ticketName,
      'price': d.priceText,
      'capacity': d.capacityText,
      'includes': d.includes,
      'cancel': d.cancelUntil,
      'audience': d.audience,
      'outcomes': d.outcomes,
      'preparation': d.preparation,
    };
    for (final e in values.entries) {
      fields[e.key] = TextEditingController(text: e.value);
    }
  }

  void releaseFields() {
    for (final c in fields.values) {
      c.dispose();
    }
    fields.clear();
  }

  @override
  void dispose() {
    releaseFields();
    super.dispose();
  }

  String value(String key) => fields[key]!.text.trim();
  EventDraft snapshot() => EventDraft(
    id: widget.draft.id,
    baseEvent: widget.draft.baseEvent,
    title: value('title'),
    description: value('description'),
    dateText: value('date'),
    start: value('start'),
    end: value('end'),
    online: online,
    venue: value('venue'),
    category: category,
    speakers: value('speakers'),
    program: value('program'),
    ticketName: value('ticket'),
    priceText: value('price'),
    capacityText: value('capacity'),
    includes: value('includes'),
    cancelUntil: value('cancel'),
    coverId: cover,
    extraTickets: List.unmodifiable(extraTickets),
    audience: value('audience'),
    outcomes: value('outcomes'),
    preparation: value('preparation'),
  );
  void save() {
    widget.store.saveDraft(snapshot());
  }

  Future<void> editExtra([EventTicket? original]) async {
    var id = original?.id ?? 'extra-${nextTicketId++}';
    while (original == null && extraTickets.any((t) => t.id == id)) {
      id = 'extra-${nextTicketId++}';
    }
    final ticket = await editTicketDialog(context, id, initial: original);
    if (ticket == null || !mounted) return;
    setState(() {
      if (original == null) {
        extraTickets.add(ticket);
      } else {
        extraTickets[extraTickets.indexOf(original)] = ticket;
      }
    });
    save();
  }

  void changeStep(int next) {
    FocusManager.instance.primaryFocus?.unfocus();
    save();
    setState(() {
      step = next;
      notice = null;
    });
  }

  Future<void> publish() async {
    final reviewed = snapshot();
    if (reviewed.errors.isNotEmpty) {
      setState(() => step = 3);
      return;
    }
    final updating = reviewed.baseEvent != null;
    final changes = updating
        ? eventChanges(reviewed.baseEvent!, reviewed.toEvent())
        : <String>[];
    if (updating && changes.isEmpty) {
      setState(() => notice = 'Нет изменений для публикации.');
      return;
    }
    widget.store.saveDraft(reviewed);
    final confirmed = await discoveryDialog<bool>(
      context,
      updating ? 'Опубликовать изменения?' : 'Опубликовать мероприятие?',
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(reviewed.title, style: tx(21, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            '${reviewed.dateText} · ${reviewed.start}–${reviewed.end} · МСК\n${reviewed.venue}',
            style: tx(15),
          ),
          const SizedBox(height: 16),
          Text(
            updating
                ? 'Изменения увидят пользователи. Уведомления появятся у ${widget.store.attendees(reviewed.id).length} участников. Исходные билеты и условия их приобретения сохранятся.'
                : 'Событие появится в афише личного кабинета. Пользователь сможет записаться, а вы увидите его в участниках.',
            style: tx(14, color: C.muted),
          ),
          const SizedBox(height: 20),
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(change, style: tx(14)),
            ),
          PrimaryButton(
            updating ? 'Опубликовать и уведомить' : 'Опубликовать в афише',
            () => Navigator.pop(ctx, true),
            key: const ValueKey('organizer-confirm-publish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Вернуться к проверке'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final event = widget.store.publish(reviewed);
    if (event == null) {
      setState(
        () => notice =
            'Черновик изменился. Проверьте данные и повторите публикацию.',
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Мероприятие опубликовано и доступно в афише'),
      ),
    );
    widget.onPublished(event);
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    String? hint,
    bool number = false,
    int? limit,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      key: ValueKey('organizer-field-$key'),
      controller: fields[key],
      minLines: lines,
      maxLines: lines,
      maxLength: limit,
      keyboardType: number
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (_) {
        if (notice != null) setState(() => notice = null);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = snapshot();
    return DiscoveryLayout(
      id: 'organizer-editor-${d.id}-$step',
      maxWidth: 960,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              save();
              widget.onBack();
            },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Мои мероприятия'),
          ),
        ),
        const SizedBox(height: 12),
        DiscoveryHeading(
          d.baseEvent == null
              ? 'ОРГАНИЗАТОР · ЧЕРНОВИК'
              : 'ОРГАНИЗАТОР · ИЗМЕНЕНИЯ',
          d.baseEvent == null
              ? 'Подготовим вашу встречу'
              : 'Редактирование мероприятия',
          d.baseEvent == null
              ? 'Заполните основные сведения и проверьте, как событие увидят участники.'
              : 'Пока вы готовите изменения, участникам доступна предыдущая опубликованная версия.',
        ),
        DiscoveryTabs(
          id: 'organizer-editor',
          labels: const [
            '1. О событии',
            '2. Программа',
            '3. Участие',
            '4. Проверка',
          ],
          selected: step,
          onSelect: changeStep,
        ),
        if (step != 3)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (step == 0) ...[
                  Text('О событии', style: tx(23, weight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  field(
                    'title',
                    'Название *',
                    hint: 'Например, вечер о здоровом сне',
                    limit: 120,
                  ),
                  field(
                    'description',
                    'Описание *',
                    lines: 4,
                    hint: 'Для кого встреча и что участники узнают',
                    limit: 3000,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Категория'),
                    items:
                        [
                              'Открытая встреча',
                              'Лекция и практика',
                              'Клубная практика',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => category = v!),
                  ),
                  const SizedBox(height: 20),
                  field('date', 'Дата · ДД.ММ.ГГГГ *', hint: '30.10.2026'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: field('start', 'Начало · МСК *', hint: '19:00'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: field('end', 'Окончание · МСК *', hint: '20:30'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Онлайн'),
                        selected: online,
                        onSelected: d.baseEvent != null
                            ? null
                            : (_) => setState(() {
                                online = true;
                                fields['venue']!.text = 'Онлайн · в MONTAS';
                              }),
                      ),
                      ChoiceChip(
                        label: const Text('В Москве'),
                        selected: !online,
                        onSelected: d.baseEvent != null
                            ? null
                            : (_) => setState(() {
                                online = false;
                                fields['venue']!.text = '';
                              }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  field(
                    'venue',
                    d.baseEvent != null
                        ? 'Площадка и доступ *'
                        : online
                        ? 'Онлайн-площадка *'
                        : 'Площадка и адрес в Москве *',
                    hint: online
                        ? 'Название платформы'
                        : 'Название зала, улица и дом',
                  ),
                  Text(
                    'Обложка анонса',
                    style: tx(16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Выберите одну из подготовленных иллюстраций.',
                    style: tx(13, color: C.muted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in [
                        ('sleep-lab', 'Лекция'),
                        ('analysis', 'Обсуждение'),
                        ('recovery', 'Практика'),
                      ])
                        SizedBox(
                          width: 132,
                          child: InkWell(
                            key: ValueKey('organizer-cover-${item.$1}'),
                            onTap: () => setState(() => cover = item.$1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cover == item.$1 ? C.green : C.line,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: Image.asset(
                                        'assets/events/${item.$1}-v1.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${cover == item.$1 ? "✓ " : ""}${item.$2}',
                                    style: tx(12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (step == 1) ...[
                  Text(
                    'Программа и спикеры',
                    style: tx(23, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Каждый пункт программы и каждого спикера укажите с новой строки.',
                    style: tx(14, color: C.muted),
                  ),
                  const SizedBox(height: 20),
                  field(
                    'speakers',
                    'Кто проводит встречу *',
                    lines: 3,
                    hint: 'Анна Волкова · терапевт',
                    limit: 1000,
                  ),
                  field(
                    'program',
                    'Программа *',
                    lines: 6,
                    hint:
                        '19:00 · Знакомство\n19:15 · Основная часть\n20:00 · Вопросы',
                    limit: 3000,
                  ),
                ],
                if (step == 2 && d.baseEvent != null) ...[
                  Text(
                    'Условия билетов сохранены',
                    style: tx(23, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Редактирование программы не меняет формат, цену, вместимость и условия уже оформленных билетов.',
                    style: tx(14, color: C.muted),
                  ),
                  for (final ticket in d.baseEvent!.tickets)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        '${ticket.name}\n${discoveryMoney(ticket.price)} · ${ticket.capacity} мест\n${ticket.includes}\nОтмена: ${ticket.cancelUntil}',
                        style: tx(14),
                      ),
                    ),
                ],
                if (step == 1) ...[
                  field('audience', 'Для кого встреча', lines: 3, limit: 1000),
                  field(
                    'outcomes',
                    'Что получат участники',
                    lines: 3,
                    limit: 1000,
                  ),
                  field(
                    'preparation',
                    'Как подготовиться',
                    lines: 3,
                    limit: 1000,
                  ),
                ],
                if (step == 2 && d.baseEvent == null) ...[
                  Text(
                    'Условия участия',
                    style: tx(23, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Основной формат и до пяти дополнительных. Бесплатное участие: цена 0 ₽.',
                    style: tx(14, color: C.muted),
                  ),
                  const SizedBox(height: 20),
                  field('ticket', 'Название билета *', limit: 100),
                  field('price', 'Цена, ₽ *', number: true),
                  field('capacity', 'Количество мест *', number: true),
                  field(
                    'includes',
                    'Что входит в участие *',
                    lines: 3,
                    limit: 1000,
                  ),
                  field('cancel', 'Условия отмены *', lines: 2, limit: 500),
                  for (final t in extraTickets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Surface(
                        color: C.soft,
                        padding: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: tx(18, weight: FontWeight.w600),
                            ),
                            Text(
                              '${t.online ? "Онлайн" : "Очно"} · ${discoveryMoney(t.price)} · ${t.capacity} мест',
                              style: tx(14),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => editExtra(t),
                                  child: const Text('Изменить формат'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => extraTickets.remove(t));
                                    save();
                                  },
                                  child: const Text('Удалить формат'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (extraTickets.length < 5)
                    OutlinedButton.icon(
                      key: const ValueKey('organizer-add-ticket'),
                      onPressed: () => editExtra(),
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить формат участия'),
                    ),
                  const SizedBox(height: 16),
                  const Tag('Демо · без реальной оплаты'),
                ],
              ],
            ),
          ),
        if (step == 3) ...[
          if (d.errors.isNotEmpty)
            Surface(
              color: C.soft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Перед публикацией заполните',
                    style: tx(20, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  for (final error in d.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $error', style: tx(14)),
                    ),
                ],
              ),
            )
          else
            DiscoveryColumns(
              main: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.asset(
                          'assets/events/${d.coverId}-v1.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(d.title, style: tx(28, weight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(d.description, style: tx(15)),
                    const Divider(height: 32),
                    Text('Программа', style: tx(20, weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(d.program, style: tx(14, height: 1.8)),
                    const SizedBox(height: 20),
                    Text(
                      'Кто проводит',
                      style: tx(20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(d.speakers, style: tx(14)),
                  ],
                ),
              ),
              aside: Surface(
                color: C.soft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Tag('Предпросмотр · не опубликовано'),
                    const SizedBox(height: 20),
                    Text(
                      d.toEvent().date,
                      style: tx(20, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(d.venue, style: tx(14)),
                    const Divider(height: 32),
                    Text(
                      'от ${discoveryMoney(d.toEvent().price)}',
                      style: tx(24, weight: FontWeight.w600),
                    ),
                    Text(
                      d.baseEvent == null
                          ? '${1 + d.extraTickets.length} формата участия · ${int.parse(d.capacityText) + d.extraTickets.fold<int>(0, (n, t) => n + t.capacity)} мест'
                          : '${d.baseEvent!.tickets.length} формата · ${d.baseEvent!.format}\nУсловия билетов без изменений',
                      style: tx(14),
                    ),
                    const SizedBox(height: 12),
                    Text(d.includes, style: tx(14)),
                    const SizedBox(height: 12),
                    Text(
                      'Отмена: ${d.cancelUntil}',
                      style: tx(13, color: C.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(notice!, style: tx(14, color: C.green)),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (step > 0)
              OutlinedButton(
                onPressed: () => changeStep(step - 1),
                child: const Text('Назад'),
              ),
            OutlinedButton(
              key: const ValueKey('organizer-save'),
              onPressed: () {
                save();
                setState(() => notice = 'Черновик сохранён в этой демо-сессии');
              },
              child: const Text('Сохранить черновик'),
            ),
            if (step < 3)
              FilledButton(
                key: const ValueKey('organizer-next'),
                onPressed: () => changeStep(step + 1),
                child: const Text('Продолжить'),
              )
            else
              FilledButton(
                key: const ValueKey('organizer-publish'),
                onPressed: d.errors.isEmpty ? publish : null,
                child: const Text('Опубликовать'),
              ),
          ],
        ),
      ],
    );
  }
}
