import 'package:exam_ai_app/main.dart';
import 'package:exam_ai_app/screens/login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App can render login screen shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ExamAIApp(home: PremiumLoginScreen()),
    );

    expect(find.text('Exam AI'), findsOneWidget);
    expect(find.text('Tekrar ho\u015f geldin \ud83d\udc4b'), findsOneWidget);
    expect(find.text('\u00c7al\u0131\u015fmaya Ba\u015fla'), findsOneWidget);
    expect(find.text('Kay\u0131t ol'), findsOneWidget);
  });
}
