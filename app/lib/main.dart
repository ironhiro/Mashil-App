import 'dart:io' show Platform;

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';
import 'auth/social_auth_service.dart';
import 'l10n/app_localizations.dart';
import 'bridge/mashil_js_bridge.dart';
import 'services/ad_service.dart';
import 'services/app_language.dart';
import 'services/connectivity_service.dart';
import 'services/external_launcher.dart';
import 'services/location_service.dart';
import 'services/share_service.dart';
import 'services/version_checker.dart';
import 'shell/deep_links.dart';
import 'shell/splash_gate.dart';
import 'shell/web_shell_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  // 공유 링크로 열렸을 때 (App Links). MaterialApp 보다 먼저 붙여야 링크가 앱 Navigator 로 가지 않는다
  final deepLinks = DeepLinks(
    config.webBaseUrl,
    initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
  WidgetsBinding.instance.addObserver(deepLinks);
  // 카카오 SDK 초기화는 에뮬레이터에서 0.7초쯤 걸린다. 첫 화면을 그 뒤로 미루지 않고 뒤에서 돌리고,
  // 카카오 로그인·로그아웃 직전에만 기다린다 (SocialAuthService).
  final kakaoReady = config.kakaoNativeAppKey == null
      ? null
      : kakao.KakaoSdk.init(nativeAppKey: config.kakaoNativeAppKey);
  final (info, language) = await (
    PackageInfo.fromPlatform(),
    AppLanguage.load(AppLocalizations.supportedLocales),
  ).wait;
  runApp(
    MashilApp(
      config: config,
      deepLinks: deepLinks,
      kakaoReady: kakaoReady,
      language: language,
      appInfo: AppInfo(
        version: info.version,
        platform: Platform.isIOS ? 'ios' : 'android',
      ),
    ),
  );
}

class MashilApp extends StatelessWidget {
  const MashilApp({
    super.key,
    required this.config,
    required this.deepLinks,
    required this.appInfo,
    required this.language,
    this.kakaoReady,
  });

  final AppConfig config;
  final DeepLinks deepLinks;

  /// 카카오 SDK 초기화 (키가 없으면 null)
  final Future<void>? kakaoReady;
  final AppInfo appInfo;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final launcher = ExternalLauncher();
    final location = LocationService();
    final auth = SocialAuthService(config, kakaoReady: kakaoReady);
    // 홈(웹뷰)은 한 번만 만들고, 언어가 바뀌면 MaterialApp 만 다시 그린다 (웹뷰를 새로 만들지 않음).
    // 시작 연출(닫힌 문이 열림)은 웹뷰 위에 덮이고, 웹뷰는 그 뒤에서 이미 불러온다.
    // 첫 페이지가 뜨면 true: 시작 연출은 그때까지 닫힌 문으로 기다린다 (빈 웹뷰가 보이지 않도록)
    final webShown = ValueNotifier(false);
    final ads = config.adsEnabled ? AdMobService(config.bannerUnitIdFor(appInfo.platform)) : null;
    final home = SplashGate(
      ready: webShown,
      child: _VersionGate(
        checker: VersionChecker(config.apiBaseUrl),
        appInfo: appInfo,
        child: WebShellScreen(
          config: config,
          deepLinks: deepLinks,
          launcher: launcher,
          connectivity: ConnectivityService(),
          ads: ads,
          onFirstShown: () {
            webShown.value = true;
            // 광고 SDK 는 시작 연출이 끝난 뒤에 (첫 화면을 늦추지 않도록)
            Future<void>.delayed(
              SplashGate.startDelay + SplashGate.total + const Duration(milliseconds: 300),
              () => ads?.start(),
            );
          },
          bridgeFactory: (runJs, isTrusted) => MashilJsBridge(
            runJavaScript: runJs,
            location: location,
            launcher: launcher,
            auth: auth,
            appInfo: appInfo,
            language: language,
            isTrustedPage: isTrusted,
            share: ShareService(),
            shareHosts: config.allowedHosts,
            ads: ads,
          ),
        ),
      ),
    );
    return ValueListenableBuilder<Locale?>(
      valueListenable: language,
      child: home,
      builder: (context, locale, home) => MaterialApp(
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
        // 웹이 setLanguage 로 알려 준 언어 (null 이면 기기 언어, 지원 안 하면 첫 항목인 ko)
        locale: locale,
        // Material·Cupertino·Widgets 셋 다. Cupertino 가 빠지면 iOS 에서 ko 로케일 경고가 난다
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // 대만·홍콩 기기(zh-TW)가 간체로 가지 않게 중국어는 글자 체계로 고른다
        localeListResolutionCallback: (device, supported) => AppLanguage.resolve(device, supported),
        debugShowCheckedModeBanner: false,
        theme: mashilTheme(Brightness.light),
        darkTheme: mashilTheme(Brightness.dark),
        // 링크로 켜지면 시작 경로가 /toilets/12 처럼 온다. 앱 화면은 하나뿐이니 늘 홈 (주소는 웹뷰가 연다, DeepLinks).
        // home 과 onGenerateInitialRoutes 는 같이 줄 수 없다 (Flutter assert) → 홈은 onGenerateRoute 로
        onGenerateInitialRoutes: (_) => [MaterialPageRoute<void>(builder: (_) => home!)],
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => home!),
      ),
    );
  }
}

/// 시작 시 버전 확인 (APP-09). 강제 업데이트면 닫을 수 없는 안내, 권장이면 한 번 안내.
class _VersionGate extends StatefulWidget {
  const _VersionGate({
    required this.checker,
    required this.appInfo,
    required this.child,
  });

  final VersionChecker checker;
  final AppInfo appInfo;
  final Widget child;

  @override
  State<_VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<_VersionGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final r = await widget.checker.check(
      widget.appInfo.platform,
      widget.appInfo.version,
    );
    if (!mounted || r.kind == UpdateKind.none) return;
    final force = r.kind == UpdateKind.required;
    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        return PopScope(
          canPop: !force,
          child: AlertDialog(
            title: Text(force ? l.updateRequiredTitle : l.updateAvailableTitle),
            content: Text(force ? l.updateRequiredBody : l.updateAvailableBody),
            actions: [
              if (!force)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l.later),
                ),
              FilledButton(
                onPressed: r.storeUrl == null
                    ? null
                    : () => launchUrl(
                        Uri.parse(r.storeUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                child: Text(l.update),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
