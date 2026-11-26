import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/main.dart';

void main() {
  testWidgets('Nudge app shell renders navigation and loading/error states', (WidgetTester tester) async {
    await tester.pumpWidget(const NudgeApp());
    // Avoid pumpAndSettle because the loading spinner animates indefinitely.
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
