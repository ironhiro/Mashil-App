// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mashil';

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get loadFailedTitle => 'Couldn\'t load the page';

  @override
  String get offlineBody =>
      'We\'ll reload automatically when you\'re back online.';

  @override
  String get loadFailedBody => 'Please try again in a moment.';

  @override
  String get retry => 'Try again';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String get updateRequiredBody =>
      'Please update to the latest version to keep using Mashil.';

  @override
  String get updateAvailableBody => 'Get the latest improvements to Mashil.';

  @override
  String get later => 'Later';

  @override
  String get update => 'Update';
}
