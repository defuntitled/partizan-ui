import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partizan/core/link.dart';
import 'package:partizan/core/vpn_status.dart';
import 'package:partizan/ui/screens/about_screen.dart';
import 'package:partizan/ui/theme.dart';
import 'package:partizan/ui/widgets/art.dart';
import 'package:partizan/ui/widgets/record.dart';

import 'fakes.dart';

double opacityOf(WidgetTester tester, Key image) => tester
    .widget<Opacity>(
      find
          .ancestor(of: find.byKey(image), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

Widget record(VpnState state) => MaterialApp(
  home: Center(
    child: SizedBox.square(
      dimension: 300,
      child: RecordToggle(state: state, onTap: () {}),
    ),
  ),
);

void main() {
  test('every asset is bundled and every SVG parses', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final path in Art.all) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
      if (path.endsWith('.svg')) {
        final loader = SvgAssetLoader(path);
        final picture = await vg.loadPicture(loader, null);
        expect(picture.size.isEmpty, isFalse, reason: path);
        picture.picture.dispose();
      }
    }
    expect(
      await rootBundle.loadString('assets/fonts/OFL.txt'),
      contains('SIL OPEN FONT LICENSE'),
    );
  });

  testWidgets(
    'the record is broken while down, whole when up, broken at once when down',
    (tester) async {
      await tester.pumpWidget(record(VpnState.idle));
      expect(opacityOf(tester, const Key('record-broken')), 1);
      expect(opacityOf(tester, const Key('record-full')), 0);

      // Connecting: it mends over about a second.
      await tester.pumpWidget(record(VpnState.connecting));
      await tester.pump(RecordToggle.mend ~/ 2);
      final halfway = opacityOf(tester, const Key('record-full'));
      expect(halfway, inExclusiveRange(0, 1));
      await tester.pump(RecordToggle.mend);
      await tester.pumpWidget(record(VpnState.connected));
      await tester.pump();
      expect(opacityOf(tester, const Key('record-full')), 1);

      // Down: no animation.
      await tester.pumpWidget(record(VpnState.idle));
      await tester.pump();
      expect(opacityOf(tester, const Key('record-broken')), 1);
      expect(opacityOf(tester, const Key('record-full')), 0);

      await tester.pumpWidget(record(VpnState.error));
      await tester.pump();
      expect(opacityOf(tester, const Key('record-full')), 0);
    },
  );

  testWidgets('Kill Switch: the setting is saved and reaches the platform', (
    tester,
  ) async {
    final bridge = FakeBridge();
    final store = MemoryProfileStore();
    await store.add(
      name: 'Дом',
      info: LinkInfo.parse(testLink)!,
      link: testLink,
    );
    await tester.pumpWidget(app(bridge, store));
    await tester.pumpAndSettle();
    expect(bridge.killSwitches.last, isFalse);

    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kill-switch')));
    await tester.pumpAndSettle();
    expect(store.killSwitch, isTrue);
    expect(bridge.killSwitches.last, isTrue);
    expect(
      bridge.launches.last.$1,
      'Дом',
      reason: 'published with the profile',
    );

    await tester.tap(find.byKey(const Key('system-lock')));
    await tester.pumpAndSettle();
    expect(bridge.calls.last, 'vpn settings');
  });

  testWidgets('the server list shows the world map', (tester) async {
    await tester.pumpWidget(app(FakeBridge()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сервер не выбран'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-map')), findsOneWidget);
  });

  testWidgets(
    'about: version, licenses, the plate; no contacts block while empty',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: partizanTheme(),
          home: const AboutScreen(version: '1.0.0 (1)'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Версия 1.0.0 (1)'), findsOneWidget);
      expect(find.text('Лицензии'), findsOneWidget);
      expect(find.byKey(const Key('about-plate')), findsOneWidget);
      expect(find.text('КОНТАКТЫ'), findsNothing);
    },
  );
}
