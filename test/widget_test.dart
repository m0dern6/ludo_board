import 'package:flutter_test/flutter_test.dart';
import 'package:board/main.dart';

void main() {
  testWidgets('Ludo App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const LudoApp());
    expect(find.text('LUDO'), findsOneWidget);
  });
}
