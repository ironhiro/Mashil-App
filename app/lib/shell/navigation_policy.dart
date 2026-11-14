/// 웹뷰 안에서 열지, 밖(외부 앱·브라우저)으로 보낼지 (APP-07).
enum NavigationTarget { webView, external, block }

class NavigationPolicy {
  const NavigationPolicy(this.allowedHosts);

  final Set<String> allowedHosts;

  NavigationTarget decide(Uri uri) {
    switch (uri.scheme) {
      case 'http':
      case 'https':
        return allowedHosts.contains(uri.host) ? NavigationTarget.webView : NavigationTarget.external;
      case 'about':
      case 'data':
      case 'blob':
        return NavigationTarget.webView;
      case 'javascript':
      case 'file':
        return NavigationTarget.block;
      default:
        // tel:, mailto:, intent:, kakaomap: … 은 해당 앱으로
        return NavigationTarget.external;
    }
  }

  bool isTrusted(Uri? uri) =>
      uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && allowedHosts.contains(uri.host);
}
