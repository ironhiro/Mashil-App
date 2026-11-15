import '../auth/social_auth_service.dart';
import '../services/app_language.dart';
import '../services/external_launcher.dart';
import '../services/location_service.dart';
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
/// | getAppInfo | — | { ok, version, platform, providers, language } |
/// | getLocation | { maximumAgeMs?, highAccuracy?, timeoutMs? } | { ok, lat, lng, accuracy, cached } / { ok:false, reason } |
/// | openSettings | — | { ok } |
/// | openDirections | { lat, lng, name } | { ok, app } |
/// | signIn | { provider, nonce } | { ok, provider, idToken?, accessToken?, authorizationCode?, displayName? } / { ok:false, reason } |
/// | signOut | { provider } | { ok } |
/// | setLanguage | { language: ko·en } | { ok, language } / { ok:false, reason: unsupportedLanguage } |
class MashilJsBridge {
  MashilJsBridge({
    required this.runJavaScript,
    required this.location,
    required this.launcher,
    required this.auth,
    required this.appInfo,
    required this.language,
    required this.isTrustedPage,
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

  bool _signInBusy = false;

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
        final app = await launcher.openDirections(lat, lng, (m.params['name'] as String?) ?? '목적지');
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

      case 'setLanguage':
        final code = m.params['language'];
        if (code is! String || !await language.set(code)) return {'ok': false, 'reason': 'unsupportedLanguage'};
        return {'ok': true, 'language': language.value!.languageCode};

      default:
        return {'ok': false, 'reason': 'unknownMethod'};
    }
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  static AuthProvider? _provider(Object? v) {
    for (final p in AuthProvider.values) {
      if (p.name == v) return p;
    }
    return null;
  }
}
