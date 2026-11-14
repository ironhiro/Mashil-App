import 'package:material_ui/material_ui.dart';

/// docs/07-ui-design.md "C. 타일" 색 토큰 중 네이티브 화면(스플래시·오류·업데이트)에 쓰는 것.
/// 웹(Mashil-web src/design/tokens.ts)과 같은 값을 쓴다.
class MashilColors {
  /// 아이콘 바탕 "열린 문" — 라이트 accent
  static const accent = Color(0xFF1F6F69);

  static const light = MashilTokens(
    bg: Color(0xFFE8F2F0),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFC3DCD8),
    text: Color(0xFF0E3B3A),
    textMuted: Color(0xFF2F6F6B),
    accent: Color(0xFF1F6F69),
    onAccent: Color(0xFFFFFFFF),
  );

  static const dark = MashilTokens(
    bg: Color(0xFF111213),
    surface: Color(0xFF1B1C1E),
    line: Color(0xFF2A2C2F),
    text: Color(0xFFECECEC),
    textMuted: Color(0xFF9A9DA3),
    accent: Color(0xFF5CC2B7),
    onAccent: Color(0xFF0B1F1D),
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
  final scheme =
      ColorScheme.fromSeed(
        seedColor: MashilColors.accent,
        brightness: b,
      ).copyWith(
        primary: t.accent,
        onPrimary: t.onAccent,
        surface: t.surface,
        onSurface: t.text,
        onSurfaceVariant: t.textMuted,
        outline: t.line,
      );
  const radius = BorderRadius.all(Radius.circular(6));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    useMaterial3: true,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: TextStyle(color: t.bg),
      shape: const RoundedRectangleBorder(borderRadius: radius),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
