import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mashil/shell/deep_links.dart';

void main() {
  final web = Uri.parse('https://toilets.ironhiro.dev');

  group('resolve', () {
    test('path only', () {
      expect(DeepLinks.resolve(web, Uri.parse('/toilets/12')).toString(), 'https://toilets.ironhiro.dev/toilets/12');
    });
    test('full url on the same host keeps query', () {
      expect(DeepLinks.resolve(web, Uri.parse('https://toilets.ironhiro.dev/toilets/12?from=share')).toString(),
          'https://toilets.ironhiro.dev/toilets/12?from=share');
    });
    test('host is case-insensitive', () {
      expect(DeepLinks.resolve(web, Uri.parse('https://Toilets.IronHiro.dev/toilets/3')), isNotNull);
    });
    test('other host, scheme or bare root is ignored', () {
      expect(DeepLinks.resolve(web, Uri.parse('https://evil.example/toilets/12')), isNull);
      expect(DeepLinks.resolve(web, Uri.parse('https://toilets-dev.ironhiro.dev/toilets/12')), isNull);
      expect(DeepLinks.resolve(web, Uri.parse('javascript:alert(1)')), isNull);
      expect(DeepLinks.resolve(web, Uri.parse('/')), isNull);
      expect(DeepLinks.resolve(web, Uri.parse('//evil.example/x')), isNull);
      expect(DeepLinks.resolve(web, null), isNull);
    });
    test('web base path (dev bridge) is replaced', () {
      expect(DeepLinks.resolve(Uri.parse('http://10.0.2.2:5099/dev/bridge'), Uri.parse('/toilets/1')).toString(),
          'http://10.0.2.2:5099/toilets/1');
    });
  });

  test('initial route becomes pending once', () {
    final d = DeepLinks(web, initialRoute: '/toilets/7');
    expect(d.takePending().toString(), 'https://toilets.ironhiro.dev/toilets/7');
    expect(d.takePending(), isNull);
    expect(DeepLinks(web, initialRoute: '/').takePending(), isNull);
  });

  test('pushed link is emitted and swallowed', () async {
    final d = DeepLinks(web);
    final got = d.links.first;
    final handled = await d.didPushRouteInformation(RouteInformation(uri: Uri.parse('https://toilets.ironhiro.dev/toilets/9')));
    expect(handled, isTrue);
    expect((await got).path, '/toilets/9');
    // 다른 호스트도 앱 Navigator 로 넘기지 않는다
    expect(await d.didPushRouteInformation(RouteInformation(uri: Uri.parse('https://evil.example/'))), isTrue);
  });
}
