// Mentaliq Widget Test

import 'package:flutter_test/flutter_test.dart';
import 'package:mentaliq/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const MentaliqApp());
    expect(find.text('Mentaliq'), findsWidgets);
  });
}
