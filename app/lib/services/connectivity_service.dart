import 'package:connectivity_plus/connectivity_plus.dart';

/// 네트워크 연결 여부 (APP-06). 연결 "종류"만 보므로 실제 인터넷 도달은 웹뷰 로드 결과로 판단한다.
class ConnectivityService {
  final _c = Connectivity();

  static bool _online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  Future<bool> isOnline() async => _online(await _c.checkConnectivity());

  Stream<bool> get onlineStream => _c.onConnectivityChanged.map(_online).distinct();
}
