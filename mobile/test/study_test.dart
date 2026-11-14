// Study: the page with today's lessons and the near deadlines, the timetable, exams and assignments, notes and tips.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peera/feed/compose_screen.dart';
import 'package:peera/home/services.dart';
import 'package:peera/people/person_screen.dart';
import 'package:peera/study/study.dart';

import 'helpers.dart';

Future<void> _open(WidgetTester t, String service) async {
  await t.tap(find.byKey(const ValueKey('tab-me')));
  await settle(t);
  openService(t.element(find.byType(PersonScreen).first), service);
  await settle(t);
}

/// the page's own list: the tallest one scrolling down
Finder _mainList() {
  final all = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).evaluate().toList()
    ..sort((a, b) => ((b.renderObject as RenderBox?)?.size.height ?? 0).compareTo((a.renderObject as RenderBox?)?.size.height ?? 0));
  return find.byElementPredicate((e) => e == all.first);
}

Future<void> _tap(WidgetTester t, String key) async {
  if (find.byKey(ValueKey(key), skipOffstage: false).evaluate().isEmpty) await t.scrollUntilVisible(find.byKey(ValueKey(key)), 250, scrollable: _mainList());
  await t.ensureVisible(find.byKey(ValueKey(key), skipOffstage: false));
  await settle(t);
  await t.tap(find.byKey(ValueKey(key)));
  await settle(t);
}

Future<void> _back(WidgetTester t) async {
  await t.binding.handlePopRoute();
  await settle(t);
}

void main() {
  setUpAll(useTestImages);

  testWidgets("the study page: the lesson on now, a deadline ticked off, a lesson added on two days for my class", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'study');
    expect(find.byType(StudyScreen), findsOneWidget);
    expect(find.text('ახლა მიმდინარეობს'), findsOneWidget);
    expect(find.text('მაკროეკონომიკა'), findsOneWidget);
    expect(find.text('შუალედური: თავები 1–4'), findsOneWidget);
    await _tap(t, 'dl-tick-1');
    expect(api.calls, contains('done 1 true'));
    expect(find.text('ყოჩაღ! შესრულდა ✓'), findsOneWidget);
    expect(find.text('შუალედური: თავები 1–4'), findsNothing);

    await _tap(t, 'study-add');
    await _tap(t, 'ka-lesson');
    expect(find.byType(LessonFormScreen), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ls-title')), 'ფიზიკა');
    final today = DateTime.now().weekday, next = today % 7 + 1;
    await _tap(t, 'lsd-$next');
    await _tap(t, 'ls-for');
    await t.tap(find.text('მე-11 ბ').last);
    await settle(t);
    await _tap(t, 'ls-ok');
    expect(api.calls, containsAll(['lesson new ფიზიკა ${today < next ? today : next} group 7', 'lesson new ფიზიკა ${today < next ? next : today} group 7']));
    expect(find.byType(LessonFormScreen), findsNothing);
    expect(find.byType(StudyScreen), findsOneWidget);
    // back leaves the study page, one step
    await _back(t);
    expect(find.byType(StudyScreen), findsNothing);
    expect(find.byType(PersonScreen), findsWidgets);
  });

  testWidgets("the timetable: tomorrow's lesson from my class, only mine, the class's lesson removed by its admin; mine changed", (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'schedule');
    expect(find.byType(ScheduleScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-1')), findsOneWidget);
    final next = DateTime.now().weekday % 7 + 1;
    await _tap(t, 'sday-$next');
    expect(find.text('სტატისტიკა'), findsOneWidget);
    expect(find.text('მე-11 ბ'), findsWidgets);
    await _tap(t, 'sgf-me');
    expect(find.text('სტატისტიკა'), findsNothing);
    await _tap(t, 'sgf-');
    await _tap(t, 'lesson-2');
    expect(find.text('ჯგუფის ლექცია'), findsOneWidget);
    // back closes the sheet only
    await _back(t);
    expect(find.text('ჯგუფის ლექცია'), findsNothing);
    expect(find.byType(ScheduleScreen), findsOneWidget);
    await _tap(t, 'lesson-2');
    await _tap(t, 'ku-del');
    await t.tap(find.text('წაშლა').last);
    await settle(t);
    expect(api.calls, contains('lessondel 2'));
    expect(find.text('სტატისტიკა'), findsNothing);

    await _tap(t, 'sday-${DateTime.now().weekday}');
    await _tap(t, 'lesson-1');
    expect(find.text('ლექციის რედაქტირება'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('ls-title')), 'მაკროეკონომიკა II');
    await _tap(t, 'lsk-seminar');
    await _tap(t, 'ls-ok');
    expect(api.calls, contains('lesson 1 მაკროეკონომიკა II ${DateTime.now().weekday}'));
    expect(find.text('მაკროეკონომიკა II'), findsOneWidget);
  });

  testWidgets('exams and assignments: one done and found among the done, a quiz added, the class assignment shown, mine removed', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'exams');
    expect(find.byType(ExamsScreen), findsOneWidget);
    expect(find.text('ამ კვირაში'), findsOneWidget);
    expect(find.text('მოგვიანებით'), findsOneWidget);
    await _tap(t, 'dl-tick-1');
    expect(api.calls, contains('done 1 true'));
    expect(find.byKey(const ValueKey('dl-1')), findsNothing);
    await t.tap(find.text('შესრულებული'));
    await settle(t);
    expect(find.byKey(const ValueKey('dl-1')), findsOneWidget);
    expect(find.text('შესრულდა'), findsOneWidget);
    await t.tap(find.text('მომავალი'));
    await settle(t);

    await _tap(t, 'dl-new');
    expect(find.byType(DeadlineFormScreen), findsOneWidget);
    await _tap(t, 'dlk-quiz');
    await t.enterText(find.byKey(const ValueKey('dl-title')), 'ქვიზი 3');
    await _tap(t, 'dls-მაკროეკონომიკა');
    await _tap(t, 'dl-ok');
    expect(api.calls, contains('deadline new quiz ქვიზი 3'));
    expect(find.text('ქვიზი 3'), findsOneWidget);

    await _tap(t, 'dl-2');
    expect(find.text('ჯგუფის ვადა'), findsOneWidget);
    await _back(t);
    expect(find.byType(ExamsScreen), findsOneWidget);

    await t.tap(find.text('შესრულებული'));
    await settle(t);
    await _tap(t, 'dl-1');
    expect(find.byType(DeadlineFormScreen), findsOneWidget);
    await _tap(t, 'dl-del');
    await t.tap(find.text('წაშლა').last);
    await settle(t);
    expect(api.calls, contains('deadlinedel 1'));
    expect(find.byKey(const ValueKey('dl-1')), findsNothing);
  });

  testWidgets('notes by subject and a new one begun with its tags; study tips', (t) async {
    phone(t);
    final api = await shell(t);
    await _open(t, 'notes');
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(api.calls, contains('tagged კონსპექტი'));
    expect(find.byKey(const ValueKey('lib-108')), findsOneWidget);
    await _tap(t, 'libc-მათემატიკა');
    expect(api.calls, contains('tagged კონსპექტი+მათემატიკა'));
    expect(find.text('ვერაფერი მოიძებნა'), findsOneWidget);
    await _tap(t, 'lib-new');
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is TextField && (w.controller?.text.contains('#კონსპექტი #მათემატიკა') ?? false)), findsOneWidget);
    await _back(t);
    expect(find.byType(LibraryScreen), findsOneWidget);
    await _back(t);
    expect(find.byType(LibraryScreen), findsNothing);

    await _open(t, 'tips');
    expect(find.text('სასწავლო რჩევები'), findsWidgets);
    expect(api.calls, contains('tagged რჩევა'));
    expect(find.text('რჩევები ჯერ არ არის'), findsOneWidget);
  });

  test('days and deadlines in words', () {
    expect(onDay(1), 'ორშაბათს');
    expect(onDay(7), 'კვირას');
    final now = DateTime(2026, 11, 16, 9);
    expect(dueText(DateTime(2026, 11, 16, 12), now).$2, 'soon');
    expect(dueText(DateTime(2026, 11, 17, 10), now).$1, 'ხვალ 10:00');
    expect(dueText(DateTime(2026, 11, 20, 10), now).$1, '4 დღეში');
    expect(dueText(DateTime(2026, 11, 15, 10), now).$2, 'late');
    expect(weekOk({'weeks': 'odd'}, DateTime(2026, 1, 1)), isTrue); // week 1
    expect(weekOk({'weeks': 'even'}, DateTime(2026, 1, 1)), isFalse);
  });
}
