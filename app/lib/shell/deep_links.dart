import 'dart:async';

import 'package:flutter/widgets.dart';

/// 공유 링크(Android App Links, iOS Universal Links)로 앱이 열렸을 때 웹뷰가 열 주소.
///
/// Flutter 기본 딥링크를 쓴다: 앱이 켜질 때의 링크는 `PlatformDispatcher.defaultRouteName`,
/// 켜져 있을 때 온 링크는 [didPushRouteInformation] 으로 온다. 화면은 웹이 그리므로 앱의 Navigator 로는
/// 보내지 않는다 — 이 관찰자를 runApp 전에 붙여 MaterialApp 보다 먼저 받고 true 로 끝낸다.
///
/// 웹 주소([webBase])와 같은 호스트의 링크만 받는다. 다른 호스트나 `/` 만 온 링크는 무시하고 홈을 연다.
class DeepLinks with WidgetsBindingObserver {
  DeepLinks(this.webBase, {String? initialRoute}) {
    if (initialRoute != null && initialRoute != '/') {
      _pending = resolve(webBase, Uri.tryParse(initialRoute));
    }
  }

  final Uri webBase;
  final _links = StreamController<Uri>.broadcast();
  Uri? _pending;

  /// 웹뷰가 뜬 뒤 들어온 링크.
  Stream<Uri> get links => _links.stream;

  /// 웹뷰가 아직 없을 때 들어온 링크 (첫 화면으로 연다). 한 번 꺼내면 비운다.
  Uri? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final target = resolve(webBase, routeInformation.uri);
    if (target != null) {
      _pending = target;
      _links.add(target);
    }
    return true;
  }

  /// 링크 → 웹뷰가 열 주소. 경로만 오면(`/toilets/12`) 웹 주소에 붙이고, 전체 주소면 호스트가 같아야 한다.
  static Uri? resolve(Uri webBase, Uri? link) {
    if (link == null) return null;
    if (link.hasScheme && link.scheme != 'https' && link.scheme != 'http') return null;
    // "//다른호스트/x" 처럼 스킴 없이 호스트만 붙은 것도 막는다
    if ((link.hasScheme || link.hasAuthority) && link.host.toLowerCase() != webBase.host.toLowerCase()) return null;
    final path = link.path;
    if (!path.startsWith('/') || path.startsWith('//')) return null;
    if (path == '/' && link.query.isEmpty) return null;
    return webBase.replace(
      path: path,
      query: link.query.isEmpty ? null : link.query,
      fragment: link.fragment.isEmpty ? null : link.fragment,
    );
  }

  void dispose() => _links.close();
}
