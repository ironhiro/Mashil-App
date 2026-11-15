import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show Locale;
import 'package:mashil/app_config.dart';
import 'package:mashil/auth/social_auth_service.dart';
import 'package:mashil/bridge/bridge_message.dart';
import 'package:mashil/bridge/mashil_js_bridge.dart';
import 'package:mashil/services/app_language.dart';
import 'package:mashil/services/external_launcher.dart';
import 'package:mashil/services/location_service.dart';
import 'package:mashil/services/version_checker.dart';
import 'package:mashil/shell/navigation_policy.dart';

class FakeLocation implements LocationService {
  PermissionState state = PermissionState.granted;
  LatLng? pos = const LatLng(37.5665, 126.978, accuracy: 12);
  LatLng? last;
  Duration? lastMaxAge;
  ({Duration timeout, bool highAccuracy})? measured;
  @override
  Future<PermissionState> ensurePermission() async => state;
  @override
  Future<LatLng?> lastKnown({required Duration maxAge}) async {
    lastMaxAge = maxAge;
    return last;
  }

  @override
  Future<LatLng?> currentPosition({Duration timeout = const Duration(seconds: 12), bool highAccuracy = true}) async {
    measured = (timeout: timeout, highAccuracy: highAccuracy);
    return pos;
  }
  @override
  Future<bool> openAppSettings() async => true;
}

class FakeLauncher implements ExternalLauncher {
  final opened = <String>[];
  @override
  Future<String?> openDirections(double lat, double lng, String name) async {
    opened.add('$lat,$lng,$name');
    return 'kakaomap';
  }

  @override
  Future<bool> openExternal(Uri uri) async => true;
}

class FakeAuth implements SocialAuthService {
  Object? next; // SocialCredential 또는 던질 예외
  String? lastNonce;
  int signOuts = 0;
  @override
  List<AuthProvider> availableProviders() => [AuthProvider.kakao];
  @override
  Future<SocialCredential> signIn(AuthProvider p, String? nonce) async {
    lastNonce = nonce;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final n = next;
    if (n is Exception) throw n;
    return n as SocialCredential;
  }

  @override
  Future<void> signOut(AuthProvider p) async => signOuts++;
}

void main() {
  late List<String> scripts;
  late FakeLocation location;
  late FakeAuth auth;
  late FakeLauncher launcher;
  late AppLanguage language;
  late List<String> savedLanguages;
  var trusted = true;

  MashilJsBridge bridge() => MashilJsBridge(
        runJavaScript: (s) async => scripts.add(s),
        location: location,
        launcher: launcher,
        auth: auth,
        appInfo: const AppInfo(version: '1.0.0', platform: 'android'),
        language: language,
        isTrustedPage: () => trusted,
      );

  /// 응답 스크립트에서 (requestId, result) 를 꺼낸다.
  (String, Map<String, dynamic>) reply(String script) {
    final m = RegExp(r'__mashilBridgeReply\((".*?"), (\{.*\})\);$').firstMatch(script)!;
    return (jsonDecode(m.group(1)!) as String, jsonDecode(m.group(2)!) as Map<String, dynamic>);
  }

  String msg(String id, String method, [Map<String, Object?> params = const {}]) =>
      jsonEncode({'requestId': id, 'method': method, 'params': params});

  setUp(() {
    scripts = [];
    location = FakeLocation();
    auth = FakeAuth();
    launcher = FakeLauncher();
    savedLanguages = [];
    language = AppLanguage(
      supported: const [Locale('ko'), Locale('en')],
      persist: (code) async => savedLanguages.add(code),
    );
    trusted = true;
  });

  test('getAppInfo 는 버전·플랫폼·로그인 제공자를 준다', () async {
    await bridge().onMessage(msg('a1', 'getAppInfo'));
    final (id, r) = reply(scripts.single);
    expect(id, 'a1');
    expect(r, {'ok': true, 'version': '1.0.0', 'platform': 'android', 'providers': ['kakao'], 'language': null});
  });

  test('setLanguage: 지원 언어면 앱 언어를 바꾸고 저장, 아니면 거절', () async {
    final b = bridge();
    await b.onMessage(msg('g1', 'setLanguage', {'language': 'en-US'}));
    expect(reply(scripts.last).$2, {'ok': true, 'language': 'en'});
    expect(language.value, const Locale('en'));
    expect(savedLanguages, ['en']);

    await b.onMessage(msg('g2', 'setLanguage', {'language': 'ja'}));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'unsupportedLanguage'});
    expect(language.value, const Locale('en'));

    await b.onMessage(msg('g3', 'setLanguage'));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'unsupportedLanguage'});

    await b.onMessage(msg('g4', 'getAppInfo'));
    expect(reply(scripts.last).$2, containsPair('language', 'en'));
  });

  test('setLanguage: 허용 호스트가 아닌 페이지면 무시', () async {
    trusted = false;
    await bridge().onMessage(msg('g5', 'setLanguage', {'language': 'en'}));
    expect(scripts, isEmpty);
    expect(language.value, isNull);
  });

  test('getLocation: 허용이면 좌표, 거부면 사유', () async {
    final b = bridge();
    await b.onMessage(msg('l1', 'getLocation'));
    expect(reply(scripts.last).$2, containsPair('lat', 37.5665));

    location.state = PermissionState.deniedForever;
    await b.onMessage(msg('l2', 'getLocation'));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'deniedForever'});

    location
      ..state = PermissionState.granted
      ..pos = null;
    await b.onMessage(msg('l3', 'getLocation'));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'timeout'});
  });

  test('getLocation: 파라미터가 없으면 예전처럼 정밀하게 12초까지 잰다', () async {
    location.last = const LatLng(1, 2);
    await bridge().onMessage(msg('l4', 'getLocation'));
    expect(reply(scripts.last).$2, containsPair('cached', false));
    expect(location.lastMaxAge, isNull);
    expect(location.measured, (timeout: const Duration(seconds: 12), highAccuracy: true));
  });

  test('getLocation: maximumAgeMs 안의 마지막 위치가 있으면 바로 준다', () async {
    location.last = const LatLng(37.1, 127.2, accuracy: 30);
    await bridge().onMessage(msg('l5', 'getLocation', {'maximumAgeMs': 600000}));
    expect(reply(scripts.last).$2, {'ok': true, 'lat': 37.1, 'lng': 127.2, 'accuracy': 30.0, 'cached': true});
    expect(location.lastMaxAge, const Duration(minutes: 10));
    expect(location.measured, isNull);
  });

  test('getLocation: 마지막 위치가 없으면 요청한 정확도와 시간으로 잰다', () async {
    await bridge().onMessage(msg('l6', 'getLocation', {'maximumAgeMs': 600000, 'highAccuracy': false, 'timeoutMs': 500}));
    expect(reply(scripts.last).$2, containsPair('cached', false));
    expect(location.measured, (timeout: const Duration(seconds: 2), highAccuracy: false));
  });

  test('signIn 은 nonce 를 넘기고 자격 증명을 돌려준다', () async {
    auth.next = const SocialCredential(provider: AuthProvider.kakao, idToken: 'id.t', accessToken: 'at');
    await bridge().onMessage(msg('s1', 'signIn', {'provider': 'kakao', 'nonce': 'n-1'}));
    expect(auth.lastNonce, 'n-1');
    expect(reply(scripts.single).$2, {'ok': true, 'provider': 'kakao', 'idToken': 'id.t', 'accessToken': 'at'});
  });

  test('signIn 취소·실패·모르는 제공자', () async {
    final b = bridge();
    auth.next = SignInCancelled();
    await b.onMessage(msg('s1', 'signIn', {'provider': 'kakao', 'nonce': 'n'}));
    expect(reply(scripts.last).$2, {'ok': false, 'provider': 'kakao', 'reason': 'cancelled'});

    auth.next = SignInFailed('KOE');
    await b.onMessage(msg('s2', 'signIn', {'provider': 'kakao'}));
    expect(reply(scripts.last).$2, containsPair('reason', 'failed'));
    expect(auth.lastNonce, isNull);

    await b.onMessage(msg('s3', 'signIn', {'provider': 'naver'}));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'unknownProvider'});
  });

  test('로그인 진행 중 두 번째 signIn 은 busy', () async {
    auth.next = const SocialCredential(provider: AuthProvider.kakao, idToken: 'x');
    final b = bridge();
    await Future.wait([
      b.onMessage(msg('p1', 'signIn', {'provider': 'kakao'})),
      b.onMessage(msg('p2', 'signIn', {'provider': 'kakao'})),
    ]);
    final results = {for (final s in scripts) reply(s).$1: reply(s).$2};
    expect(results['p1']!['ok'], true);
    expect(results['p2'], {'ok': false, 'reason': 'busy'});
  });

  test('openDirections 파라미터 검사', () async {
    final b = bridge();
    await b.onMessage(msg('d1', 'openDirections', {'lat': 37.1, 'lng': '127.2', 'name': '역'}));
    expect(reply(scripts.last).$2, {'ok': true, 'app': 'kakaomap'});
    expect(launcher.opened.single, '37.1,127.2,역');
    await b.onMessage(msg('d2', 'openDirections', {'lat': 'x'}));
    expect(reply(scripts.last).$2, {'ok': false, 'reason': 'invalidParams'});
  });

  test('허용되지 않은 페이지·깨진 메시지는 무시, 모르는 메서드는 응답', () async {
    final b = bridge();
    trusted = false;
    await b.onMessage(msg('x1', 'getAppInfo'));
    trusted = true;
    await b.onMessage('not json');
    await b.onMessage(jsonEncode({'method': 'getAppInfo'}));
    expect(scripts, isEmpty);
    await b.onMessage(msg('x2', 'selfDestruct'));
    expect(reply(scripts.single).$2, {'ok': false, 'reason': 'unknownMethod'});
  });

  test('응답 스크립트는 requestId 를 문자열 리터럴로 이스케이프한다', () {
    final s = bridgeReplyScript('a"); alert(1); ("', {'t': 'x${String.fromCharCode(0x2028)}y'});
    expect(s, contains(r'"a\"); alert(1); (\""'));
    expect(s, isNot(contains(String.fromCharCode(0x2028))));
    expect(s, contains(r'x\u2028y'));
  });

  group('NavigationPolicy', () {
    const p = NavigationPolicy({'mashil.example', '10.0.2.2'});
    test('허용 호스트만 웹뷰, 나머지는 외부, 위험 스킴은 차단', () {
      expect(p.decide(Uri.parse('https://mashil.example/toilets/1')), NavigationTarget.webView);
      expect(p.decide(Uri.parse('http://10.0.2.2:5099/dev/bridge')), NavigationTarget.webView);
      expect(p.decide(Uri.parse('https://map.kakao.com/')), NavigationTarget.external);
      expect(p.decide(Uri.parse('tel:0212345678')), NavigationTarget.external);
      expect(p.decide(Uri.parse('kakaomap://route?ep=1,2')), NavigationTarget.external);
      expect(p.decide(Uri.parse('javascript:alert(1)')), NavigationTarget.block);
      expect(p.decide(Uri.parse('file:///etc/hosts')), NavigationTarget.block);
      expect(p.isTrusted(Uri.parse('https://evil.example/')), isFalse);
      expect(p.isTrusted(Uri.parse('https://mashil.example/')), isTrue);
    });
  });

  group('VersionChecker', () {
    test('버전 비교와 판정', () {
      expect(VersionChecker.compare('1.2.10', '1.2.9'), 1);
      expect(VersionChecker.compare('1.2', '1.2.0'), 0);
      expect(VersionChecker.compare('1.0.0-beta+3', '1.0.1'), -1);
      expect(VersionChecker.decide('1.0.0', '1.1.0', '1.2.0', 's').kind, UpdateKind.required);
      expect(VersionChecker.decide('1.1.0', '1.1.0', '1.2.0', 's').kind, UpdateKind.recommended);
      expect(VersionChecker.decide('1.2.0', '1.1.0', '1.2.0', 's').kind, UpdateKind.none);
      expect(VersionChecker.decide('1.2.0', null, null, null).kind, UpdateKind.none);
    });
  });

  test('AppConfig 기본값은 에뮬레이터에서 PC 의 개발 서버', () {
    final c = AppConfig.fromEnvironment();
    expect(c.webBaseUrl.host, '10.0.2.2');
    expect(c.allowedHosts, contains('10.0.2.2'));
  });
}
