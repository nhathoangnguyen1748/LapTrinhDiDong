import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apptracngiem/main.dart';

void main() {
  testWidgets('LocalQuizBleApp launches and renders role selection screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LocalQuizBleApp(),
      ),
    );

    // Pump past the initial entry animations
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    // Verify title and main action cards exist
    expect(find.text('LocalQuiz BLE'), findsOneWidget);
    expect(find.text('Vào Thi (Thí Sinh)'), findsOneWidget);
    expect(find.text('Phát Đề (Giám Thị)'), findsOneWidget);
  });
}
