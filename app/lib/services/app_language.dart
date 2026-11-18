import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 화면 언어. 시작할 때는 기기(앱별) 언어를 따르고(null), 웹이 브리지 `setLanguage` 로 알려 주면 그 언어로 맞춘다.
///
/// 저장하지 않는다 (2026-11-18): 앱 안에 언어 고르기를 없애고 기기 언어를 따르기로 해서, 저장해 두면 기기 언어를
/// 바꾼 뒤에도 네이티브 화면(오류·점검 화면)만 예전 언어로 남는다. 예전 버전이 저장한 값은 처음 실행 때 지운다.
class AppLanguage extends ValueNotifier<Locale?> {
  AppLanguage({
    Locale? initial,
    required this.supported,
    this.persist,
  }) : super(initial);

  static const _prefsKey = 'app_language';

  /// 지원 언어 코드 (AppLocalizations.supportedLocales).
  final List<Locale> supported;

  /// 언어가 바뀔 때 부르는 후크 (앱에서는 쓰지 않는다. 테스트가 바뀐 값을 확인할 때 넣는다).
  final Future<void> Function(String code)? persist;

  /// 기기 언어로 시작한다. 예전 버전이 저장해 둔 언어는 지운다.
  static Future<AppLanguage> load(List<Locale> supported) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    return AppLanguage(supported: supported);
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
