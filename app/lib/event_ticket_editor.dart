part of 'main.dart';

bool validEventTicket(EventTicket t) =>
    t.id.trim().isNotEmpty &&
    t.name.trim().isNotEmpty &&
    t.name.length <= 100 &&
    t.price >= 0 &&
    t.price <= 1000000 &&
    t.capacity > 0 &&
    t.capacity <= 10000 &&
    t.includes.trim().isNotEmpty &&
    t.includes.length <= 1000 &&
    t.cancelUntil.trim().isNotEmpty &&
    t.cancelUntil.length <= 500;

Future<EventTicket?> editTicketDialog(
  BuildContext context,
  String id, {
  EventTicket? initial,
}) => showDialog<EventTicket>(
  context: context,
  builder: (_) => EventTicketDialog(id: id, initial: initial),
);

class EventTicketDialog extends StatefulWidget {
  const EventTicketDialog({required this.id, this.initial, super.key});
  final String id;
  final EventTicket? initial;
  @override
  State<EventTicketDialog> createState() => _EventTicketDialogState();
}

class _EventTicketDialogState extends State<EventTicketDialog> {
  late final name = TextEditingController(
    text: widget.initial?.name ?? 'Онлайн-участие',
  );
  late final price = TextEditingController(
    text: '${widget.initial?.price ?? 0}',
  );
  late final capacity = TextEditingController(
    text: '${widget.initial?.capacity ?? 30}',
  );
  late final includes = TextEditingController(
    text: widget.initial?.includes ?? 'Участие во встрече и материалы',
  );
  late final cancel = TextEditingController(
    text: widget.initial?.cancelUntil ?? 'До начала события',
  );
  late bool online = widget.initial?.online ?? true;
  String? error;
  @override
  void dispose() {
    for (final c in [name, price, capacity, includes, cancel]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    final ticket = EventTicket(
      widget.id,
      name.text.trim(),
      int.tryParse(price.text) ?? -1,
      online,
      includes.text.trim(),
      capacity: int.tryParse(capacity.text) ?? -1,
      cancelUntil: cancel.text.trim(),
    );
    if (!validEventTicket(ticket)) {
      setState(
        () =>
            error = 'Заполните все поля. Цена: 0–1 000 000 ₽, мест: 1–10 000.',
      );
      return;
    }
    Navigator.pop(context, ticket);
  }

  Widget field(
    String key,
    String label,
    TextEditingController controller, {
    bool number = false,
    int max = 100,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      key: ValueKey('ticket-input-$key'),
      controller: controller,
      maxLength: max,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null
                  ? 'Новый формат участия'
                  : 'Формат участия',
              style: tx(24, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Цена показывается для примера. Реальной оплаты нет.',
              style: tx(13, color: C.muted),
            ),
            const SizedBox(height: 20),
            field('name', 'Название', name),
            Wrap(
              spacing: 8,
              children: [
                for (final v in [true, false])
                  ChoiceChip(
                    label: Text(v ? 'Онлайн' : 'Очно'),
                    selected: online == v,
                    onSelected: (_) => setState(() => online = v),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            field(
              'price',
              'Цена, ₽ (0 — бесплатно)',
              price,
              number: true,
              max: 7,
            ),
            field(
              'capacity',
              'Количество мест',
              capacity,
              number: true,
              max: 5,
            ),
            field('includes', 'Что входит', includes, max: 1000),
            field('cancel', 'Условия отмены', cancel, max: 500),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error!, style: tx(14, color: Colors.red.shade800)),
              ),
            FilledButton(
              key: const ValueKey('ticket-save'),
              onPressed: submit,
              child: const Text('Сохранить формат'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    ),
  );
}

extension EventWorkspaceOperations on EventsStore {
  bool addTicket(MontasEvent reviewed, EventTicket ticket) {
    if (byId(reviewed.id) != reviewed ||
        isCancelled(reviewed.id) ||
        _drafts.any((d) => d.id == reviewed.id) ||
        !validEventTicket(ticket) ||
        reviewed.tickets.length >= 6 ||
        reviewed.tickets.any((t) => t.id == ticket.id)) {
      return false;
    }
    final next = MontasEvent(
      id: reviewed.id,
      title: reviewed.title,
      day: reviewed.day,
      time: reviewed.time,
      category: reviewed.category,
      description: reviewed.description,
      speakers: reviewed.speakers,
      agenda: reviewed.agenda,
      tickets: List.unmodifiable([...reviewed.tickets, ticket]),
      venue: reviewed.venue,
      icon: reviewed.icon,
      startsAt: reviewed.startsAt,
      coverId: reviewed.coverId,
      audience: reviewed.audience,
      outcomes: reviewed.outcomes,
      preparation: reviewed.preparation,
    );
    _events[_events.indexOf(reviewed)] = next;
    _history.add(
      EventChange(reviewed, next, [
        'Добавлен формат участия «${ticket.name}».',
      ]),
    );
    _emit();
    return true;
  }
}

class EventAudienceInfo extends StatelessWidget {
  const EventAudienceInfo({required this.event, super.key});
  final MontasEvent event;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in [
          (
            'Для кого',
            event.audience.isEmpty
                ? 'Для тех, кто интересуется темой «${event.category}» и хочет задать вопросы ведущему.'
                : event.audience,
          ),
          (
            'Что получите',
            event.outcomes.isEmpty
                ? 'Разбор темы с экспертом, практические примеры и ответы на вопросы. Состав участия указан в выбранном билете.'
                : event.outcomes,
          ),
          (
            'Как подготовиться',
            event.preparation.isEmpty
                ? 'Подготовьте вопросы. Для онлайн-встречи проверьте связь; для очной — адрес и время начала.'
                : event.preparation,
          ),
        ]) ...[
          Text(item.$1, style: tx(19, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(item.$2, style: tx(14)),
          const SizedBox(height: 20),
        ],
      ],
    ),
  );
}
