import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:agriguard_ai/main.dart';
import 'package:agriguard_ai/services/api_key_service.dart';
import 'package:agriguard_ai/services/location_session.dart';
import 'package:agriguard_ai/services/user_session.dart';

void main() {
  testWidgets('Splash screen displays app title', (WidgetTester tester) async {
    final apiKeyService = ApiKeyService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserSession()),
          ChangeNotifierProvider(create: (_) => LocationSession()),
          ChangeNotifierProvider.value(value: apiKeyService),
        ],
        child: const AgriGuardApp(),
      ),
    );

    expect(find.text('Agri-Guard AI'), findsOneWidget);
    expect(
      find.text('Smart Agricultural Intelligence Platform'),
      findsOneWidget,
    );
  });
}
