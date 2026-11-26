import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/main.dart';

void main() {
  testWidgets('Nudge opens its dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const NudgeApp());
    await tester.pumpAndSettle();

    expect(find.text('Hello, Idan'), findsOneWidget);
    expect(find.text('SMART NUDGE'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsOneWidget);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Projects'), findsOneWidget);
  });
}
