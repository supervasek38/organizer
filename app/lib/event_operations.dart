part of 'main.dart';

class EventNotice {
  EventNotice(
    this.id,
    this.eventId,
    this.userId,
    this.recipient,
    this.title,
    this.body,
  );
  final String id, eventId, userId, recipient, title, body;
  bool read = false;
}

class EventMaterial {
  EventMaterial(this.id, this.eventId, this.file);
  final String id, eventId;
  final LocalFile file;
  bool published = false;
}

class EventChange {
  const EventChange(this.before, this.after, this.summary);
  final MontasEvent before, after;
  final List<String> summary;
}

List<String> eventChanges(MontasEvent a, MontasEvent b) => [
  if (a.title != b.title) 'Название: ${a.title} → ${b.title}',
  if ((a.startsAt ?? DateTime(2026, 10, a.day)) != b.startsAt ||
      a.time != b.time)
    'Дата и время: ${a.date} → ${b.date}',
  if (a.venue != b.venue) 'Площадка: ${a.venue} → ${b.venue}',
  if (a.description != b.description) 'Обновлено описание встречи.',
  if (a.speakers != b.speakers) 'Спикеры: ${a.speakers} → ${b.speakers}',
  if (a.agenda.join('\n') != b.agenda.join('\n'))
    'Программа: ${a.agenda.join('; ')} → ${b.agenda.join('; ')}',
  if (a.category != b.category) 'Категория: ${a.category} → ${b.category}',
  if ((a.coverId ?? a.id) != b.coverId) 'Обновлена обложка мероприятия.',
  if (a.audience != b.audience ||
      a.outcomes != b.outcomes ||
      a.preparation != b.preparation)
    'Обновлены информация для участников и подготовка к встрече.',
];

extension EventOperations on EventsStore {
  MontasEvent? byId(String id) => _events.where((e) => e.id == id).firstOrNull;
  bool isCancelled(String id) => _cancellations.containsKey(id);
  String? cancellationReason(String id) => _cancellations[id];
  List<EventRegistration> get personalRegistrations =>
      List.unmodifiable(_registrations.where((r) => r.userId == 'personal'));
  List<EventRegistration> attendees(String id) => List.unmodifiable(
    _registrations.where((r) => r.event.id == id && !r.cancelled),
  );
  List<EventNotice> get notices => List.unmodifiable(_notices);
  List<EventNotice> get personalNotices =>
      List.unmodifiable(_notices.where((n) => n.userId == 'personal'));
  List<EventChange> changesFor(String id) =>
      List.unmodifiable(_history.where((h) => h.after.id == id));
  List<EventMaterial> materialsFor(String id) =>
      List.unmodifiable(_materials.where((m) => m.eventId == id));

  EventDraft? editPublished(MontasEvent event) {
    if (byId(event.id) != event || isCancelled(event.id)) return null;
    final existing = _drafts.where((d) => d.id == event.id).firstOrNull;
    if (existing != null) return existing;
    final date = event.startsAt ?? DateTime(2026, 10, event.day);
    final ticket = event.tickets.first;
    final draft = EventDraft(
      id: event.id,
      baseEvent: event,
      title: event.title,
      description: event.description,
      dateText:
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
      start: event.time.split('–').first,
      end: event.time.split('–').last,
      online: ticket.online,
      venue: event.venue,
      category: event.category,
      speakers: event.speakers,
      program: event.agenda.join('\n'),
      ticketName: ticket.name,
      priceText: '${ticket.price}',
      capacityText: '${ticket.capacity}',
      includes: ticket.includes,
      cancelUntil: ticket.cancelUntil,
      coverId: event.coverId ?? event.id,
      audience: event.audience,
      outcomes: event.outcomes,
      preparation: event.preparation,
    );
    _drafts.add(draft);
    _emit();
    return draft;
  }

  void _notifyParticipants(String eventId, String title, String body) {
    final seen = <String>{};
    for (final r in attendees(eventId)) {
      if (seen.add(r.userId)) {
        _notices.add(
          EventNotice(
            'N-${_notices.length + 1}',
            eventId,
            r.userId,
            r.participantName,
            title,
            body,
          ),
        );
      }
    }
  }

  void readNotice(EventNotice notice) {
    if (!_notices.contains(notice) ||
        notice.userId != 'personal' ||
        notice.read) {
      return;
    }
    notice.read = true;
    _emit();
  }

  bool cancelEvent(
    MontasEvent reviewed,
    String reason,
    List<String> reviewedAttendees,
  ) {
    if (byId(reviewed.id) != reviewed ||
        isCancelled(reviewed.id) ||
        reason.trim().isEmpty ||
        reason.length > 1000 ||
        attendees(reviewed.id).map((r) => r.id).join(',') !=
            reviewedAttendees.join(',')) {
      return false;
    }
    _cancellations[reviewed.id] = reason.trim();
    cancelEventPartnerships(reviewed.id);
    _notifyParticipants(
      reviewed.id,
      'Мероприятие отменено',
      '${reviewed.title}\n${reviewed.date}\nПричина: ${reason.trim()}\nЗапись отменена организатором. В демо деньги не списывались; реальный возврат не выполняется.',
    );
    for (final r in attendees(reviewed.id)) {
      r.cancelled = true;
      r.cancelledByEvent = true;
    }
    _drafts.removeWhere((d) => d.id == reviewed.id);
    _emit();
    return true;
  }

  EventMaterial? addMaterial(String eventId, LocalFile file) {
    file.validate();
    if (byId(eventId) == null || isCancelled(eventId)) return null;
    final material = EventMaterial('MAT-${_nextMaterial++}', eventId, file);
    _materials.add(material);
    _emit();
    return material;
  }

  bool publishMaterial(EventMaterial material) {
    if (!_materials.contains(material) ||
        material.published ||
        isCancelled(material.eventId)) {
      return false;
    }
    material.published = true;
    _notifyParticipants(
      material.eventId,
      'Новый материал мероприятия',
      'Доступен файл «${material.file.name}». Откройте событие → Материалы участника.',
    );
    _emit();
    return true;
  }

  bool canAccessMaterial(EventMaterial material) =>
      _materials.contains(material) &&
      material.published &&
      !isCancelled(material.eventId) &&
      active(material.eventId) != null;

  void seedParticipants() {
    if (_seeded) return;
    _seeded = true;
    final seeds = [
      (
        'sleep-lab',
        0,
        'personal',
        'Александр · демо-пользователь',
        'alexander@example.com',
        false,
      ),
      (
        'sleep-lab',
        1,
        'marina',
        'Марина Соколова · демо',
        'marina@example.com',
        false,
      ),
      (
        'sleep-lab',
        2,
        'oleg',
        'Олег Смирнов · демо',
        'oleg@example.com',
        false,
      ),
      (
        'analysis',
        0,
        'personal',
        'Александр · демо-пользователь',
        'alexander@example.com',
        false,
      ),
      (
        'analysis',
        0,
        'irina',
        'Ирина Белова · демо',
        'irina@example.com',
        true,
      ),
      (
        'recovery',
        0,
        'denis',
        'Денис Орлов · демо',
        'denis@example.com',
        false,
      ),
    ];
    for (final s in seeds) {
      final event = byId(s.$1)!;
      if (_registrations.any(
        (r) => r.event.id == event.id && r.userId == s.$3,
      )) {
        continue;
      }
      _registrations.add(
        EventRegistration(
          'EV-${(_registrations.length + 1).toString().padLeft(3, '0')}',
          event,
          event.tickets[s.$2],
          userId: s.$3,
          participantName: s.$4,
          participantEmail: s.$5,
        )..cancelled = s.$6,
      );
    }
    _emit();
  }
}

Future<void> showEventFile(BuildContext context, LocalFile file) async {
  await discoveryDialog<void>(
    context,
    file.name,
    (ctx) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (file.mime == 'text/plain')
          SelectableText(
            utf8.decode(file.bytes, allowMalformed: true),
            style: tx(14),
          )
        else if (file.mime.startsWith('image/'))
          Image.memory(
            file.bytes,
            height: 320,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'Не удалось отобразить изображение. Файл можно скачать.',
            ),
          )
        else
          const Text(
            'PDF можно открыть в отдельной вкладке браузера или скачать.',
          ),
        const SizedBox(height: 16),
        if (file.mime == 'application/pdf')
          OutlinedButton(
            onPressed: () {
              try {
                file_bridge.preview(file);
              } catch (_) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Просмотр PDF доступен в веб-версии.'),
                  ),
                );
              }
            },
            child: const Text('Открыть PDF'),
          ),
        OutlinedButton.icon(
          onPressed: () {
            try {
              file_bridge.download(file.name, file.mime, file.bytes);
            } catch (_) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Скачивание доступно в веб-версии.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.download_outlined),
          label: const Text('Скачать файл'),
        ),
      ],
    ),
  );
}

class EventNoticeList extends StatelessWidget {
  const EventNoticeList({
    required this.store,
    this.onOpen,
    this.organizer = false,
    this.eventId,
    super.key,
  });
  final EventsStore store;
  final bool organizer;
  final String? eventId;
  final ValueChanged<MontasEvent>? onOpen;
  @override
  Widget build(BuildContext context) {
    final records = (organizer ? store.notices : store.personalNotices)
        .where((n) => eventId == null || n.eventId == eventId)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (records.isEmpty)
          Surface(
            child: Text(
              organizer
                  ? 'Уведомлений пока нет. Они появятся после публикации изменений, материалов или отмены события.'
                  : 'Новых сообщений от организаторов пока нет.',
              style: tx(15, color: C.muted),
            ),
          ),
        for (final notice in records.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              key: ValueKey('event-notice-${notice.id}'),
              padding: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(
                    organizer
                        ? 'Создано в демо-кабинете'
                        : notice.read
                        ? 'Прочитано'
                        : 'Новое',
                    green: !notice.read,
                  ),
                  const SizedBox(height: 12),
                  Text(notice.title, style: tx(20, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    store.byId(notice.eventId)!.title,
                    style: tx(15, weight: FontWeight.w500),
                  ),
                  if (organizer)
                    Text(
                      'Получатель: ${notice.recipient}',
                      style: tx(13, color: C.muted),
                    ),
                  const SizedBox(height: 12),
                  Text(notice.body, style: tx(14)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (onOpen != null)
                        OutlinedButton(
                          onPressed: () {
                            if (!organizer) store.readNotice(notice);
                            onOpen!(store.byId(notice.eventId)!);
                          },
                          child: const Text('Открыть мероприятие'),
                        ),
                      if (!organizer && !notice.read)
                        TextButton(
                          onPressed: () => store.readNotice(notice),
                          child: const Text('Отметить прочитанным'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ParticipantMaterials extends StatelessWidget {
  const ParticipantMaterials({
    required this.store,
    required this.eventId,
    super.key,
  });
  final EventsStore store;
  final String eventId;
  @override
  Widget build(BuildContext context) {
    final records = store
        .materialsFor(eventId)
        .where((m) => store.canAccessMaterial(m))
        .toList();
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Материалы участника', style: tx(22, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (store.isCancelled(eventId))
            Text(
              'Событие отменено. Доступ к материалам закрыт.',
              style: tx(14, color: C.muted),
            )
          else if (store.active(eventId) == null)
            Text(
              'Материалы будут доступны после регистрации на мероприятие.',
              style: tx(14, color: C.muted),
            )
          else if (records.isEmpty)
            Text(
              'Организатор пока не опубликовал материалы.',
              style: tx(14, color: C.muted),
            ),
          for (final material in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.file.name,
                    style: tx(15, weight: FontWeight.w600),
                  ),
                  OutlinedButton(
                    key: ValueKey('participant-material-${material.id}'),
                    onPressed: () {
                      if (store.canAccessMaterial(material)) {
                        showEventFile(context, material.file);
                      }
                    },
                    child: const Text('Посмотреть и скачать'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class EventOperationsPanel extends StatefulWidget {
  const EventOperationsPanel({
    required this.store,
    required this.eventId,
    required this.onBack,
    this.embedded = false,
    super.key,
  });
  final EventsStore store;
  final String eventId;
  final VoidCallback onBack;
  final bool embedded;
  @override
  State<EventOperationsPanel> createState() => _EventOperationsPanelState();
}

class _EventOperationsPanelState extends State<EventOperationsPanel> {
  bool picking = false;
  String? error;
  Future<void> upload() async {
    if (picking) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final file = await file_bridge.pick();
      if (file == null || !mounted) return;
      if (widget.store.addMaterial(widget.eventId, file) == null) {
        setState(() => error = 'Событие уже отменено. Материал не добавлен.');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Не удалось загрузить файл. Попробуйте ещё раз.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> publishFile(EventMaterial material) async {
    final yes = await discoveryDialog<bool>(
      context,
      'Открыть материал участникам?',
      (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(material.file.name, style: tx(18, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            'Файл будет доступен действующим и будущим участникам этого события. Сейчас уведомление появится у ${widget.store.attendees(widget.eventId).length} участников. Файл хранится только в этой вкладке.',
            style: tx(14),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            'Опубликовать материал',
            () => Navigator.pop(ctx, true),
            key: const ValueKey('material-confirm-publish'),
          ),
        ],
      ),
    );
    if (yes == true && mounted && !widget.store.publishMaterial(material)) {
      setState(
        () => error =
            'Публикация недоступна: событие отменено или файл уже опубликован.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final event = widget.store.byId(widget.eventId)!;
      final cancelled = widget.store.isCancelled(event.id);
      return DiscoveryLayout(
        id: 'organizer-materials-${event.id}',
        children: [
          if (!widget.embedded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('К мероприятиям'),
              ),
            ),
          if (!widget.embedded)
            DiscoveryHeading(
              'ОРГАНИЗАТОР · МАТЕРИАЛЫ И ИСТОРИЯ',
              event.title,
              'Файлы встречи и опубликованные изменения.',
            ),
          if (cancelled)
            Surface(
              color: C.soft,
              child: Text(
                'Событие отменено. ${widget.store.cancellationReason(event.id)}',
                style: tx(16),
              ),
            ),
          const SizedBox(height: 16),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Материалы встречи',
                  style: tx(22, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF, PNG, JPG или TXT · до 10 МБ. После загрузки файл виден только вам, пока вы не откроете его участникам.',
                  style: tx(14, color: C.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('organizer-upload'),
                  onPressed: cancelled || picking ? null : upload,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    picking ? 'Выберите файл…' : 'Загрузить материал',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: tx(14, color: Colors.red.shade700),
                    ),
                  ),
                if (widget.store.materialsFor(event.id).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'Материалов пока нет. Добавьте презентацию или памятку.',
                      style: tx(14, color: C.muted),
                    ),
                  ),
                for (final material in widget.store.materialsFor(event.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          material.file.name,
                          style: tx(16, weight: FontWeight.w600),
                        ),
                        Text(
                          '${(material.file.bytes.length / 1024).toStringAsFixed(1)} КБ · ${material.published ? "Открыт участникам" : "Только организатору"}',
                          style: tx(13, color: C.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () =>
                                  showEventFile(context, material.file),
                              child: const Text('Посмотреть файл'),
                            ),
                            if (!material.published && !cancelled)
                              FilledButton(
                                key: ValueKey(
                                  'material-publish-${material.id}',
                                ),
                                onPressed: () => publishFile(material),
                                child: const Text('Открыть участникам'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('История изменений', style: tx(22, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (widget.store.changesFor(event.id).isEmpty)
            Text(
              'Опубликованных изменений пока нет.',
              style: tx(14, color: C.muted),
            ),
          for (final change in widget.store.changesFor(event.id).reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Surface(
                child: Text(change.summary.join('\n'), style: tx(14)),
              ),
            ),
          if (cancelled)
            Surface(
              child: Text(
                'Отмена события: ${widget.store.cancellationReason(event.id)}',
                style: tx(14),
              ),
            ),
        ],
      );
    },
  );
}
