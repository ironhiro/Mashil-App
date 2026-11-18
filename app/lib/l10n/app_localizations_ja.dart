// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Mashil';

  @override
  String get offlineTitle => 'インターネットに接続されていません';

  @override
  String get loadFailedTitle => '画面を読み込めませんでした';

  @override
  String get offlineBody => '接続されると自動的に再読み込みします。';

  @override
  String get loadFailedBody => 'しばらくしてからもう一度お試しください。';

  @override
  String get retry => '再試行';

  @override
  String get pressBackAgainToExit => 'もう一度押すと終了します';

  @override
  String get updateRequiredTitle => 'アップデートが必要です';

  @override
  String get updateAvailableTitle => '新しいバージョンがあります';

  @override
  String get updateRequiredBody => '引き続きご利用いただくには、最新バージョンにアップデートしてください。';

  @override
  String get updateAvailableBody => 'より使いやすくなったMashilをお試しください。';

  @override
  String get later => 'あとで';

  @override
  String get update => 'アップデート';

  @override
  String get maintenanceTitle => 'ただいまメンテナンス中です';

  @override
  String get maintenanceBody => 'Mashilをより良くするためにメンテナンスしています。';

  @override
  String get maintenanceUntil => '再開予定';

  @override
  String get maintenanceRetry => 'もう一度確認';

  @override
  String get openKakaoMap => 'KakaoMapでトイレを探す';
}
