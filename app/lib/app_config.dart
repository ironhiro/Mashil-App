/// 빌드 시 `--dart-define-from-file=env/<환경>.json` 으로 주입하는 설정.
/// 키 값은 저장소에 넣지 않는다 (`env/*.json` 은 gitignore, `env/example.json` 참고).
class AppConfig {
  const AppConfig({
    required this.webBaseUrl,
    required this.apiBaseUrl,
    required this.allowedHosts,
    this.kakaoNativeAppKey,
    this.googleServerClientId,
    this.googleIosClientId,
    this.adsEnabled = false,
    this.admobBannerId,
  });

  /// 웹뷰가 처음 여는 주소. 개발: 에뮬레이터에서 PC 는 10.0.2.2.
  final Uri webBaseUrl;

  /// 버전 확인 등 앱이 직접 부르는 API.
  final Uri apiBaseUrl;

  /// 웹뷰 안에서 열어도 되는 호스트. 나머지는 외부 브라우저로 연다 (APP-07).
  final Set<String> allowedHosts;

  final String? kakaoNativeAppKey;
  final String? googleServerClientId;
  final String? googleIosClientId;

  /// 하단 배너 광고를 켤지 (ADS_ENABLED=true)
  final bool adsEnabled;

  /// 배너 광고 단위 ID (ADMOB_BANNER_ID). 비우면 Google 의 테스트 광고 단위 — 실제 ID 는 프로덕션 env 에만 넣는다
  final String? admobBannerId;

  /// Google 이 공개한 적응형 배너 테스트 단위 (누르거나 노출돼도 수익·무효 트래픽과 무관)
  static const testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const testBannerIos = 'ca-app-pub-3940256099942544/2435281174';

  String bannerUnitIdFor(String platform) =>
      admobBannerId ?? (platform == 'ios' ? testBannerIos : testBannerAndroid);

  static const _web = String.fromEnvironment('WEB_BASE_URL', defaultValue: 'http://10.0.2.2:5099/dev/bridge');
  static const _api = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5099');
  static const _extraHosts = String.fromEnvironment('ALLOWED_HOSTS');
  static const _kakao = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  static const _googleServer = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _googleIos = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const _ads = String.fromEnvironment('ADS_ENABLED');
  static const _admobBanner = String.fromEnvironment('ADMOB_BANNER_ID');

  factory AppConfig.fromEnvironment() {
    final web = Uri.parse(_web);
    final api = Uri.parse(_api);
    return AppConfig(
      webBaseUrl: web,
      apiBaseUrl: api,
      allowedHosts: {
        web.host,
        api.host,
        ..._extraHosts.split(',').map((h) => h.trim()).where((h) => h.isNotEmpty),
      },
      kakaoNativeAppKey: _blankToNull(_kakao),
      googleServerClientId: _blankToNull(_googleServer),
      googleIosClientId: _blankToNull(_googleIos),
      adsEnabled: _ads.trim().toLowerCase() == 'true',
      admobBannerId: _blankToNull(_admobBanner),
    );
  }

  static String? _blankToNull(String v) => v.trim().isEmpty ? null : v.trim();
}
