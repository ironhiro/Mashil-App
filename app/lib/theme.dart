import 'package:material_ui/material_ui.dart';

/// 네이티브 화면(스플래시·오류·업데이트)의 색. 웹(Mashil-web src/styles/tokens.css, Hallmark · Wayfind)과
/// 같은 값의 hex 사본이다. 전부 Pantone 색: 종이 656 C, 잉크 282 C (남색), 지금 열린 것과 주 행동은 286 C 파랑,
/// 곧 닫힘 신호는 485 C 빨강 (둘은 섞지 않는다). 모서리 0, 2px 잉크 테두리.
class MashilColors {
  /// 앱 아이콘 "열린 문"의 바탕 = 테마 파랑, 손잡이 = 신호 빨강 (남녀 화장실 색을 섞지 않고 역할로 나눔)
  static const doorBg = Color(0xFF0033A0); // Pantone 286 C
  static const signal = Color(0xFFDA291C); // Pantone 485 C

  static const light = MashilTokens(
    bg: Color(0xFFDDE5ED), // paper = Pantone 656 C
    surface: Color(0xFFFFFFFF), // paper-3
    line: Color(0xFF041E42), // 2px 테두리는 잉크
    text: Color(0xFF041E42), // ink = Pantone 282 C
    textMuted: Color(0xFF425563), // muted = Pantone 7545 C
    accent: Color(0xFF0033A0), // Pantone 286 C
    onAccent: Color(0xFFFCFEFF),
  );

  static const dark = MashilTokens(
    bg: Color(0xFF101820), // night paper = Pantone Black 6 C
    surface: Color(0xFF1D252D), // night band = Pantone 433 C
    line: Color(0xFFDDE5ED),
    text: Color(0xFFDDE5ED), // Pantone 656 C
    textMuted: Color(0xFF98A4AE), // Pantone 7543 C
    accent: Color(0xFF485CC7), // Pantone 2726 C (286 C 는 밤 바탕에 너무 어둡다. 흰 글자 5.8:1)
    onAccent: Color(0xFFFCFEFF),
  );

  static MashilTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class MashilTokens {
  const MashilTokens({
    required this.bg,
    required this.surface,
    required this.line,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.onAccent,
  });

  final Color bg, surface, line, text, textMuted, accent, onAccent;
}

ThemeData mashilTheme(Brightness b) {
  final t = b == Brightness.dark ? MashilColors.dark : MashilColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: t.accent, brightness: b)
      .copyWith(
        primary: t.accent,
        onPrimary: t.onAccent,
        surface: t.surface,
        onSurface: t.text,
        onSurfaceVariant: t.textMuted,
        outline: t.line,
      );
  // Wayfind: 모서리 0, 깊이는 테두리로
  const square = RoundedRectangleBorder();
  final bar = BorderSide(color: t.line, width: 2);
  return ThemeData(
    // 웹과 같은 서체: 라틴·숫자는 Overpass, 한글은 서울남산체 (assets/fonts, tool/make_fonts.py).
    // 일본어·중국어 글자는 둘 다 없어서 기기 글꼴로 그린다 (웹의 :lang(ja|zh) 와 같은 결과)
    fontFamily: 'Overpass',
    fontFamilyFallback: const ['SeoulNamsan'],
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: square,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: square,
        side: bar,
        foregroundColor: t.text,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: square, foregroundColor: t.text),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(side: bar),
      backgroundColor: t.bg,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: TextStyle(color: t.bg),
      shape: square,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
