import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 화면 언어. 웹이 브리지 `setLanguage` 로 알려 준 언어를 쓰고, 저장해서 다음 실행에도 유지한다.
/// 값이 null 이면 기기 언어를 따른다 (웹이 아직 한 번도 알려 주지 않았을 때).
///
/// 웹이 언어의 기준인 이유: 웹 메뉴에서 언어를 고를 수 있고, 앱 네이티브 문구(오류 화면 등)도 같은 언어로 보여야 해서.
class AppLanguage extends ValueNotifier<Locale?> {
  AppLanguage({
    Locale? initial,
    required this.supported,
    this.persist,
  }) : super(initial);

  static const _prefsKey = 'app_language';

  /// 지원 언어 코드 (AppLocalizations.supportedLocales).
  final List<Locale> supported;

  /// 고른 언어 저장 (기본: SharedPreferences). 테스트에서는 바꿔 끼운다.
  final Future<void> Function(String code)? persist;

  /// 저장된 언어로 시작. 저장값이 없거나 지원하지 않는 언어면 기기 언어.
  static Future<AppLanguage> load(List<Locale> supported) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    return AppLanguage(
      initial: _match(saved, supported),
      supported: supported,
      persist: (code) => prefs.setString(_prefsKey, code),
    );
  }

  /// 언어 바꾸기. 지원하지 않는 언어면 false.
  Future<bool> set(String? code) async {
    final locale = _match(code, supported);
    if (locale == null) return false;
    if (value != locale) value = locale;
    await persist?.call(locale.languageCode);
    return true;
  }

  /// "en", "en-US", "ko_KR" → 지원 목록의 Locale (언어 코드만 비교).
  static Locale? _match(String? code, List<Locale> supported) {
    if (code == null || code.isEmpty) return null;
    final lang = code.split(RegExp('[-_]')).first.toLowerCase();
    for (final l in supported) {
      if (l.languageCode == lang) return l;
    }
    return null;
  }
}
