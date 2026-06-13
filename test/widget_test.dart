import 'package:flutter_test/flutter_test.dart';
import 'package:my_school/main.dart';

void main() {
  testWidgets('Madrasa app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MadrasaApp());

    // Verify that our input screen is shown.
    expect(find.text('Madrasa App Settings'), findsOneWidget);
  });
}
