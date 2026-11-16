import 'package:url_launcher/url_launcher.dart';

/// 길찾기 이동 수단. 차는 카카오맵이 실시간 교통·음성 안내로 맡는다 (앱 안 경로는 도보만).
enum DirectionsMode { walk, car }

/// 길찾기·전화·외부 링크 (APP-04, APP-07).
class ExternalLauncher {
  /// 카카오맵 앱이 있으면 그 수단의 길찾기, 없으면 카카오맵 웹 길찾기. 반환: 연 대상 ("kakaomap" / "web").
  Future<String?> openDirections(double lat, double lng, String name, {DirectionsMode mode = DirectionsMode.walk}) async {
    final by = mode == DirectionsMode.car ? 'CAR' : 'FOOT';
    final app = Uri.parse('kakaomap://route?ep=$lat,$lng&by=$by');
    try {
      if (await launchUrl(app, mode: LaunchMode.externalNonBrowserApplication)) return 'kakaomap';
    } catch (_) {
      // 앱이 없으면 예외 또는 false
    }
    final web = Uri.parse('https://map.kakao.com/link/to/${Uri.encodeComponent(name)},$lat,$lng');
    return await launchUrl(web, mode: LaunchMode.externalApplication) ? 'web' : null;
  }

  /// 점검 중 대안: 카카오맵에서 "화장실" 검색. 앱이 있으면 앱, 없으면 카카오맵 웹
  Future<bool> openKakaoMapSearch(String query) async {
    final q = Uri.encodeComponent(query);
    try {
      if (await launchUrl(Uri.parse('kakaomap://search?q=$q'), mode: LaunchMode.externalNonBrowserApplication)) return true;
    } catch (_) {
      // 앱이 없으면 예외 또는 false
    }
    return openExternal(Uri.parse('https://map.kakao.com/?q=$q'));
  }

  Future<bool> openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
