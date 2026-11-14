import 'package:url_launcher/url_launcher.dart';

/// 길찾기·전화·외부 링크 (APP-04, APP-07).
class ExternalLauncher {
  /// 카카오맵 앱이 있으면 도보 길찾기, 없으면 카카오맵 웹 길찾기. 반환: 연 대상 ("kakaomap" / "web").
  Future<String?> openDirections(double lat, double lng, String name) async {
    final app = Uri.parse('kakaomap://route?ep=$lat,$lng&by=FOOT');
    try {
      if (await launchUrl(app, mode: LaunchMode.externalNonBrowserApplication)) return 'kakaomap';
    } catch (_) {
      // 앱이 없으면 예외 또는 false
    }
    final web = Uri.parse('https://map.kakao.com/link/to/${Uri.encodeComponent(name)},$lat,$lng');
    return await launchUrl(web, mode: LaunchMode.externalApplication) ? 'web' : null;
  }

  Future<bool> openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
