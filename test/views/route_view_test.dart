import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:fl_clash/views/route/route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() => navigationPort = Navigation());
  tearDown(() => navigationPort = null);

  testWidgets('Route page is available on mobile and desktop navigation', (
    tester,
  ) async {
    final item = Navigation()
        .getItems(openLogs: true, hasProxies: true, hasNetworking: true)
        .singleWhere((item) => item.label == PageLabel.route);

    expect(item.modes, containsAll(NavigationItemMode.values.take(2)));

    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        overrides: [currentProfileProvider.overrideWith((ref) => null)],
        child: Builder(builder: item.builder),
      ),
    );
    await tester.pump();

    expect(find.byType(RouteView), findsOneWidget);
    expect(find.text('Select a profile to configure routing'), findsOneWidget);
    expect(find.byIcon(Icons.alt_route_outlined), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();
  });
}
