import 'package:flutter_test/flutter_test.dart';
import 'package:pix/app.dart';

void main() {
  testWidgets('App loads and shows splash', (WidgetTester tester) async {
    await tester.pumpWidget(const PixApp());
    await tester.pump();
    expect(find.text('PIX'), findsOneWidget);
  });
}
