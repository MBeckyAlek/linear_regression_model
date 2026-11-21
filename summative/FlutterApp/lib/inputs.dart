// The 10 inputs and the checks we run before calling the API.
// Typed text is loosely matched to what the API expects, e.g. "installments" -> "Bought, under installment".

class Fields {
  static const deviceType = 'device_type';
  static const acquisition = 'acquisition';
  static const yearsOwned = 'years_owned';
  static const county = 'county';
  static const locality = 'locality';
  static const rooms = 'rooms';
  static const mobilePhones = 'mobile_phones';
  static const ownsDwelling = 'owns_dwelling';
  static const gridConnected = 'grid_connected';
  static const hasBankAccount = 'has_bank_account';

  static const all = [
    deviceType, acquisition, yearsOwned, county, locality,
    rooms, mobilePhones, ownsDwelling, gridConnected, hasBankAccount,
  ];

  static const labels = {
    deviceType: 'Type of device',
    acquisition: 'Payment',
    yearsOwned: 'Years owned',
    county: 'County',
    locality: 'Area',
    rooms: 'Rooms',
    mobilePhones: 'Mobile phones',
    ownsDwelling: 'Do they own their home?',
    gridConnected: 'Connected to the national grid?',
    hasBankAccount: 'Does anyone have a bank account?',
  };

  // used in error messages
  static const shortNames = {
    deviceType: 'Type of device',
    acquisition: 'Payment',
    yearsOwned: 'Years owned',
    county: 'County',
    locality: 'Area',
    rooms: 'Rooms',
    mobilePhones: 'Mobile phones',
    ownsDwelling: 'Home ownership',
    gridConnected: 'Grid connection',
    hasBankAccount: 'Bank account',
  };
}

// display name -> API value
const deviceTypes = {
  'Solar Lantern': 'Solar Lantern',
  'Solar lighting system': 'Solar lighting System',
  'Solar home system': 'Solar home system (Solar PV system)',
};

const counties = [
  'Baringo', 'Bomet', 'Bungoma', 'Busia', 'Elgeyo Marakwet', 'Embu', 'Garissa', 'Homa Bay',
  'Isiolo', 'Kajiado', 'Kakamega', 'Kericho', 'Kiambu', 'Kilifi', 'Kirinyaga', 'Kisii', 'Kisumu',
  'Kitui', 'Kwale', 'Laikipia', 'Lamu', 'Machakos', 'Makueni', 'Mandera', 'Marsabit', 'Meru',
  'Migori', 'Mombasa', 'Muranga', 'Nairobi', 'Nakuru', 'Nandi', 'Narok', 'Nyamira', 'Nyandarua',
  'Nyeri', 'Samburu', 'Siaya', 'Taita Taveta', 'Tana-River', 'Tharaka-Nithi', 'Trans Nzoia',
  'Turkana', 'Uasin Gishu', 'Vihiga', 'Wajir', 'West Pokot',
];

// letters only, so "Tana River" and "tana-river" both match
String _key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

final Map<String, String> _deviceAliases = {
  for (final display in deviceTypes.keys) _key(display): display,
  _key('Solar home system (Solar PV system)'): 'Solar home system',
  'lantern': 'Solar Lantern',
  'lightingsystem': 'Solar lighting system',
  'lighting': 'Solar lighting system',
  'homesystem': 'Solar home system',
  'solarpvsystem': 'Solar home system',
  'pvsystem': 'Solar home system',
};

const _acquisitionAliases = {
  'fullypaid': 'Bought, fully paid',
  'fully': 'Bought, fully paid',
  'paid': 'Bought, fully paid',
  'boughtfullypaid': 'Bought, fully paid',
  'installments': 'Bought, under installment',
  'installment': 'Bought, under installment',
  'instalments': 'Bought, under installment',
  'instalment': 'Bought, under installment',
  'boughtunderinstallment': 'Bought, under installment',
};

final Map<String, String> _countyKeys = {for (final c in counties) _key(c): c};

String? matchDeviceType(String text) => _deviceAliases[_key(text)];

String? matchCounty(String text) => _countyKeys[_key(text)];

String? _matchYesNo(String text) => switch (_key(text)) {
      'yes' || 'y' => 'Yes',
      'no' || 'n' => 'No',
      _ => null,
    };

String? _matchArea(String text) => switch (_key(text)) {
      'rural' => 'Rural',
      'urban' => 'Urban',
      _ => null,
    };

class CheckResult {
  CheckResult(this.body, this.errors, this.missing);

  /// null if anything failed
  final Map<String, Object>? body;
  final Map<String, String> errors;
  final Set<String> missing;

  bool get isValid => body != null;
}

CheckResult checkInputs(Map<String, String> raw) {
  final errors = <String, String>{};
  final missing = <String>{};
  final body = <String, Object>{};

  String text(String f) => (raw[f] ?? '').trim();

  void category(String f, String? Function(String) match, String choices, {String? Function(String)? toApi}) {
    final t = text(f);
    final name = Fields.shortNames[f]!;
    if (t.isEmpty) {
      missing.add(f);
      errors[f] = '$name is missing. Enter $choices.';
      return;
    }
    final matched = match(t);
    if (matched == null) {
      errors[f] = '$name must be $choices.';
      return;
    }
    body[f] = toApi != null ? toApi(matched)! : matched;
  }

  void number(String f, {required bool whole, required num min, required num max,
      required bool minExclusive, required String example}) {
    final t = text(f);
    final name = Fields.shortNames[f]!;
    final kind = whole ? 'a whole number' : 'a number';
    if (t.isEmpty) {
      missing.add(f);
      errors[f] = '$name is missing. Enter $kind, like $example.';
      return;
    }
    final num? value = whole ? int.tryParse(t) : double.tryParse(t);
    if (value == null || (value is double && !value.isFinite)) {
      errors[f] = '$name must be $kind, like $example.';
      return;
    }
    final tooLow = minExclusive ? value <= min : value < min;
    if (tooLow || value > max) {
      errors[f] = minExclusive
          ? '$name must be more than $min and at most $max.'
          : '$name must be between $min and $max.';
      return;
    }
    body[f] = whole ? value.toInt() : value.toDouble();
  }

  category(Fields.deviceType, matchDeviceType, 'Solar Lantern, Solar lighting system or Solar home system',
      toApi: (d) => deviceTypes[d]);
  category(Fields.acquisition, (t) => _acquisitionAliases[_key(t)], 'Fully paid or Installments');
  number(Fields.yearsOwned, whole: false, min: 0, max: 30, minExclusive: true, example: '2');
  category(Fields.county, matchCounty, 'a Kenyan county from the list, like Kisumu');
  category(Fields.locality, _matchArea, 'Rural or Urban');
  number(Fields.rooms, whole: true, min: 1, max: 25, minExclusive: false, example: '3');
  number(Fields.mobilePhones, whole: true, min: 0, max: 10, minExclusive: false, example: '2');
  category(Fields.ownsDwelling, _matchYesNo, 'Yes or No');
  category(Fields.gridConnected, _matchYesNo, 'Yes or No');
  category(Fields.hasBankAccount, _matchYesNo, 'Yes or No');

  final ordered = {for (final f in Fields.all) if (errors.containsKey(f)) f: errors[f]!};
  return CheckResult(ordered.isEmpty ? body : null, ordered, missing);
}

/// "1288.4" -> "1,288"
String formatKes(double value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}
