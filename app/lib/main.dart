import 'dart:io' show Platform;

import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';
import 'auth/social_auth_service.dart';
import 'l10n/app_localizations.dart';
import 'bridge/mashil_js_bridge.dart';
import 'services/app_language.dart';
import 'services/connectivity_service.dart';
import 'services/external_launcher.dart';
import 'services/location_service.dart';
import 'services/version_checker.dart';
import 'shell/splash_gate.dart';
import 'shell/web_shell_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.kakaoNativeAppKey != null) {
    await kakao.KakaoSdk.init(nativeAppKey: config.kakaoNativeAppKey);
  }
  final info = await PackageInfo.fromPlatform();
  final language = await AppLanguage.load(AppLocalizations.supportedLocales);
  runApp(
    MashilApp(
      config: config,
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
    required this.appInfo,
    required this.language,
  });

  final AppConfig config;
  final AppInfo appInfo;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final launcher = ExternalLauncher();
    final location = LocationService();
    final auth = SocialAuthService(config);
    // 홈(웹뷰)은 한 번만 만들고, 언어가 바뀌면 MaterialApp 만 다시 그린다 (웹뷰를 새로 만들지 않음).
    // 시작 연출(닫힌 문이 열림)은 웹뷰 위에 덮이고, 웹뷰는 그 뒤에서 이미 불러온다.
    final home = SplashGate(
      child: _VersionGate(
        checker: VersionChecker(config.apiBaseUrl),
        appInfo: appInfo,
        child: WebShellScreen(
          config: config,
          launcher: launcher,
          connectivity: ConnectivityService(),
          bridgeFactory: (runJs, isTrusted) => MashilJsBridge(
            runJavaScript: runJs,
            location: location,
            launcher: launcher,
            auth: auth,
            appInfo: appInfo,
            language: language,
            isTrustedPage: isTrusted,
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        debugShowCheckedModeBanner: false,
        theme: mashilTheme(Brightness.light),
        darkTheme: mashilTheme(Brightness.dark),
        home: home,
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
