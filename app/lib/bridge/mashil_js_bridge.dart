import 'dart:async';

import '../auth/social_auth_service.dart';
import '../services/ad_service.dart';
import '../services/app_language.dart';
import '../services/external_launcher.dart';
import '../services/location_service.dart';
import '../services/share_service.dart';
import 'bridge_message.dart';

typedef RunJavaScript = Future<void> Function(String script);

class AppInfo {
  const AppInfo({required this.version, required this.platform});
  final String version;
  final String platform; // android / ios
}

/// 웹(MashilBridge 채널) ↔ 네이티브 기능. 프로토콜은 docs/03-class-diagram.md "JS 브리지 프로토콜".
///
/// | method | params | 응답 |
/// |---|---|---|
/// | getAppInfo | — | { ok, version, platform, providers, language, ads: { enabled } } |
/// | getLocation | { maximumAgeMs?, highAccuracy?, timeoutMs? } | { ok, lat, lng, accuracy, cached } / { ok:false, reason } |
/// | openSettings | — | { ok } |
/// | openDirections | { lat, lng, name, mode?: walk·car } | { ok, app } (mode 가 없거나 모르는 값이면 walk) |
/// | signIn | { provider, nonce } | { ok, provider, idToken?, accessToken?, authorizationCode?, displayName? } / { ok:false, reason } |
/// | signOut | { provider } | { ok } |
/// | setLanguage | { language: ko·en } | { ok, language } / { ok:false, reason: unsupportedLanguage } |
/// | watchLocation | { highAccuracy?, distanceFilterM? } | { ok } / { ok:false, reason } — 이후 `location` 이벤트 |
/// | stopWatchLocation | — | { ok } |
/// | setAdBanner | { visible } | { ok } / { ok:false, reason: adsDisabled } — 목록·검색 결과, 화장실 상세에서만 켠다 (MON-01) |
/// | share | { target: kakao·system, title, url, description?, address?, buttonTitle? } | { ok, via: kakaoTalk·kakaoWeb·shared } / { ok:false, reason: dismissed·invalidParams·failed } |
///
/// 앱 → 웹 이벤트 (`window.__mashilBridgeEvent(name, data)`):
///
/// | name | data |
/// |---|---|
/// | location | { lat, lng, accuracy, heading? } |
/// | locationError | { reason } — 이 뒤로는 이벤트가 오지 않는다 (다시 watchLocation 해야 함) |
class MashilJsBridge {
  MashilJsBridge({
    required this.runJavaScript,
    required this.location,
    required this.launcher,
    required this.auth,
    required this.appInfo,
    required this.language,
    required this.isTrustedPage,
    required this.share,
    this.shareHosts = const {},
    this.ads,
  });

  static const channelName = 'MashilBridge';

  final RunJavaScript runJavaScript;
  final LocationService location;
  final ExternalLauncher launcher;
  final SocialAuthService auth;
  final AppInfo appInfo;

  /// 앱 화면 언어 — 웹이 setLanguage 로 맞춘다.
  final AppLanguage language;

  /// 현재 웹뷰에 떠 있는 페이지가 허용 호스트인지. 아니면 메시지를 무시한다 (다른 사이트가 브리지를 쓰지 못하게).
  final bool Function() isTrustedPage;

  final ShareService share;

  /// 공유할 수 있는 링크의 호스트 (앱이 띄우는 웹 = 허용 호스트). 다른 주소는 공유하지 않는다.
  final Set<String> shareHosts;

  /// 하단 배너 광고 (꺼져 있으면 null). 웹이 [AdService.wanted] 를 켜고 끈다
  final AdService? ads;

  bool _signInBusy = false;

  /// watchLocation 구독과 그 설정 (앱이 백그라운드에 갔다 오면 같은 설정으로 다시 붙인다).
  StreamSubscription<LatLng>? _watch;
  ({bool highAccuracy, int distanceFilterM})? _watchSettings;
  bool _watchPaused = false;

  /// watchLocation·stopWatchLocation 이 올 때마다 올린다. 권한을 묻는 동안 stop(또는 다른 watch)이 오면
  /// 늦게 끝난 앞의 watch 는 이 값이 달라졌으니 구독하지 않는다 (React 개발 모드는 효과를 두 번 돌려
  /// watch → stop → watch 가 연달아 온다).
  int _watchGen = 0;

  /// 구독 끊기와 붙이기를 차례대로. geolocator 는 스트림 하나를 나눠 쓰므로, 끊기가 끝나기 전에 새로 붙이면
  /// 네이티브 GPS 요청이 남아 꺼지지 않는다 (에뮬레이터에서 확인).
  Future<void> _watchOps = Future.value();
  Future<void> _serial(Future<void> Function() op) =>
      _watchOps = _watchOps.then((_) => op()).catchError((Object _) {});

  Future<void> onMessage(String raw) async {
    final msg = BridgeMessage.tryParse(raw);
    if (msg == null || !isTrustedPage()) return;
    Map<String, Object?> result;
    try {
      result = await handle(msg);
    } catch (e) {
      result = {'ok': false, 'reason': 'error', 'detail': e.toString()};
    }
    await runJavaScript(bridgeReplyScript(msg.requestId, result));
  }

  Future<Map<String, Object?>> handle(BridgeMessage m) async {
    switch (m.method) {
      case 'getAppInfo':
        return {
          'ok': true,
          'version': appInfo.version,
          'platform': appInfo.platform,
          'providers': auth.availableProviders().map((p) => p.name).toList(),
          'language': language.value?.languageCode,
          'ads': {'enabled': ads != null},
        };

      case 'getLocation':
        final state = await location.ensurePermission();
        if (state != PermissionState.granted) return {'ok': false, 'reason': state.name};
        // maximumAgeMs 안의 마지막 위치가 있으면 새로 재지 않고 바로 준다 (cached: true).
        // 예전 웹은 파라미터를 보내지 않으므로 기본값은 예전과 같다 (정밀하게, 12초까지).
        final maxAge = _num(m.params['maximumAgeMs']);
        if (maxAge != null && maxAge > 0) {
          final last = await location.lastKnown(maxAge: Duration(milliseconds: maxAge.round()));
          if (last != null) {
            return {'ok': true, 'lat': last.lat, 'lng': last.lng, 'accuracy': last.accuracy, 'cached': true};
          }
        }
        final timeoutMs = _num(m.params['timeoutMs']);
        final pos = await location.currentPosition(
          highAccuracy: m.params['highAccuracy'] != false,
          timeout: timeoutMs == null
              ? const Duration(seconds: 12)
              : Duration(milliseconds: timeoutMs.clamp(2000, 30000).round()),
        );
        if (pos == null) return {'ok': false, 'reason': 'timeout'};
        return {'ok': true, 'lat': pos.lat, 'lng': pos.lng, 'accuracy': pos.accuracy, 'cached': false};

      case 'openSettings':
        return {'ok': await location.openAppSettings()};

      case 'openDirections':
        final lat = _num(m.params['lat']), lng = _num(m.params['lng']);
        if (lat == null || lng == null) return {'ok': false, 'reason': 'invalidParams'};
        final mode = m.params['mode'] == 'car' ? DirectionsMode.car : DirectionsMode.walk;
        final app = await launcher.openDirections(lat, lng, (m.params['name'] as String?) ?? '목적지', mode: mode);
        return {'ok': app != null, 'app': app};

      case 'signIn':
        final provider = _provider(m.params['provider']);
        if (provider == null) return {'ok': false, 'reason': 'unknownProvider'};
        if (_signInBusy) return {'ok': false, 'reason': 'busy'};
        _signInBusy = true;
        try {
          final nonce = m.params['nonce'];
          final c = await auth.signIn(provider, nonce is String && nonce.isNotEmpty ? nonce : null);
          return c.toJson();
        } on SignInCancelled {
          return {'ok': false, 'provider': provider.name, 'reason': 'cancelled'};
        } on SignInFailed catch (e) {
          return {'ok': false, 'provider': provider.name, 'reason': 'failed', 'detail': e.detail};
        } finally {
          _signInBusy = false;
        }

      case 'signOut':
        final provider = _provider(m.params['provider']);
        if (provider != null) await auth.signOut(provider);
        return {'ok': true};

      case 'watchLocation':
        final gen = ++_watchGen;
        final state = await location.ensurePermission();
        // 권한을 묻는 동안 웹이 그만두었다 (stop 또는 새 watch)
        if (gen != _watchGen) return {'ok': false, 'reason': 'cancelled'};
        if (state != PermissionState.granted) return {'ok': false, 'reason': state.name};
        _watchSettings = (
          highAccuracy: m.params['highAccuracy'] != false,
          distanceFilterM: (_num(m.params['distanceFilterM']) ?? 3).clamp(0, 100).round(),
        );
        _watchPaused = false;
        await _startWatch();
        return {'ok': true};

      case 'stopWatchLocation':
        await stopWatchingLocation();
        return {'ok': true};

      case 'share':
        final title = m.params['title'];
        final url = Uri.tryParse((m.params['url'] as String?) ?? '');
        if (title is! String || title.isEmpty || url == null || !(url.scheme == 'https' || url.scheme == 'http') ||
            !shareHosts.contains(url.host)) {
          return {'ok': false, 'reason': 'invalidParams'};
        }
        final req = ShareRequest(
          title: title,
          url: url,
          description: m.params['description'] as String?,
          address: m.params['address'] as String?,
          buttonTitle: m.params['buttonTitle'] as String?,
        );
        try {
          final outcome = m.params['target'] == 'kakao' ? await share.kakaoTalk(req) : await share.system(req);
          if (outcome == ShareOutcome.dismissed) return {'ok': false, 'reason': 'dismissed'};
          return {'ok': true, 'via': outcome.name};
        } catch (e) {
          return {'ok': false, 'reason': 'failed', 'detail': e.toString()};
        }

      case 'setLanguage':
        final code = m.params['language'];
        if (code is! String || !await language.set(code)) return {'ok': false, 'reason': 'unsupportedLanguage'};
        return {'ok': true, 'language': language.value!.languageCode};

      case 'setAdBanner':
        final a = ads;
        if (a == null) return {'ok': false, 'reason': 'adsDisabled'};
        a.wanted.value = m.params['visible'] == true;
        return {'ok': true};

      default:
        return {'ok': false, 'reason': 'unknownMethod'};
    }
  }

  Future<void> _startWatch() => _serial(() async {
        await _cancelWatch();
        final settings = _watchSettings;
        if (settings == null || _watchPaused) return;
        _listen(settings);
      });

  Future<void> _cancelWatch() async {
    final w = _watch;
    _watch = null;
    await w?.cancel();
  }

  void _listen(({bool highAccuracy, int distanceFilterM}) settings) {
    _watch = location.watch(highAccuracy: settings.highAccuracy, distanceFilterM: settings.distanceFilterM).listen(
      (p) => _emit('location', {
        'lat': p.lat,
        'lng': p.lng,
        'accuracy': p.accuracy,
        if (p.heading != null) 'heading': p.heading,
      }),
      onError: (Object e) {
        // 권한을 도중에 끄거나 위치 서비스를 끄면 스트림이 오류로 끝난다
        unawaited(stopWatchingLocation());
        _emit('locationError', {'reason': 'failed', 'detail': e.toString()});
      },
      cancelOnError: true,
    );
  }

  /// 위치 따라가기를 멈춘다. 웹이 stopWatchLocation 을 보내지 못하고 페이지가 바뀔 때(새로고침, 다른 문서)도 셸이 부른다.
  Future<void> stopWatchingLocation() {
    _watchGen++;
    _watchSettings = null;
    _watchPaused = false;
    return _serial(_cancelWatch);
  }

  /// 앱이 화면에서 내려가면 GPS 를 쉬게 하고, 돌아오면 같은 설정으로 다시 따라간다.
  void pauseLocationWatch() {
    if (_watchSettings == null) return;
    _watchPaused = true;
    unawaited(_serial(_cancelWatch));
  }

  void resumeLocationWatch() {
    if (!_watchPaused) return;
    _watchPaused = false;
    unawaited(_startWatch());
  }

  void dispose() => unawaited(stopWatchingLocation());

  Future<void> _emit(String name, Map<String, Object?> data) async {
    if (!isTrustedPage()) return;
    await runJavaScript(bridgeEventScript(name, data));
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  static AuthProvider? _provider(Object? v) {
    for (final p in AuthProvider.values) {
      if (p.name == v) return p;
    }
    return null;
  }
}
