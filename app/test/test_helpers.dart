import 'package:flutter_test/flutter_test.dart';
import 'package:montas_organizer/main.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

EventDraft ready(
  String id, {
  String title = 'Новая встреча',
  String capacity = '2',
  String date = '30.10.2026',
  String start = '19:00',
  String end = '20:00',
  String price = '0',
}) => EventDraft(
  id: id,
  title: title,
  description: 'Описание встречи',
  speakers: 'Анна Волкова',
  program: '19:00 · Обсуждение\n19:30 · Вопросы',
  capacityText: capacity,
  dateText: date,
  start: start,
  end: end,
  priceText: price,
);
