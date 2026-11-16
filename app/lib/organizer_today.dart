part of 'main.dart';

class OrganizerTodayScreen extends StatelessWidget {
  const OrganizerTodayScreen({
    required this.store,
    required this.onSection,
    required this.onCreate,
    required this.onManage,
    required this.onParticipants,
    required this.onPartners,
    required this.onDraft,
    this.onPublic,
    this.onCatalog,
    super.key,
  });
  final EventsStore store;
  final ValueChanged<int> onSection;
  final VoidCallback onCreate;
  final ValueChanged<MontasEvent> onManage, onParticipants, onPartners;
  final ValueChanged<EventDraft> onDraft;
  final ValueChanged<MontasEvent>? onPublic;
  final VoidCallback? onCatalog;
  List<MontasEvent> get upcoming {
    final anchor = DateTime(2026, 10, 20);
    final result = store.events
        .where(
          (e) =>
              !store.isCancelled(e.id) &&
              !(e.startsAt ?? DateTime(2026, 10, e.day)).isBefore(anchor),
        )
        .toList();
    result.sort((a, b) {
      final date = (a.startsAt ?? DateTime(2026, 10, a.day)).compareTo(
        b.startsAt ?? DateTime(2026, 10, b.day),
      );
      return date != 0 ? date : a.time.compareTo(b.time);
    });
    return result;
  }

  Widget panel(
    Widget child, {
    Color color = Colors.white,
    double padding = 24,
  }) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(OrganizerStyle.radius),
      border: color == Colors.white ? Border.all(color: C.line) : null,
      boxShadow: color == Colors.white
          ? const [
              BoxShadow(
                color: Color(0x07061713),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: child,
  );

  Widget button(
    String label,
    VoidCallback? action, {
    String? id,
    bool accent = false,
    bool inverse = false,
    IconData? icon,
  }) => FilledButton(
    key: id == null ? null : ValueKey(id),
    onPressed: action,
    style: FilledButton.styleFrom(
      backgroundColor: accent
          ? C.lime
          : inverse
          ? Colors.white
          : C.ink,
      foregroundColor: accent || inverse ? C.ink : Colors.white,
      minimumSize: const Size(44, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: OrganizerStyle.text(15, weight: FontWeight.w600),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label)),
      ],
    ),
  );

  Widget link(
    String label,
    VoidCallback? action, {
    String? id,
    IconData icon = Icons.arrow_forward_rounded,
  }) => TextButton(
    key: id == null ? null : ValueKey(id),
    onPressed: action,
    style: TextButton.styleFrom(
      foregroundColor: C.ink,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: OrganizerStyle.text(13, weight: FontWeight.w500),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label)),
        const SizedBox(width: 8),
        Icon(icon, size: 18),
      ],
    ),
  );

  Widget metric(String title, int number, String description, int section) =>
      Expanded(
        child: panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '$number',
                      style: OrganizerStyle.text(40, weight: FontWeight.w300),
                    ),
                  ),
                  IconButton(
                    tooltip: title,
                    onPressed: () => onSection(section),
                    icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
              ),
            ],
          ),
        ),
      );

  Widget featured(MontasEvent? event) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(colors: [C.ink, OrganizerStyle.darkEnd]),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final photo = event != null && box.maxWidth >= 560;
        final details = Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ближайшее мероприятие',
                style: OrganizerStyle.text(13, color: const Color(0xFFC3D8CC)),
              ),
              const SizedBox(height: 20),
              Text(
                event?.title ?? 'Ваша следующая встреча',
                style: OrganizerStyle.text(
                  24,
                  color: Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                event == null
                    ? 'Создайте мероприятие и пригласите участников.'
                    : '${event.date}\n${event.format}',
                style: OrganizerStyle.text(15, color: const Color(0xFFDDEAE2)),
              ),
              const SizedBox(height: 24),
              if (event != null) ...[
                button(
                  'Управление событием',
                  () => onManage(event),
                  accent: true,
                  id: 'today-featured-manage',
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 12),
                Text(
                  'Участников: ${store.attendees(event.id).length} · ${event.category}',
                  style: OrganizerStyle.text(
                    13,
                    color: const Color(0xFFC3D8CC),
                  ),
                ),
              ] else
                button(
                  'Создать мероприятие',
                  onCreate,
                  accent: true,
                  id: 'today-empty-create',
                  icon: Icons.add,
                ),
            ],
          ),
        );
        if (!photo) return details;
        return Row(
          children: [
            Expanded(flex: 6, child: details),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/events/${event.coverId ?? event.id}-v1.png',
                    height: 270,
                    fit: BoxFit.cover,
                    semanticLabel: 'Обложка мероприятия ${event.title}',
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget preparation(MontasEvent? event) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Подготовка',
          style: OrganizerStyle.text(20, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (store.drafts.isNotEmpty) ...[
          Text(
            'Вернитесь к черновику',
            style: OrganizerStyle.text(15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            store.drafts.first.title.isEmpty
                ? 'Новое мероприятие'
                : store.drafts.first.title,
            style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
          ),
          link(
            'Продолжить',
            () => onDraft(store.drafts.first),
            id: 'organizer-edit-${store.drafts.first.id}',
          ),
        ] else ...[
          Text(
            'Все события опубликованы',
            style: OrganizerStyle.text(15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Можно проверить программу и подготовить материалы для участников.',
            style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
          ),
          link('Открыть материалы', () => onSection(3)),
        ],
        const Divider(height: 28),
        Row(
          children: [
            const Icon(Icons.handshake_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Партнёры для события',
                style: OrganizerStyle.text(15, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          store.partnerRequests.isEmpty
              ? 'Найдите бренды, которым близка ваша аудитория.'
              : 'Запросов: ${store.partnerRequests.length}. Проверьте предложения и условия.',
          style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
        ),
        link(
          'Партнёрства',
          () => onSection(5),
          id: 'organizer-partners-summary',
        ),
      ],
    ),
  );

  Widget eventRow(MontasEvent event) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: panel(
      LayoutBuilder(
        builder: (context, box) {
          final small = box.maxWidth < 560;
          final date = event.startsAt ?? DateTime(2026, 10, event.day);
          final dateLabel = event.startsAt == null
              ? 'окт'
              : '${date.month.toString().padLeft(2, '0')} / ${date.year}';
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: C.canvas,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${date.day}',
                      style: OrganizerStyle.text(24, weight: FontWeight.w600),
                    ),
                    Text(
                      dateLabel,
                      style: OrganizerStyle.text(
                        12,
                        color: OrganizerStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: OrganizerStyle.text(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.time} · ${event.format}',
                      style: OrganizerStyle.text(
                        13,
                        color: OrganizerStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      store.isCancelled(event.id)
                          ? 'Событие отменено'
                          : 'Участников: ${store.attendees(event.id).length} · Опубликовано',
                      style: OrganizerStyle.text(
                        12,
                        color: OrganizerStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              link(
                'Участники',
                () => onParticipants(event),
                id: 'organizer-participants-${event.id}',
                icon: Icons.people_outline,
              ),
              link(
                'Управление',
                () => onManage(event),
                id: 'organizer-manage-${event.id}',
              ),
              link(
                'Страница',
                onPublic == null ? null : () => onPublic!(event),
                id: 'organizer-public-${event.id}',
                icon: Icons.north_east_rounded,
              ),
              if (!store.isCancelled(event.id))
                link(
                  'Нужны партнёры',
                  () => onPartners(event),
                  id: 'organizer-partners-${event.id}',
                  icon: Icons.handshake_outlined,
                ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 12),
              if (!small) const Divider(height: 1),
              if (!small) const SizedBox(height: 4),
              actions,
            ],
          );
        },
      ),
      padding: 20,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) {
      final wide = viewport.maxWidth >= 1050;
      final nearest = upcoming.firstOrNull;
      final content = Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('organizer-today-brand'),
              padding: EdgeInsets.all(wide ? 32 : 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final twoColumns = box.maxWidth >= 920;
                      final title = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сегодня организатора',
                            style: OrganizerStyle.text(
                              32,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Здравствуйте, Наталья. Всё для ваших ближайших встреч.',
                            style: OrganizerStyle.text(
                              15,
                              color: OrganizerStyle.muted,
                            ),
                          ),
                        ],
                      );
                      final create = button(
                        'Создать мероприятие',
                        onCreate,
                        id: 'organizer-create',
                        icon: Icons.add,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (box.maxWidth >= 780)
                            Row(
                              children: [
                                Expanded(child: title),
                                const SizedBox(width: 24),
                                create,
                              ],
                            )
                          else ...[
                            title,
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: create,
                            ),
                          ],
                          const SizedBox(height: 28),
                          if (twoColumns)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: featured(nearest)),
                                const SizedBox(width: 20),
                                Expanded(flex: 4, child: preparation(nearest)),
                              ],
                            )
                          else
                            featured(nearest),
                          const SizedBox(height: 20),
                          if (box.maxWidth >= 600)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                metric(
                                  'Опубликовано',
                                  store.events
                                      .where((e) => !store.isCancelled(e.id))
                                      .length,
                                  'Мероприятия в каталоге',
                                  1,
                                ),
                                const SizedBox(width: 16),
                                metric(
                                  'Участники',
                                  store.registrations
                                      .where((r) => !r.cancelled)
                                      .length,
                                  'Активные регистрации',
                                  2,
                                ),
                                const SizedBox(width: 16),
                                metric(
                                  'Черновики',
                                  store.drafts.length,
                                  'Можно продолжить',
                                  1,
                                ),
                              ],
                            )
                          else
                            panel(
                              Row(
                                children: [
                                  for (final item in [
                                    (
                                      'События',
                                      store.events
                                          .where(
                                            (e) => !store.isCancelled(e.id),
                                          )
                                          .length,
                                      1,
                                    ),
                                    (
                                      'Участники',
                                      store.registrations
                                          .where((r) => !r.cancelled)
                                          .length,
                                      2,
                                    ),
                                    ('Черновики', store.drafts.length, 1),
                                  ])
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => onSection(item.$3),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                '${item.$2}',
                                                style: OrganizerStyle.text(
                                                  32,
                                                  weight: FontWeight.w300,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.$1,
                                                style: OrganizerStyle.text(
                                                  12,
                                                  color: OrganizerStyle.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              padding: 16,
                            ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Ваши мероприятия',
                                  style: OrganizerStyle.text(
                                    24,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              link('Все', () => onSection(1)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (final event in store.events) eventRow(event),
                          if (store.events.isEmpty)
                            panel(
                              Text(
                                'Здесь появятся ваши опубликованные мероприятия.',
                                style: OrganizerStyle.text(15),
                              ),
                            ),
                          if (!twoColumns) ...[
                            const SizedBox(height: 16),
                            preparation(nearest),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'Демонстрационный кабинет · 20 октября 2026. Изменения сохраняются до перезагрузки.',
                            style: OrganizerStyle.text(
                              12,
                              color: OrganizerStyle.muted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      return OrganizerShell(
        store: store,
        selected: 0,
        title: 'Сегодня',
        onSection: onSection,
        onCatalog: onCatalog,
        child: content,
      );
    },
  );
}
