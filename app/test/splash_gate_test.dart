import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mashil/shell/splash_gate.dart';

void main() {
  Widget app({bool reduceMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const SplashGate(child: Text('main')),
    ),
  );

  testWidgets('문이 열리는 동안 연출이 덮고, 끝나면 메인만 남는다', (tester) async {
    await tester.pumpWidget(app());
    // 메인은 처음부터 뒤에서 그려진다 (웹뷰가 미리 불러오도록)
    expect(find.text('main'), findsOneWidget);
    expect(find.byKey(SplashGate.overlayKey), findsOneWidget);

    await tester.pump(); // 첫 프레임 뒤 대기 시작
    await tester.pump(SplashGate.startDelay);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(SplashGate.overlayKey), findsWidgets); // 아직 연출 중

    await tester.pump(SplashGate.total);
    await tester.pumpAndSettle();
    expect(find.text('main'), findsOneWidget);
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
  });

  testWidgets('애니메이션 줄이기 설정이면 연출 없이 바로 메인', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pump();
    expect(find.text('main'), findsOneWidget);
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
  });
}
