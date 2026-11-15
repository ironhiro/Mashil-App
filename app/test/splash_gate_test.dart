import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mashil/shell/splash_gate.dart';

void main() {
  Widget app({bool reduceMotion = false, ValueNotifier<bool>? ready}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: SplashGate(ready: ready, child: const Text('main')),
    ),
  );

  Future<void> runOut(WidgetTester tester) async {
    await tester.pump(SplashGate.startDelay);
    await tester.pump(SplashGate.total);
    await tester.pumpAndSettle();
  }

  testWidgets('준비될 때까지 닫힌 문으로 기다렸다가 연다', (tester) async {
    final ready = ValueNotifier(false);
    await tester.pumpWidget(app(ready: ready));
    await tester.pump();
    await runOut(tester);
    expect(find.byKey(SplashGate.overlayKey), findsOneWidget); // 아직 준비 안 됨

    ready.value = true;
    await tester.pump();
    await runOut(tester);
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
  });

  testWidgets('준비가 끝내 안 되면 maxWait 뒤에 연다', (tester) async {
    await tester.pumpWidget(app(ready: ValueNotifier(false)));
    await tester.pump();
    await tester.pump(SplashGate.maxWait);
    await runOut(tester);
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
  });

  testWidgets('애니메이션 줄이기여도 준비 전에는 닫힌 문, 준비되면 바로 메인', (tester) async {
    final ready = ValueNotifier(false);
    await tester.pumpWidget(app(reduceMotion: true, ready: ready));
    await tester.pump();
    expect(find.byKey(SplashGate.overlayKey), findsOneWidget);
    ready.value = true;
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
  });

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

  testWidgets('연출이 끝나도 메인을 새로 만들지 않는다 (웹뷰가 다시 불러오지 않도록)', (tester) async {
    var created = 0;
    await tester.pumpWidget(MaterialApp(home: SplashGate(child: _Counted(() => created++))));
    await tester.pump();
    await runOut(tester);
    expect(find.byKey(SplashGate.overlayKey), findsNothing);
    expect(created, 1);
  });
}

class _Counted extends StatefulWidget {
  const _Counted(this.onCreate);
  final VoidCallback onCreate;
  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const Text('main');
}
