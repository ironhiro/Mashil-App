import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 하단 배너 광고 (AdMob, docs/01 MON-01).
///
/// - 배너를 보일 화면은 웹이 정한다: 목록·검색 결과와 화장실 상세에서 브리지 `setAdBanner { visible }` 로 켜고 끈다
///   ([wanted]). 셸은 그 아래에 배너를 붙이고, 웹에는 하단 여백만 알린다
/// - **비맞춤 광고**만 요청한다 ([request]). 광고 ID 기반 맞춤 광고를 쓰지 않으므로 행태정보 동의 화면(UMP)이 없다.
///   맞춤 광고로 바꾸면 UMP 동의, 처리방침, Play 데이터 보안을 함께 고친다
/// - 시작 연출이 끝난 뒤에 [start] 한다 (첫 화면을 늦추지 않도록)
abstract class AdService {
  /// SDK 가 준비됨
  ValueListenable<bool> get ready;

  /// 웹이 지금 화면에 배너를 원하는지. 문서를 새로 불러오면 false 로 돌아간다 (새 페이지가 다시 켠다)
  ValueNotifier<bool> get wanted;

  /// 배너 광고 단위 ID
  String get bannerUnitId;

  Future<void> start();

  /// 비맞춤 광고 요청 (AdMob npa=1)
  static const request = AdRequest(nonPersonalizedAds: true);
}

class AdMobService implements AdService {
  AdMobService(this.bannerUnitId);

  @override
  final String bannerUnitId;

  final _ready = ValueNotifier(false);
  bool _started = false;

  @override
  final wanted = ValueNotifier(false);

  @override
  ValueListenable<bool> get ready => _ready;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      await MobileAds.instance.initialize();
      _ready.value = true;
    } catch (e) {
      debugPrint('ads: start failed ($e)');
    }
  }
}
