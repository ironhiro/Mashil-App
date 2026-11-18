import 'package:flutter_test/flutter_test.dart';
import 'package:mashil/l10n/app_localizations.dart';
import 'package:mashil/services/app_language.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;
  Locale pick(List<Locale> device) => AppLanguage.resolve(device, supported);

  test('중국어는 글자 체계로 고른다: 대만·홍콩은 번체, 그 밖은 간체', () {
    const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    expect(pick(const [Locale('zh', 'TW')]), hant);
    expect(pick(const [Locale('zh', 'HK')]), hant);
    expect(pick(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW')]), hant);
    expect(pick(const [Locale('zh', 'CN')]), const Locale('zh'));
    expect(pick(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans')]), const Locale('zh'));
  });

  test('일본어·영어·한국어, 지원 안 하는 언어는 다음 언어 → 없으면 첫 언어(한국어)', () {
    expect(pick(const [Locale('ja', 'JP')]), const Locale('ja'));
    expect(pick(const [Locale('fr'), Locale('en', 'US')]), const Locale('en'));
    expect(pick(const [Locale('fr')]), const Locale('ko'));
  });

  test('웹이 알려 준 언어 코드도 같은 규칙', () async {
    final lang = AppLanguage(supported: supported);
    expect(await lang.set('zh-Hant'), isTrue);
    expect(lang.value?.scriptCode, 'Hant');
    expect(await lang.set('zh-Hans'), isTrue);
    expect(lang.value, const Locale('zh'));
    expect(await lang.set('ja'), isTrue);
    expect(lang.value, const Locale('ja'));
    expect(await lang.set('fr'), isFalse);
  });
}
