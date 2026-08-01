/// Central application identity.
///
/// The legal owner is a single [const]; the year is computed at runtime via
/// [DateTime.now], so the copyright string is never hardcoded on any surface
/// (Flutter About dialog, macOS About panel, exports).
const String kAppName = 'Glibusta';
const String kAppLegaleseOwner = 'GoSayram Glibusta';

/// `Copyright © <current year> GoSayram Glibusta. All rights reserved.`
String get appLegalese =>
    'Copyright © ${DateTime.now().year} $kAppLegaleseOwner. All rights reserved.';
