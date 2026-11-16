import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 시작 연출: 닫힌 문이 열리고, 바닥에 빛이 번진 뒤 메인으로 넘어간다.
///
/// 시스템 스플래시(Android 12+ `splash_icon`, 그 전 `launch_icon`)는 같은 위치·크기의 **닫힌 문**을 그린다
/// (`tool/make_icons.py`). 그래서 Flutter 첫 화면이 그 문을 이어받아 여는 것처럼 보인다.
/// 웹뷰는 연출 뒤에서 이미 불러온다. [ready] 를 주면 문은 그것이 true 가 될 때까지 닫힌 채 기다린다
/// (첫 페이지가 뜨기 전의 빈 웹뷰가 보이지 않도록). 아무리 늦어도 [maxWait] 뒤에는 연다.
/// 기기 설정에서 애니메이션을 줄였으면(`disableAnimations`) 준비되는 대로 연출 없이 들어간다.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child, this.ready});

  final Widget child;

  /// 메인이 보여 줄 준비가 됐는지 (null 이면 처음부터 준비됨)
  final ValueListenable<bool>? ready;

  /// 준비를 기다리는 최대 시간 (첫 프레임부터)
  static const maxWait = Duration(seconds: 6);

  /// 연출 전체 길이 (문 열림 · 바닥 빛 · 사라짐 구간은 _SplashGateState 의 Interval 이 나눈다)
  static const total = Duration(milliseconds: 1400);

  /// 첫 프레임 뒤 문을 열기 전까지 기다리는 시간
  static const startDelay = Duration(milliseconds: 500);

  /// 연출 덮개 (테스트에서 찾는 용도)
  static const overlayKey = ValueKey('splash-overlay');

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SplashGate.total,
  );
  bool _done = false;
  bool _started = false;
  final _childKey = GlobalKey();

  // 구간 (전체 1.4초 기준): 잠깐 멈춤 → 문 열림 → 바닥 빛 → 멈춤 → 사라짐
  static const _open = Interval(0.12, 0.58, curve: Curves.easeOutCubic);
  static const _floor = Interval(0.50, 0.72, curve: Curves.easeOut);
  static const _fade = Interval(0.80, 1.0, curve: Curves.easeIn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _done) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion && _isReady) {
      _done = true; // 애니메이션 줄이기 + 이미 준비됨: 연출 없이
      return;
    }
    // 첫 화면이 실제로 그려지고 시스템 스플래시가 걷힌 뒤에 연다. 바로 시작하면 시작 직후의 버벅임 동안
    // 애니메이션 시간이 흘러가 버려, 문이 열리는 모습 없이 끝나 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        Future<void>.delayed(
          reduceMotion ? Duration.zero : SplashGate.startDelay,
        ),
        _whenReady(),
      ]);
      if (!mounted) return;
      if (reduceMotion) {
        setState(() => _done = true);
        return;
      }
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  bool get _isReady => widget.ready?.value ?? true;

  /// [ready] 가 true 가 되거나 [SplashGate.maxWait] 가 지나면 끝난다.
  Future<void> _whenReady() {
    final ready = widget.ready;
    if (ready == null || ready.value) return Future.value();
    final done = Completer<void>();
    void check() {
      if (ready.value && !done.isCompleted) done.complete();
    }

    ready.addListener(check);
    final timer = Timer(SplashGate.maxWait, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future.whenComplete(() {
      ready.removeListener(check);
      timer.cancel();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = MashilColors.of(context).bg; // = launch_bg (시스템 스플래시 바탕)
    // 연출이 끝나도 Stack 모양은 그대로 둔다. child 의 자리가 바뀌면 웹뷰가 새로 만들어져 페이지를 다시 불러온다.
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(key: _childKey, child: widget.child),
        if (!_done)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final fade = _fade.transform(_c.value);
              return IgnorePointer(
                ignoring: fade > 0.5,
                child: Opacity(
                  opacity: 1 - fade,
                  child: ColoredBox(
                    key: SplashGate.overlayKey,
                    color: bg,
                    child: Center(
                      child: CustomPaint(
                        size: const Size.square(DoorPainter.canvasDp),
                        painter: DoorPainter(
                          open: _open.transform(_c.value),
                          floor: _floor.transform(_c.value),
                          dark: dark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// 문 글리프 — `make_icons.py` 의 glyph() 와 같은 100 단위 격자.
/// open 0 = 닫힘 (문짝이 문틀을 다 덮음), 1 = 열림 (문짝 오른쪽 끝 x55, 위 28, 아래 75).
class DoorPainter extends CustomPainter {
  DoorPainter({
    required this.open,
    required this.floor,
    required this.dark,
  });

  final double open;
  final double floor;
  final bool dark;

  /// Android 12 스플래시 아이콘 영역 240dp 안에서 문 높이 110dp (make_icons.py 와 같게)
  static const canvasDp = 240.0;
  static const doorDp = 110.0;

  static const _blue = MashilColors.doorBg; // Pantone 286 C
  static const _red = MashilColors.signal; // Pantone 485 C 손잡이
  static const _light = Color(0xFFA7C6ED); // 문 안쪽 빛 (Pantone 2717 C)
  static const _leaf = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    // 격자 → 화면: 문틀(33,22)~(67,80) 의 가운데를 캔버스 가운데에, 높이 61 단위 = 110dp
    final k = doorDp / (80 - 22 + 3);
    canvas.translate(size.width / 2 - 50 * k, size.height / 2 - 51 * k);
    canvas.scale(k);

    final right = 67 - 12 * open; // 문짝 오른쪽 끝
    final top = 22 + 6 * open;
    final bottom = 80 - 5 * open;
    final leaf = Path()
      ..moveTo(33, 22)
      ..lineTo(right, top)
      ..lineTo(right, bottom)
      ..lineTo(33, 80)
      ..close();

    // 바닥에 번지는 빛 (문이 거의 다 열린 뒤)
    if (floor > 0) {
      final spill = Path()
        ..moveTo(55, 77)
        ..lineTo(67, 80)
        ..lineTo(80, 94)
        ..lineTo(57, 94)
        ..close();
      final c = dark ? _light : _blue;
      canvas.drawPath(
        spill,
        Paint()..color = c.withValues(alpha: (dark ? 0.35 : 0.22) * floor),
      );
    }

    final frame = RRect.fromLTRBR(33, 22, 67, 80, const Radius.circular(2));
    if (dark) {
      // 어두운 바탕: 문틈으로 옅은 파랑 빛, 흰 문짝
      canvas.drawRRect(frame, Paint()..color = _light);
      canvas.drawPath(leaf, Paint()..color = _leaf);
    } else {
      // 밝은 바탕: 파랑 외곽선 문틀 + 파랑 문짝 (흰 문은 밝은 바탕에 묻힌다)
      canvas.drawRRect(
        RRect.fromLTRBR(31.5, 20.5, 68.5, 81.5, const Radius.circular(3.5)),
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawPath(leaf, Paint()..color = _blue);
    }
    // 손잡이 = 빨강 점. 문짝과 함께 움직인다
    canvas.drawCircle(Offset(right - 5, 53), 2.8, Paint()..color = _red);
  }

  @override
  bool shouldRepaint(DoorPainter old) =>
      old.open != open ||
      old.floor != floor ||
      old.dark != dark;
}
