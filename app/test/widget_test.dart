import 'package:flutter_test/flutter_test.dart';
import 'package:bnu_schedule_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BnuScheduleApp());
    expect(find.text('北师老鸦'), findsOneWidget);
  });
}
