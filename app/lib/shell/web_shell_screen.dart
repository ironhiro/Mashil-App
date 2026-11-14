import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_config.dart';
import '../bridge/mashil_js_bridge.dart';
import '../l10n/app_localizations.dart';
import '../services/connectivity_service.dart';
import '../services/external_launcher.dart';
import 'error_screen.dart';
import 'navigation_policy.dart';

/// 웹(Mashil-web)을 띄우는 화면 (APP-01, 05~08). 저장소(localStorage·쿠키)는 웹뷰 기본값대로 유지된다 (APP-08).
class WebShellScreen extends StatefulWidget {
  const WebShellScreen({
    super.key,
    required this.config,
    required this.bridgeFactory,
    required this.launcher,
    required this.connectivity,
  });

  final AppConfig config;
  final MashilJsBridge Function(RunJavaScript runJs, bool Function() isTrusted) bridgeFactory;
  final ExternalLauncher launcher;
  final ConnectivityService connectivity;

  @override
  State<WebShellScreen> createState() => _WebShellScreenState();
}

class _WebShellScreenState extends State<WebShellScreen> {
  late final WebViewController _controller;
  late final NavigationPolicy _policy = NavigationPolicy(widget.config.allowedHosts);
  late final MashilJsBridge _bridge;
  StreamSubscription<bool>? _online;

  Uri? _currentUrl;
  int _progress = 0;
  bool _firstLoadDone = false;
  bool _offline = false;
  String? _loadError;
  DateTime? _lastBackAt;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _bridge = widget.bridgeFactory(_controller.runJavaScript, () => _policy.isTrusted(_currentUrl));
    _setUp();
    _online = widget.connectivity.onlineStream.listen((online) {
      if (!mounted) return;
      final wasOffline = _offline;
      setState(() => _offline = !online);
      if (online && (wasOffline || _loadError != null)) _retry();
    });
  }

  Future<void> _setUp() async {
    final ua = await _controller.getUserAgent();
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    // 웹이 앱 안인지 알 수 있게 UA 끝에 붙인다 (브리지 유무로도 판별 가능)
    await _controller.setUserAgent('${ua ?? ''} MashilApp/${_bridge.appInfo.version} (${_bridge.appInfo.platform})'.trim());
    await _controller.addJavaScriptChannel(
      MashilJsBridge.channelName,
      onMessageReceived: (m) => _bridge.onMessage(m.message),
    );
    await _controller.setNavigationDelegate(NavigationDelegate(
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
      onPageStarted: (url) => _currentUrl = Uri.tryParse(url),
      onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      onPageFinished: (url) {
        _currentUrl = Uri.tryParse(url);
        _controller.runJavaScript("window.dispatchEvent(new Event('mashilbridgeready'));");
        if (mounted) setState(() => _firstLoadDone = true);
      },
      onWebResourceError: (e) {
        if (e.isForMainFrame != true || !mounted) return;
        setState(() => _loadError = '${e.errorType?.name ?? 'error'} (${e.errorCode})');
      },
      onHttpError: (e) {
        // 문서 자체가 5xx 면 오류 화면. 4xx 는 웹이 처리하도록 둔다.
        final code = e.response?.statusCode ?? 0;
        if (code >= 500 && e.request?.uri == _currentUrl && mounted) setState(() => _loadError = 'HTTP $code');
      },
    ));
    await _controller.loadRequest(widget.config.webBaseUrl);
  }

  Future<void> _retry() async {
    setState(() => _loadError = null);
    if (_currentUrl != null && _firstLoadDone) {
      await _controller.reload();
    } else {
      await _controller.loadRequest(widget.config.webBaseUrl);
    }
  }

  // Android 뒤로가기: 웹 history → 없으면 "한 번 더 누르면 종료" (APP-05)
  Future<void> _onBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
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
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (!_firstLoadDone && !showError) const Center(child: CircularProgressIndicator()),
              if (_firstLoadDone && _progress < 100 && !showError)
                Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(value: _progress / 100)),
              if (showError) Positioned.fill(child: ErrorScreen(offline: _offline, detail: _loadError, onRetry: _retry)),
            ],
          ),
        ),
      ),
    );
  }
}
