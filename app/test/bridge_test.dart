import 'dart:async';
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
import 'package:mashil/services/share_service.dart';
import 'package:mashil/services/version_checker.dart';
import 'package:mashil/shell/navigation_policy.dart';

class FakeLocation implements LocationService {
  PermissionState state = PermissionState.granted;
  LatLng? pos = const LatLng(37.5665, 126.978, accuracy: 12);
  LatLng? last;
  Duration? lastMaxAge;
  ({Duration timeout, bool highAccuracy})? measured;
  /// 있으면 권한 확인이 이것이 끝날 때까지 기다린다 (권한 창이 떠 있는 동안)
  Completer<void>? permissionGate;
  @override
  Future<PermissionState> ensurePermission() async {
    await permissionGate?.future;
    return state;
  }
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

  /// watch() 로 붙은 스트림. add 로 위치를 흘려 보낸다.
  StreamController<LatLng>? watching;
  ({bool highAccuracy, int distanceFilterM})? watchedWith;
  int watchStarts = 0;
  @override
  Stream<LatLng> watch({bool highAccuracy = true, int distanceFilterM = 3}) {
    watchStarts++;
    watchedWith = (highAccuracy: highAccuracy, distanceFilterM: distanceFilterM);
    final c = StreamController<LatLng>();
    c.onCancel = () => watching = null;
    watching = c;
    return c.stream;
  }
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

class FakeShare implements ShareService {
  final requests = <(String, ShareRequest)>[];
  ShareOutcome next = ShareOutcome.kakaoTalk;
  Object? error;
  @override
  Future<ShareOutcome> kakaoTalk(ShareRequest r) async {
    requests.add(('kakao', r));
    if (error != null) throw error!;
    return next;
  }

  @override
  Future<ShareOutcome> system(ShareRequest r) async {
    requests.add(('system', r));
    if (error != null) throw error!;
    return next;
  }
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
  late FakeShare share;
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
        share: share,
        shareHosts: const {'mashil.example'},
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
    share = FakeShare();
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

  group('watchLocation', () {
    /// 이벤트 스크립트에서 (name, data) 를 꺼낸다.
    (String, Map<String, dynamic>) event(String script) {
      final m = RegExp(r'__mashilBridgeEvent\((".*?"), (\{.*\})\);$').firstMatch(script)!;
      return (jsonDecode(m.group(1)!) as String, jsonDecode(m.group(2)!) as Map<String, dynamic>);
    }

    test('허용이면 구독하고 위치를 location 이벤트로 보낸다', () async {
      final b = bridge();
      await b.onMessage(msg('w1', 'watchLocation', {'distanceFilterM': 5}));
      expect(reply(scripts.last).$2, {'ok': true});
      expect(location.watchedWith, (highAccuracy: true, distanceFilterM: 5));

      location.watching!.add(const LatLng(37.5, 127.0, accuracy: 8, heading: 90));
      await pumpEventQueue();
      final (name, data) = event(scripts.last);
      expect(name, 'location');
      expect(data, {'lat': 37.5, 'lng': 127.0, 'accuracy': 8.0, 'heading': 90.0});

      // 방향을 모르면 heading 은 빠진다
      location.watching!.add(const LatLng(37.6, 127.1, accuracy: 9));
      await pumpEventQueue();
      expect(event(scripts.last).$2.containsKey('heading'), isFalse);
    });

    test('권한이 없으면 사유를 주고 구독하지 않는다', () async {
      location.state = PermissionState.denied;
      await bridge().onMessage(msg('w2', 'watchLocation'));
      expect(reply(scripts.last).$2, {'ok': false, 'reason': 'denied'});
      expect(location.watchStarts, 0);
    });

    test('stopWatchLocation 이면 구독을 끊는다', () async {
      final b = bridge();
      await b.onMessage(msg('w3', 'watchLocation'));
      await b.onMessage(msg('w4', 'stopWatchLocation'));
      expect(reply(scripts.last).$2, {'ok': true});
      expect(location.watching, isNull);
    });

    test('다시 watchLocation 하면 이전 구독은 끊고 새로 붙인다', () async {
      final b = bridge();
      await b.onMessage(msg('w5', 'watchLocation'));
      final first = location.watching!;
      await b.onMessage(msg('w6', 'watchLocation', {'highAccuracy': false}));
      expect(first.hasListener, isFalse);
      expect(location.watchStarts, 2);
      expect(location.watchedWith?.highAccuracy, isFalse);
    });

    test('권한을 묻는 동안 stop 이 오면 늦게 끝난 watch 는 구독하지 않는다', () async {
      final b = bridge();
      location.permissionGate = Completer();
      final watching = b.onMessage(msg('r1', 'watchLocation'));
      await b.onMessage(msg('r2', 'stopWatchLocation'));
      location.permissionGate!.complete();
      await watching;
      expect(reply(scripts.last).$2, {'ok': false, 'reason': 'cancelled'});
      expect(location.watchStarts, 0);
    });

    test('watch → stop → watch 가 연달아 와도 구독은 하나만 남는다', () async {
      final b = bridge();
      location.permissionGate = Completer();
      final first = b.onMessage(msg('r3', 'watchLocation'));
      await b.onMessage(msg('r4', 'stopWatchLocation'));
      final second = b.onMessage(msg('r5', 'watchLocation'));
      location.permissionGate!.complete();
      await Future.wait([first, second]);
      expect(location.watchStarts, 1);
      expect(location.watching, isNotNull);
      await b.onMessage(msg('r6', 'stopWatchLocation'));
      expect(location.watching, isNull);
    });

    test('스트림 오류면 locationError 를 보내고 멈춘다', () async {
      final b = bridge();
      await b.onMessage(msg('w7', 'watchLocation'));
      location.watching!.addError(Exception('off'));
      await pumpEventQueue();
      expect(event(scripts.last).$1, 'locationError');
      b.resumeLocationWatch();
      expect(location.watchStarts, 1);
    });

    test('앱이 내려가면 쉬고, 돌아오면 같은 설정으로 다시 붙는다', () async {
      final b = bridge();
      await b.onMessage(msg('w8', 'watchLocation', {'distanceFilterM': 7}));
      b.pauseLocationWatch();
      await pumpEventQueue();
      expect(location.watching, isNull);
      b.resumeLocationWatch();
      await pumpEventQueue();
      expect(location.watchStarts, 2);
      expect(location.watchedWith?.distanceFilterM, 7);
    });

    test('멈춘 뒤에는 돌아와도 다시 붙지 않는다', () async {
      final b = bridge();
      await b.onMessage(msg('w9', 'watchLocation'));
      b.pauseLocationWatch();
      await b.stopWatchingLocation();
      b.resumeLocationWatch();
      await pumpEventQueue();
      expect(location.watchStarts, 1);
    });

    test('허용 호스트가 아닌 페이지로 바뀌면 위치를 보내지 않는다', () async {
      final b = bridge();
      await b.onMessage(msg('w10', 'watchLocation'));
      final before = scripts.length;
      trusted = false;
      location.watching!.add(const LatLng(1, 2));
      await pumpEventQueue();
      expect(scripts.length, before);
    });
  });

  group('share', () {
    Map<String, Object?> p([Map<String, Object?> extra = const {}]) => {
          'target': 'kakao',
          'title': '세종문화회관 화장실',
          'url': 'https://mashil.example/toilets/66',
          'address': '서울특별시 종로구 세종대로 175',
          ...extra,
        };

    test('카카오톡: 주소가 있으면 위치 카드로 넘기고 경로를 알려 준다', () async {
      await bridge().onMessage(msg('h1', 'share', p({'buttonTitle': '마실에서 보기'})));
      expect(reply(scripts.single).$2, {'ok': true, 'via': 'kakaoTalk'});
      final (target, r) = share.requests.single;
      expect(target, 'kakao');
      expect(r.url, Uri.parse('https://mashil.example/toilets/66'));
      expect(r.address, '서울특별시 종로구 세종대로 175');
      expect(r.buttonTitle, '마실에서 보기');
    });

    test('시스템 공유 창을 닫으면 dismissed', () async {
      share.next = ShareOutcome.dismissed;
      await bridge().onMessage(msg('h2', 'share', p({'target': 'system'})));
      expect(share.requests.single.$1, 'system');
      expect(reply(scripts.single).$2, {'ok': false, 'reason': 'dismissed'});
    });

    test('허용 호스트가 아닌 주소나 제목 없는 요청은 공유하지 않는다', () async {
      final b = bridge();
      await b.onMessage(msg('h3', 'share', p({'url': 'https://evil.example/x'})));
      await b.onMessage(msg('h4', 'share', p({'url': 'javascript:alert(1)'})));
      await b.onMessage(msg('h5', 'share', p({'title': ''})));
      expect(share.requests, isEmpty);
      for (final s in scripts) {
        expect(reply(s).$2, {'ok': false, 'reason': 'invalidParams'});
      }
    });

    test('SDK 오류는 failed 로', () async {
      share.error = Exception('KakaoClientException');
      await bridge().onMessage(msg('h6', 'share', p()));
      expect(reply(scripts.single).$2, containsPair('reason', 'failed'));
    });
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
