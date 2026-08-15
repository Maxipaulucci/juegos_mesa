import 'package:flutter_test/flutter_test.dart';

import 'package:app_juegos_mesa/main.dart';

void main() {
  testWidgets('muestra el menú de juegos', (WidgetTester tester) async {
    await tester.pumpWidget(const JuegosMesaApp());

    expect(find.text('AMO A MI NOVIA'), findsOneWidget);
    expect(find.text('Diez Mil'), findsOneWidget);
  });
}
