part of 'main.dart';

/// A standalone demonstration with its own in-memory event data.
class OrganizerDemo extends StatefulWidget {
  const OrganizerDemo({this.seedDemo = false, super.key});
  final bool seedDemo;

  @override
  State<OrganizerDemo> createState() => _OrganizerDemoState();
}

class _OrganizerDemoState extends State<OrganizerDemo> {
  final store = EventsStore();
  final catalogKey = GlobalKey<EventsScreenState>();
  bool catalogVisible = false;
  bool todayVisible = true;

  void showCatalog() {
    catalogKey.currentState?.showCatalog();
    setState(() => catalogVisible = true);
  }

  void openEvent(MontasEvent event) {
    catalogKey.currentState?.open(event);
    setState(() => catalogVisible = true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.seedDemo) store.seedParticipants();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (catalogVisible || !todayVisible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Wrap(
                spacing: 24,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('MONTAS', style: tx(24, weight: FontWeight.w800)),
                  Text('Мероприятия', style: tx(14, color: C.muted)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('organizer-demo-workspace'),
                        label: const Text('Кабинет организатора'),
                        selected: !catalogVisible,
                        onSelected: (_) =>
                            setState(() => catalogVisible = false),
                      ),
                      ChoiceChip(
                        key: const ValueKey('organizer-demo-catalog'),
                        label: const Text('Каталог мероприятий'),
                        selected: catalogVisible,
                        onSelected: (_) => showCatalog(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: catalogVisible ? 1 : 0,
              children: [
                OrganizerWorkspace(
                  store: store,
                  onPublicEvent: openEvent,
                  onCatalog: showCatalog,
                  onTodayChanged: (value) =>
                      setState(() => todayVisible = value),
                ),
                EventsScreen(key: catalogKey, store: store),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
