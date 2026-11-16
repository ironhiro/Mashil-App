import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// 앱 이름 (작업 전환 화면 등)
  ///
  /// In ko, this message translates to:
  /// **'마실'**
  String get appTitle;

  /// No description provided for @offlineTitle.
  ///
  /// In ko, this message translates to:
  /// **'인터넷에 연결되어 있지 않아요'**
  String get offlineTitle;

  /// No description provided for @loadFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'화면을 불러오지 못했어요'**
  String get loadFailedTitle;

  /// No description provided for @offlineBody.
  ///
  /// In ko, this message translates to:
  /// **'연결되면 자동으로 다시 불러옵니다.'**
  String get offlineBody;

  /// No description provided for @loadFailedBody.
  ///
  /// In ko, this message translates to:
  /// **'잠시 후 다시 시도해 주세요.'**
  String get loadFailedBody;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In ko, this message translates to:
  /// **'한 번 더 누르면 종료됩니다'**
  String get pressBackAgainToExit;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트가 필요해요'**
  String get updateRequiredTitle;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 나왔어요'**
  String get updateAvailableTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In ko, this message translates to:
  /// **'계속 사용하려면 최신 버전으로 업데이트해 주세요.'**
  String get updateRequiredBody;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ko, this message translates to:
  /// **'더 나아진 마실을 만나 보세요.'**
  String get updateAvailableBody;

  /// No description provided for @later.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get later;

  /// No description provided for @update.
  ///
  /// In ko, this message translates to:
  /// **'업데이트'**
  String get update;

  /// 네이티브 점검 화면 제목 (웹 maintenance.title 과 같게)
  ///
  /// In ko, this message translates to:
  /// **'문이 잠시 닫혔어요'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In ko, this message translates to:
  /// **'더 나은 마실을 위해 점검하고 있어요.'**
  String get maintenanceBody;

  /// No description provided for @maintenanceUntil.
  ///
  /// In ko, this message translates to:
  /// **'다시 여는 시각'**
  String get maintenanceUntil;

  /// No description provided for @maintenanceRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 확인'**
  String get maintenanceRetry;

  /// No description provided for @openKakaoMap.
  ///
  /// In ko, this message translates to:
  /// **'카카오맵에서 화장실 찾기'**
  String get openKakaoMap;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
