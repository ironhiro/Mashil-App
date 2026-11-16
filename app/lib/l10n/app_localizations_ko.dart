// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '마실';

  @override
  String get offlineTitle => '인터넷에 연결되어 있지 않아요';

  @override
  String get loadFailedTitle => '화면을 불러오지 못했어요';

  @override
  String get offlineBody => '연결되면 자동으로 다시 불러옵니다.';

  @override
  String get loadFailedBody => '잠시 후 다시 시도해 주세요.';

  @override
  String get retry => '다시 시도';

  @override
  String get pressBackAgainToExit => '한 번 더 누르면 종료됩니다';

  @override
  String get updateRequiredTitle => '업데이트가 필요해요';

  @override
  String get updateAvailableTitle => '새 버전이 나왔어요';

  @override
  String get updateRequiredBody => '계속 사용하려면 최신 버전으로 업데이트해 주세요.';

  @override
  String get updateAvailableBody => '더 나아진 마실을 만나 보세요.';

  @override
  String get later => '나중에';

  @override
  String get update => '업데이트';

  @override
  String get maintenanceTitle => '문이 잠시 닫혔어요';

  @override
  String get maintenanceBody => '더 나은 마실을 위해 점검하고 있어요.';

  @override
  String get maintenanceUntil => '다시 여는 시각';

  @override
  String get maintenanceRetry => '다시 확인';

  @override
  String get openKakaoMap => '카카오맵에서 화장실 찾기';
}
