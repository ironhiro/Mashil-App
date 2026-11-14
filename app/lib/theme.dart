import 'package:material_ui/material_ui.dart';

/// docs/07-ui-design.md 의 색 토큰 중 네이티브 화면(스플래시·오류·업데이트)에 쓰는 것만.
class MashilColors {
  static const accent = Color(0xFF1F6F69); // 아이콘 배경 "열린 문"
  static const lightBg = Color(0xFFF7F7F5);
  static const darkBg = Color(0xFF161818);
}

ThemeData mashilTheme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: MashilColors.accent, brightness: b),
      scaffoldBackgroundColor: b == Brightness.dark ? MashilColors.darkBg : MashilColors.lightBg,
      useMaterial3: true,
    );
