import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../app_config.dart';
import '../bridge/mashil_js_bridge.dart';
import '../l10n/app_localizations.dart';
import '../services/app_status.dart';
import '../services/connectivity_service.dart';
import '../services/external_launcher.dart';
import '../theme.dart';
import 'deep_links.dart';
import 'error_screen.dart';
import 'maintenance_screen.dart';
import 'navigation_policy.dart';

/// 웹(Mashil-web)을 띄우는 화면 (APP-01, 05~08). 저장소(localStorage·쿠키)는 웹뷰 기본값대로 유지된다 (APP-08).
class WebShellScreen extends StatefulWidget {
  const WebShellScreen({
    super.key,
    required this.config,
    required this.bridgeFactory,
    required this.launcher,
    required this.connectivity,
    this.deepLinks,
    this.onFirstShown,
  });

  final AppConfig config;
  final MashilJsBridge Function(RunJavaScript runJs, bool Function() isTrusted) bridgeFactory;
  final ExternalLauncher launcher;
  final ConnectivityService connectivity;

  /// 공유 링크로 열린 주소 (없으면 늘 [AppConfig.webBaseUrl] 부터)
  final DeepLinks? deepLinks;

  /// 첫 페이지가 다 뜨거나(또는 오류 화면이 뜨면) 한 번 불린다. 시작 연출이 이때까지 문을 닫고 기다린다.
  final VoidCallback? onFirstShown;

  @override
  State<WebShellScreen> createState() => _WebShellScreenState();
}

class _WebShellScreenState extends State<WebShellScreen> {
  // 첫 프레임 뒤에 만든다. Android 웹뷰는 만들 때 메인 스레드를 1초 넘게 붙잡아서, initState 에서 만들면
  // 그동안 첫 화면이 안 그려지고 시스템 스플래시만 보인다. 뒤로 미루면 시작 연출(닫힌 문)이 먼저 뜨고 그 뒤에서 만든다.
  WebViewController? _controller;
  late final NavigationPolicy _policy = NavigationPolicy(widget.config.allowedHosts);
  late final MashilJsBridge _bridge = widget.bridgeFactory(
    (js) => _controller?.runJavaScript(js) ?? Future<void>.value(),
    () => _policy.isTrusted(_currentUrl),
  );
  StreamSubscription<bool>? _online;
  StreamSubscription<Uri>? _links;
  // 앱이 화면에서 내려가면 방향 안내의 위치 따라가기(GPS)를 쉬게 한다
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: _bridge.pauseLocationWatch,
    onShow: _bridge.resumeLocationWatch,
  );

  Uri? _currentUrl;
  int _progress = 0;
  bool _firstLoadDone = false;
  // 첫 주소를 불렀는지 (그 전에 온 공유 링크는 첫 주소로 쓴다)
  bool _initialRequested = false;
  // 문서를 새로 불러오는 중인지 (onPageStarted ~ onPageFinished). SPA 화면 전환(pushState)과 지도 타일·API 같은
  // 하위 리소스도 onProgress 를 올리므로, 진행 막대는 이 동안에만 보인다.
  bool _documentLoading = false;
  bool _offline = false;
  String? _loadError;
  // 웹을 불러오지 못했는데 서버가 점검 중이면 네이티브 점검 화면 (웹이 뜨면 웹이 자기 점검 화면을 그린다)
  late final _statusClient = AppStatusClient(widget.config.apiBaseUrl);
  AppStatus? _maintenance;
  bool _checkingStatus = false;
  DateTime? _lastBackAt;
  bool _shown = false;

  void _markShown() {
    if (_shown) return;
    _shown = true;
    widget.onFirstShown?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 첫 페이지가 그려지기 전의 웹뷰 바탕을 앱 바탕(paper)과 같게: 흰 화면이 번쩍이지 않도록
    _controller?.setBackgroundColor(MashilColors.of(context).bg);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle; // late final: 여기서 붙인다
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 첫 프레임이 실제로 화면에 올라가 시스템 스플래시가 걷힐 때까지 기다린다. 그 전환도 메인 스레드에서 일어나서,
      // 너무 일찍(50ms) 만들면 전환이 웹뷰 생성 뒤로 밀린다. 문은 페이지가 뜰 때까지 닫혀 있으므로 이 지연은 보이지 않는다.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final c = WebViewController();
      c.setBackgroundColor(MashilColors.of(context).bg);
      setState(() => _controller = c);
      try {
        await _setUp(c);
      } catch (e) {
        // 웹뷰 설정이 실패하면 오류 화면 (다시 시도는 loadRequest 부터)
        if (!mounted) return;
        setState(() => _loadError = 'setup ($e)');
        _markShown();
      }
    });
    // 앱이 켜져 있을 때 공유 링크를 누르면 그 화장실로. 웹뷰를 만드는 중이면 _setUp 이 takePending 으로 연다
    _links = widget.deepLinks?.links.listen((uri) {
      final c = _controller;
      if (c == null || !_initialRequested) return;
      widget.deepLinks?.takePending();
      setState(() {
        _loadError = null;
        _maintenance = null;
      });
      unawaited(c.loadRequest(uri));
    });
    _online = widget.connectivity.onlineStream.listen((online) {
      if (!mounted) return;
      final wasOffline = _offline;
      setState(() => _offline = !online);
      if (!online) _markShown();
      if (online && (wasOffline || _loadError != null)) _retry();
    });
  }

  Future<void> _setUp(WebViewController c) async {
    final ua = await c.getUserAgent();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _lockDown(c);
    // 웹이 앱 안인지 알 수 있게 UA 끝에 붙인다 (브리지 유무로도 판별 가능)
    await c.setUserAgent('${ua ?? ''} MashilApp/${_bridge.appInfo.version} (${_bridge.appInfo.platform})'.trim());
    await c.addJavaScriptChannel(
      MashilJsBridge.channelName,
      onMessageReceived: (m) => _bridge.onMessage(m.message),
    );
    await c.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (req) async {
        final uri = Uri.tryParse(req.url);
        if (uri == null) return NavigationDecision.prevent;
        switch (_policy.decide(uri)) {
          case NavigationTarget.webView:
            return NavigationDecision.navigate;
          case NavigationTarget.external:
            await widget.launcher.openExternal(uri);
            return NavigationDecision.prevent;
          case NavigationTarget.block:
            return NavigationDecision.prevent;
        }
      },
      onUrlChange: (c) => _currentUrl = c.url == null ? _currentUrl : Uri.tryParse(c.url!),
      onPageStarted: (url) {
        _currentUrl = Uri.tryParse(url);
        // 문서를 새로 부르면 이전 페이지의 위치 구독자는 사라진다 (새로고침 등). GPS 를 끈다
        unawaited(_bridge.stopWatchingLocation());
        if (mounted) setState(() => _documentLoading = true);
      },
      onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      onPageFinished: (url) {
        _currentUrl = Uri.tryParse(url);
        c.runJavaScript("window.dispatchEvent(new Event('mashilbridgeready'));");
        if (mounted) {
          setState(() {
            _firstLoadDone = true;
            _documentLoading = false;
          });
        }
        _markShown();
      },
      onWebResourceError: (e) {
        if (e.isForMainFrame != true || !mounted) return;
        setState(() => _loadError = '${e.errorType?.name ?? 'error'} (${e.errorCode})');
        _markShown();
        unawaited(_checkMaintenance(null));
      },
      onHttpError: (e) {
        // 문서 자체가 5xx 면 오류 화면. 4xx 는 웹이 처리하도록 둔다.
        final code = e.response?.statusCode ?? 0;
        if (code >= 500 && e.request?.uri == _currentUrl && mounted) {
          setState(() => _loadError = 'HTTP $code');
          _markShown();
          unawaited(_checkMaintenance(code));
        }
      },
    ));
    // 링크가 이 직전에 왔으면 pending 에 남아 있다: 여기서 꺼내 연다. 이 뒤로 오는 링크는 _links 가 연다
    _initialRequested = true;
    await c.loadRequest(widget.deepLinks?.takePending() ?? widget.config.webBaseUrl);
  }

  /// 웹 페이지처럼 보이게 하는 웹뷰 기본 동작을 끈다. 텍스트 선택·길게 누르기 메뉴·이미지 끌기·더블탭 확대는
  /// 웹이 앱 안(UA 의 MashilApp/)일 때 CSS 로 끈다 (Mashil-web src/styles/base.css `html.in-app`).
  Future<void> _lockDown(WebViewController c) async {
    // 개발자 도구: 운영(release) 빌드에서는 Chrome(chrome://inspect)·Safari 웹 속성으로 붙을 수 없게. debug·profile 은 열어 둔다.
    const inspectable = !kReleaseMode;
    // 손가락 두 개로 페이지 전체 확대 금지. 지도는 자체 터치 처리로 계속 확대·축소된다.
    await c.enableZoom(false);
    // 끝까지 스크롤했을 때 페이지가 튕기거나(iOS) 늘어나는(Android) 효과 끔
    await c.setOverScrollMode(WebViewOverScrollMode.never);
    final p = c.platform;
    if (p is AndroidWebViewController) {
      await AndroidWebViewController.enableDebugging(inspectable);
      await p.setMediaPlaybackRequiresUserGesture(true);
    } else if (p is WebKitWebViewController) {
      await p.setInspectable(inspectable);
      // 링크를 길게 눌렀을 때 뜨는 미리보기(peek)는 끈다.
      await p.setAllowsLinkPreview(false);
      // 왼쪽 가장자리에서 밀어 웹 history 뒤로 가기는 켠다 (iOS 사용자가 기대하는 뒤로 가기. Android 의 뒤로 버튼 역할)
      await p.setAllowsBackForwardNavigationGestures(true);
    }
  }

  /// 문서를 못 불러왔을 때 점검 중인지 서버에 묻는다. 오프라인이면 묻지 않는다 (오프라인 화면이 먼저)
  Future<void> _checkMaintenance(int? httpCode) async {
    if (_offline) return;
    final s = await _statusClient.fetch();
    if (!mounted || _loadError == null) return; // 그새 다시 불러와 떴으면 그대로
    setState(() => _maintenance = AppStatus.maintenanceFor(s, httpCode));
  }

  Future<void> _retry() async {
    final c = _controller;
    if (c == null) return; // 아직 만드는 중: 만들고 나면 알아서 첫 페이지를 부른다
    if (_maintenance != null) {
      // 점검 화면의 "다시 확인": 아직 점검이면 화면을 그대로 두고 시각·안내만 새로
      setState(() => _checkingStatus = true);
      final s = await _statusClient.fetch();
      if (!mounted) return;
      final still = s == null ? _maintenance : (s.maintenance ? s : null);
      setState(() {
        _checkingStatus = false;
        _maintenance = still;
      });
      if (still != null && s != null) return;
      // 상태를 못 받았으면(서버가 아직 내려가 있음) 웹을 다시 불러 본다. 503 이면 다시 점검 화면이 된다
    }
    setState(() {
      _loadError = null;
      _maintenance = null;
    });
    if (_currentUrl != null && _firstLoadDone) {
      await c.reload();
    } else {
      await c.loadRequest(widget.config.webBaseUrl);
    }
  }

  // Android 뒤로가기: 웹 history → 없으면 "한 번 더 누르면 종료" (APP-05)
  Future<void> _onBack() async {
    final c = _controller;
    if (c != null && await c.canGoBack()) {
      await c.goBack();
      return;
    }
    final now = DateTime.now();
    if (_lastBackAt != null && now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).pressBackAgainToExit), duration: const Duration(seconds: 2)));
  }

  @override
  void dispose() {
    _online?.cancel();
    _links?.cancel();
    _lifecycle.dispose();
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showError = _offline || _loadError != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        // 아래쪽은 웹뷰가 시스템 제스처 막대 밑까지 그린다. 웹이 env(safe-area-inset-bottom) 로 하단 탭과 하단 바를
        // 그 위로 올린다 (여기서도 띄우면 여백이 두 번 생겨 하단 탭 아래에 빈 띠가 남는다).
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              if (_controller case final c?)
                WebViewWidget(controller: c)
              else
                ColoredBox(color: MashilColors.of(context).bg, child: const SizedBox.expand()),
              // 첫 로드는 보통 시작 연출(닫힌 문) 뒤에서 끝난다. 그보다 늦거나 문서를 새로 불러올 때만 위쪽 가는 줄.
              // 웹 안의 화면 전환에는 띄우지 않는다 (웹이 자기 로딩 표시를 한다).
              if ((!_firstLoadDone || (_documentLoading && _progress < 100)) && !showError)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(value: _firstLoadDone ? _progress / 100 : null),
                ),
              if (showError)
                Positioned.fill(
                  child: !_offline && _maintenance != null
                      ? MaintenanceScreen(
                          status: _maintenance!,
                          retrying: _checkingStatus,
                          onRetry: _retry,
                          onOpenKakaoMap: () => widget.launcher.openKakaoMapSearch('화장실'),
                        )
                      : ErrorScreen(offline: _offline, detail: _loadError, onRetry: _retry),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
