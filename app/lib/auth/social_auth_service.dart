import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app_config.dart';

enum AuthProvider { kakao, google, apple }

/// IdP 에서 받은 자격 증명. 서버(`POST /api/auth/oauth/{provider}`)가 직접 검증한다 — 앱은 내용을 믿지 않는다.
class SocialCredential {
  const SocialCredential({required this.provider, this.idToken, this.accessToken, this.authorizationCode, this.displayName});

  final AuthProvider provider;
  final String? idToken;
  final String? accessToken;
  final String? authorizationCode;

  /// Apple 은 이름을 첫 로그인 때만 준다 → 서버에 기본 표시 이름으로 넘긴다.
  final String? displayName;

  Map<String, Object?> toJson() => {
        'ok': true,
        'provider': provider.name,
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
        if (authorizationCode != null) 'authorizationCode': authorizationCode,
        if (displayName != null) 'displayName': displayName,
      };
}

class SignInCancelled implements Exception {}

class SignInFailed implements Exception {
  SignInFailed(this.detail);
  final String detail;
  @override
  String toString() => 'SignInFailed: $detail';
}

abstract interface class SocialSignInProvider {
  Future<SocialCredential> signIn(String? nonce);
  Future<void> signOut();
}

/// 웹뷰 안에서 OAuth 를 하지 않고 네이티브 SDK 로 로그인한다 (APP-12, Google 은 웹뷰 로그인 차단).
class SocialAuthService {
  SocialAuthService(AppConfig config) {
    if (config.kakaoNativeAppKey != null) _providers[AuthProvider.kakao] = KakaoSignInProvider();
    final googleReady = Platform.isIOS ? config.googleIosClientId != null : config.googleServerClientId != null;
    if (googleReady) _providers[AuthProvider.google] = GoogleSignInProvider(config);
    if (Platform.isIOS) _providers[AuthProvider.apple] = AppleSignInProvider(); // 스토어 요건 STO-04
  }

  final _providers = <AuthProvider, SocialSignInProvider>{};

  List<AuthProvider> availableProviders() => _providers.keys.toList();

  Future<SocialCredential> signIn(AuthProvider p, String? nonce) {
    final provider = _providers[p];
    if (provider == null) throw SignInFailed('${p.name} 로그인을 쓸 수 없음 (설정 또는 플랫폼)');
    return provider.signIn(nonce);
  }

  Future<void> signOut(AuthProvider p) async => _providers[p]?.signOut();
}

class KakaoSignInProvider implements SocialSignInProvider {
  @override
  Future<SocialCredential> signIn(String? nonce) async {
    try {
      // 카카오톡이 있으면 앱 전환 로그인, 없거나 실패하면 카카오계정(브라우저) 로그인
      kakao.OAuthToken token;
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          token = await kakao.UserApi.instance.loginWithKakaoTalk(nonce: nonce);
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED') throw SignInCancelled();
          token = await kakao.UserApi.instance.loginWithKakaoAccount(nonce: nonce);
        }
      } else {
        token = await kakao.UserApi.instance.loginWithKakaoAccount(nonce: nonce);
      }
      // OIDC 를 켜면 idToken 이 온다. accessToken 은 서버가 탈퇴 시 연결 끊기에 쓴다.
      return SocialCredential(provider: AuthProvider.kakao, idToken: token.idToken, accessToken: token.accessToken);
    } on SignInCancelled {
      rethrow;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw SignInCancelled();
      throw SignInFailed('kakao ${e.code}: ${e.message}');
    } on kakao.KakaoAuthException catch (e) {
      if (e.error == kakao.AuthErrorCause.accessDenied) throw SignInCancelled();
      throw SignInFailed('kakao auth ${e.error}: ${e.errorDescription}');
    } on kakao.KakaoException catch (e) {
      throw SignInFailed('kakao $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {
      // 이미 토큰이 없으면 실패해도 된다
    }
  }
}

class GoogleSignInProvider implements SocialSignInProvider {
  GoogleSignInProvider(this._config);
  final AppConfig _config;
  Future<void>? _init;

  // google_sign_in 7: initialize 는 한 번만. nonce 는 그때 고정되므로 Google 은 서버에서 nonce 를 요구하지 않는다.
  Future<void> _ensureInit() => _init ??= GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? _config.googleIosClientId : null,
        serverClientId: _config.googleServerClientId,
      );

  @override
  Future<SocialCredential> signIn(String? nonce) async {
    await _ensureInit();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw SignInFailed('google idToken 없음 (serverClientId 확인)');
      return SocialCredential(provider: AuthProvider.google, idToken: idToken, displayName: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SignInCancelled();
      throw SignInFailed('google ${e.code}: ${e.description}');
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInit();
    await GoogleSignIn.instance.signOut();
  }
}

class AppleSignInProvider implements SocialSignInProvider {
  @override
  Future<SocialCredential> signIn(String? nonce) async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.fullName],
        // Apple 에는 원문의 SHA-256 을 넣는다. 서버는 원문/해시 둘 다 받는다.
        nonce: nonce == null ? null : sha256.convert(utf8.encode(nonce)).toString(),
      );
      final name = [c.familyName, c.givenName].where((s) => s != null && s.isNotEmpty).join('');
      return SocialCredential(
        provider: AuthProvider.apple,
        idToken: c.identityToken,
        authorizationCode: c.authorizationCode,
        displayName: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SignInCancelled();
      throw SignInFailed('apple ${e.code}: ${e.message}');
    }
  }

  @override
  Future<void> signOut() async {} // Apple 은 앱 쪽 세션이 없다
}
