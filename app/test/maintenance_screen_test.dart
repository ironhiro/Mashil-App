import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mashil/l10n/app_localizations.dart';
import 'package:mashil/services/app_status.dart';
import 'package:mashil/shell/maintenance_screen.dart';
import 'package:mashil/theme.dart';

void main() {
  Future<(int, int)> pump(WidgetTester tester, AppStatus status) async {
    var retries = 0, kakao = 0;
    await tester.pumpWidget(MaterialApp(
      theme: mashilTheme(Brightness.light),
      locale: const Locale('ko'),
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MaintenanceScreen(status: status, onRetry: () => retries++, onOpenKakaoMap: () => kakao++),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 확인'));
    await tester.tap(find.text('카카오맵에서 화장실 찾기'));
    return (retries, kakao);
  }

  testWidgets('제목, 운영자 안내, 다시 여는 시각, 두 행동', (tester) async {
    final (retries, kakao) = await pump(
      tester,
      AppStatus(maintenance: true, message: 'DB 점검 중이에요', until: DateTime.now().add(const Duration(hours: 1))),
    );
    expect(find.text('문이 잠시 닫혔어요'), findsOneWidget);
    expect(find.text('DB 점검 중이에요'), findsOneWidget);
    expect(find.text('다시 여는 시각'), findsOneWidget);
    expect((retries, kakao), (1, 1));
  });

  testWidgets('시각을 모르면 판 없이 기본 안내', (tester) async {
    await pump(tester, AppStatus.unavailable);
    expect(find.text('더 나은 마실을 위해 점검하고 있어요.'), findsOneWidget);
    expect(find.text('다시 여는 시각'), findsNothing);
  });
}
