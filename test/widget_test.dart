import 'package:flutter_test/flutter_test.dart';
import 'package:my_duit_gweh/main.dart';

void main() {
  testWidgets('App should render splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyDuitGwehApp());

    // The splash screen should show the app name
    expect(find.text('My Duit Gweh'), findsOneWidget);
    expect(find.text('Smart Money Manager'), findsOneWidget);
  });
}
