// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Mashil';

  @override
  String get offlineTitle => '未连接到网络';

  @override
  String get loadFailedTitle => '页面加载失败';

  @override
  String get offlineBody => '连接后将自动重新加载。';

  @override
  String get loadFailedBody => '请稍后再试。';

  @override
  String get retry => '重试';

  @override
  String get pressBackAgainToExit => '再按一次退出';

  @override
  String get updateRequiredTitle => '需要更新';

  @override
  String get updateAvailableTitle => '有新版本';

  @override
  String get updateRequiredBody => '请更新到最新版本以继续使用 Mashil。';

  @override
  String get updateAvailableBody => '快来体验更好用的 Mashil。';

  @override
  String get later => '以后再说';

  @override
  String get update => '更新';

  @override
  String get maintenanceTitle => '暂时维护中';

  @override
  String get maintenanceBody => '我们正在维护，让 Mashil 变得更好。';

  @override
  String get maintenanceUntil => '预计恢复时间';

  @override
  String get maintenanceRetry => '再次检查';

  @override
  String get openKakaoMap => '在 KakaoMap 中查找卫生间';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Mashil';

  @override
  String get offlineTitle => '未連上網路';

  @override
  String get loadFailedTitle => '無法載入頁面';

  @override
  String get offlineBody => '連上網路後會自動重新載入。';

  @override
  String get loadFailedBody => '請稍後再試。';

  @override
  String get retry => '重試';

  @override
  String get pressBackAgainToExit => '再按一次即可離開';

  @override
  String get updateRequiredTitle => '需要更新';

  @override
  String get updateAvailableTitle => '有新版本';

  @override
  String get updateRequiredBody => '請更新至最新版本以繼續使用 Mashil。';

  @override
  String get updateAvailableBody => '快來體驗更好用的 Mashil。';

  @override
  String get later => '稍後';

  @override
  String get update => '更新';

  @override
  String get maintenanceTitle => '暫時維護中';

  @override
  String get maintenanceBody => '我們正在進行維護，讓 Mashil 變得更好。';

  @override
  String get maintenanceUntil => '預計恢復時間';

  @override
  String get maintenanceRetry => '再次確認';

  @override
  String get openKakaoMap => '在 KakaoMap 尋找廁所';
}
