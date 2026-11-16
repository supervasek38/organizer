part of 'main.dart';

/// Shared visual language for the standalone organizer.
abstract final class OrganizerStyle {
  static const mint = Color(0xFFDEF8E2);
  static const muted = Color(0xFF5B6660);
  static const darkEnd = Color(0xFF086136);
  static const radius = 24.0;
  static TextStyle text(
    double size, {
    Color color = C.ink,
    FontWeight weight = FontWeight.w400,
  }) => tx(size, color: color, weight: weight, height: size >= 24 ? 1.2 : 1.45);
}

class OrganizerWordmark extends StatelessWidget {
  const OrganizerWordmark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MONTAS',
    image: true,
    child: ExcludeSemantics(
      child: SizedBox(
        width: 160,
        height: 34,
        child: FittedBox(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MONT',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w300,
                  fontSize: 56,
                  height: 64 / 56,
                  letterSpacing: 13.44,
                  color: C.ink,
                ),
              ),
              const SizedBox(width: 14),
              SvgPicture.asset('assets/brand/mark.svg', width: 40, height: 42),
              const SizedBox(width: 14),
              const Text(
                'S',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w300,
                  fontSize: 56,
                  height: 64 / 56,
                  letterSpacing: 13.44,
                  color: C.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class OrganizerShell extends StatelessWidget {
  const OrganizerShell({
    required this.store,
    required this.selected,
    required this.title,
    required this.onSection,
    required this.child,
    this.onCatalog,
    super.key,
  });
  final EventsStore store;
  final int selected;
  final String title;
  final ValueChanged<int> onSection;
  final VoidCallback? onCatalog;
  final Widget child;
  static const menu = [
    ('Сегодня', Icons.wb_sunny_outlined),
    ('Мои мероприятия', Icons.calendar_month_outlined),
    ('Участники', Icons.people_outline),
    ('Материалы', Icons.folder_open_outlined),
    ('Уведомления', Icons.notifications_none_rounded),
    ('Партнёрства', Icons.handshake_outlined),
  ];

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

  Widget navItem(int i, bool wide) => Semantics(
    selected: i == selected,
    child: TextButton(
      key: ValueKey(wide ? 'organizer-nav-$i' : 'organizer-nav-tab-$i'),
      onPressed: () => onSection(i),
      style: TextButton.styleFrom(
        foregroundColor: i == selected ? C.ink : OrganizerStyle.muted,
        backgroundColor: i == selected ? C.canvas : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: wide
          ? Row(
              children: [
                Icon(menu[i].$2, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    menu[i].$1,
                    style: OrganizerStyle.text(
                      14,
                      weight: i == selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (i == selected) const Icon(Icons.circle, size: 6),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(menu[i].$2, size: 22),
                const SizedBox(height: 4),
                Text(menu[i].$1, style: OrganizerStyle.text(12)),
              ],
            ),
    ),
  );

  Widget sidebar() => Container(
    width: 240,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: C.line)),
    ),
    child: LayoutBuilder(
      builder: (context, size) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: OrganizerWordmark(),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Кабинет организатора',
                      style: OrganizerStyle.text(
                        13,
                        color: OrganizerStyle.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  for (var i = 0; i < menu.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: navItem(i, true),
                    ),
                  const Spacer(),
                  const SizedBox(height: 40),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      avatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Наталья Орлова',
                              style: OrganizerStyle.text(
                                15,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'MONTAS Events',
                              style: OrganizerStyle.text(
                                13,
                                color: OrganizerStyle.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget avatar() => CircleAvatar(
    radius: 22,
    backgroundColor: OrganizerStyle.mint,
    child: Text('НО', style: OrganizerStyle.text(13, weight: FontWeight.w600)),
  );

  Widget header(bool wide) => Container(
    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 24, vertical: 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        if (wide)
          Text(
            'Рабочее пространство / $title',
            style: OrganizerStyle.text(13, color: OrganizerStyle.muted),
          )
        else
          const OrganizerWordmark(),
        const Spacer(),
        if (wide) ...[
          link(
            'Каталог мероприятий',
            onCatalog,
            id: 'organizer-demo-catalog',
            icon: Icons.north_east_rounded,
          ),
          const SizedBox(width: 20),
        ] else
          IconButton(
            key: const ValueKey('organizer-demo-catalog'),
            tooltip: 'Каталог мероприятий',
            onPressed: onCatalog,
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
          ),
        IconButton(
          tooltip:
              'Уведомления${store.partnerUnread > 0 ? ": ${store.partnerUnread} непрочитанных" : ""}',
          onPressed: () => onSection(4),
          icon: Badge(
            isLabelVisible: store.partnerUnread > 0,
            label: Text('${store.partnerUnread}'),
            backgroundColor: C.ink,
            child: const Icon(Icons.notifications_none_rounded, size: 22),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 1050;
      final body = Column(
        children: [
          header(wide),
          Expanded(child: child),
          if (!wide)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: C.line)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < menu.length; i++) navItem(i, false),
                  ],
                ),
              ),
            ),
        ],
      );
      return ColoredBox(
        color: C.canvas,
        child: wide
            ? Row(
                children: [
                  sidebar(),
                  Expanded(child: body),
                ],
              )
            : body,
      );
    },
  );
}
