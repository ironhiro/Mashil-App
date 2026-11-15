import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// 시작 연출: 닫힌 문이 열리고, 바닥에 빛이 번진 뒤 메인으로 넘어간다.
///
/// 시스템 스플래시(Android 12+ `splash_icon`, 그 전 `launch_icon`)는 같은 위치·크기의 **닫힌 문**을 그린다
/// (`tool/make_icons.py`). 그래서 Flutter 첫 화면이 그 문을 이어받아 여는 것처럼 보인다.
/// 웹뷰는 연출 뒤에서 이미 불러오고 있으므로 연출 때문에 늦어지지 않는다.
/// 기기 설정에서 애니메이션을 줄였으면(`disableAnimations`) 연출 없이 바로 들어간다.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  /// 문이 열리는 시간 · 빛이 번지는 시간 · 사라지는 시간
  static const openDuration = Duration(milliseconds: 650);
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

  // 구간 (전체 1.4초 기준): 잠깐 멈춤 → 문 열림 → 바닥 빛 → 멈춤 → 사라짐
  static const _open = Interval(0.12, 0.58, curve: Curves.easeOutCubic);
  static const _floor = Interval(0.50, 0.72, curve: Curves.easeOut);
  static const _fade = Interval(0.80, 1.0, curve: Curves.easeIn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _done) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _done = true; // 애니메이션 줄이기: 연출 없이
      return;
    }
    // 첫 화면이 실제로 그려지고 시스템 스플래시가 걷힌 뒤에 연다. 바로 시작하면 시작 직후의 버벅임 동안
    // 애니메이션 시간이 흘러가 버려, 문이 열리는 모습 없이 끝나 버린다.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(SplashGate.startDelay);
      if (!mounted) return;
      _c.forward().whenComplete(() {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = MashilColors.of(context).bg; // = launch_bg (시스템 스플래시 바탕)
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
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
                      size: const Size.square(_DoorPainter.canvasDp),
                      painter: _DoorPainter(
                        open: _open.transform(_c.value),
                        floor: _floor.transform(_c.value),
                        dark: dark,
                        bg: bg,
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
class _DoorPainter extends CustomPainter {
  _DoorPainter({
    required this.open,
    required this.floor,
    required this.dark,
    required this.bg,
  });

  final double open;
  final double floor;
  final bool dark;
  final Color bg;

  /// Android 12 스플래시 아이콘 영역 240dp 안에서 문 높이 110dp (make_icons.py 와 같게)
  static const canvasDp = 240.0;
  static const doorDp = 110.0;

  static const _teal = MashilColors.doorBg; // #1F6F69
  static const _light = Color(0xFF7FE0D3);
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
      final c = dark ? _light : _teal;
      canvas.drawPath(
        spill,
        Paint()..color = c.withValues(alpha: (dark ? 0.35 : 0.22) * floor),
      );
    }

    final frame = RRect.fromLTRBR(33, 22, 67, 80, const Radius.circular(2));
    if (dark) {
      // 어두운 바탕: 문틈으로 민트 빛, 흰 문짝
      canvas.drawRRect(frame, Paint()..color = _light);
      canvas.drawPath(leaf, Paint()..color = _leaf);
    } else {
      // 밝은 바탕: 청록 외곽선 문틀 + 청록 문짝 (흰 문은 밝은 바탕에 묻힌다)
      canvas.drawRRect(
        RRect.fromLTRBR(31.5, 20.5, 68.5, 81.5, const Radius.circular(3.5)),
        Paint()
          ..color = _teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawPath(leaf, Paint()..color = _teal);
    }
    // 손잡이 = 바탕이 비쳐 보이는 구멍. 문짝과 함께 움직인다
    canvas.drawCircle(Offset(right - 5, 53), 2.8, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_DoorPainter old) =>
      old.open != open ||
      old.floor != floor ||
      old.dark != dark ||
      old.bg != bg;
}
