import 'dart:convert';

import 'package:electra/api.dart';
import 'package:electra/inputs.dart';
import 'package:electra/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _good = {
  'device_type': 'Solar Lantern',
  'acquisition': 'Fully paid',
  'years_owned': '2',
  'county': 'Kisumu',
  'locality': 'Rural',
  'rooms': '3',
  'mobile_phones': '2',
  'owns_dwelling': 'Yes',
  'grid_connected': 'No',
  'has_bank_account': 'No',
};

void main() {
  group('checkInputs', () {
    test('valid inputs become the exact API body', () {
      final r = checkInputs(_good);
      expect(r.isValid, isTrue);
      expect(r.body, {
        'device_type': 'Solar Lantern',
        'acquisition': 'Bought, fully paid',
        'years_owned': 2.0,
        'county': 'Kisumu',
        'locality': 'Rural',
        'rooms': 3,
        'mobile_phones': 2,
        'owns_dwelling': 'Yes',
        'grid_connected': 'No',
        'has_bank_account': 'No',
      });
    });

    test('typed text is matched loosely', () {
      final r = checkInputs({
        ..._good,
        'device_type': 'home system',
        'acquisition': 'installments',
        'county': 'tana river',
        'locality': 'URBAN',
        'owns_dwelling': 'y',
      });
      expect(r.body!['device_type'], 'Solar home system (Solar PV system)');
      expect(r.body!['acquisition'], 'Bought, under installment');
      expect(r.body!['county'], 'Tana-River');
      expect(r.body!['locality'], 'Urban');
      expect(r.body!['owns_dwelling'], 'Yes');
    });

    test('missing, wrong type and out of range give the design messages', () {
      final r = checkInputs({..._good, 'years_owned': '', 'rooms': 'three', 'mobile_phones': '50'});
      expect(r.isValid, isFalse);
      expect(r.errors.values, [
        'Years owned is missing. Enter a number, like 2.',
        'Rooms must be a whole number, like 3.',
        'Mobile phones must be between 0 and 10.',
      ]);
      expect(r.missing, {'years_owned'});
    });

    test('ranges match the API', () {
      expect(checkInputs({..._good, 'years_owned': '0'}).isValid, isFalse);
      expect(checkInputs({..._good, 'years_owned': '30'}).isValid, isTrue);
      expect(checkInputs({..._good, 'years_owned': '30.5'}).isValid, isFalse);
      expect(checkInputs({..._good, 'rooms': '0'}).isValid, isFalse);
      expect(checkInputs({..._good, 'rooms': '25'}).isValid, isTrue);
      expect(checkInputs({..._good, 'rooms': '2.5'}).isValid, isFalse);
      expect(checkInputs({..._good, 'mobile_phones': '0'}).isValid, isTrue);
      expect(checkInputs({..._good, 'county': 'Atlantis'}).errors['county'],
          'County must be a Kenyan county from the list, like Kisumu.');
      expect(checkInputs({..._good, 'grid_connected': 'maybe'}).errors['grid_connected'],
          'Grid connection must be Yes or No.');
    });

    test('formatKes', () {
      expect(formatKes(1288.4), '1,288');
      expect(formatKes(160000), '160,000');
      expect(formatKes(950), '950');
    });
  });

  group('PredictionApi', () {
    test('posts JSON to /predict and reads the price', () async {
      late http.Request sent;
      final api = PredictionApi(client: MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode({'predicted_price_kes': 1287.6, 'model': 'SGDRegressor'}), 200);
      }));
      expect(await api.predict(checkInputs(_good).body!), 1287.6);
      expect(sent.url.toString(), '$apiBaseUrl/predict');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body)['acquisition'], 'Bought, fully paid');
    });

    test('a 422 from the API becomes readable sentences', () async {
      final api = PredictionApi(client: MockClient((_) async => http.Response(
          jsonEncode({
            'detail': [
              {'type': 'less_than_equal', 'loc': ['body', 'rooms'], 'msg': 'Input should be less than or equal to 25'}
            ]
          }),
          422)));
      expect(
          () => api.predict(checkInputs(_good).body!),
          throwsA(isA<PredictionException>()
              .having((e) => e.title, 'title', "Can't predict yet: 1 field needs fixing")
              .having((e) => e.messages, 'messages', ['Rooms: Input should be less than or equal to 25.'])));
    });

    test('a server error gives a readable message', () async {
      final api = PredictionApi(client: MockClient((_) async => http.Response('oops', 500)));
      expect(() => api.predict(checkInputs(_good).body!),
          throwsA(isA<PredictionException>().having((e) => e.messages.single, 'msg', contains('error 500'))));
    });
  });

  group('page', () {
    Future<void> pumpApp(WidgetTester tester, MockClient client) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ElectraApp(api: PredictionApi(client: client)));
    }

    Finder field(String name) => find.byKey(ValueKey(name));

    testWidgets('has 10 text fields and a Predict button', (tester) async {
      await pumpApp(tester, MockClient((_) async => http.Response('{}', 200)));
      expect(find.byType(TextField), findsNWidgets(10));
      expect(find.widgetWithText(FilledButton, 'Predict'), findsOneWidget);
      expect(find.text('KES —'), findsOneWidget);
    });

    testWidgets('shows the predicted price', (tester) async {
      await pumpApp(
          tester,
          MockClient((_) async =>
              http.Response(jsonEncode({'predicted_price_kes': 1288.0, 'model': 'SGDRegressor'}), 200)));
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Predict'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Predict'));
      await tester.pumpAndSettle();
      expect(find.text('KES 1,288'), findsOneWidget);
      expect(find.text('Solar Lantern · Kisumu · rural'), findsOneWidget);
    });

    testWidgets('shows the errors from the design without calling the API', (tester) async {
      var calls = 0;
      await pumpApp(tester, MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }));
      await tester.enterText(field('years_owned'), '');
      await tester.enterText(field('rooms'), 'three');
      await tester.enterText(field('mobile_phones'), '50');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Predict'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Predict'));
      await tester.pumpAndSettle();
      expect(find.text("Can't predict yet: 3 fields need fixing"), findsOneWidget);
      expect(find.text('Years owned is missing. Enter a number, like 2.'), findsOneWidget);
      expect(find.text('Rooms must be a whole number, like 3.'), findsOneWidget);
      expect(find.text('Mobile phones must be between 0 and 10.'), findsOneWidget);
      expect(find.text('Required, up to 30'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('theme toggle switches between light and dark', (tester) async {
      await pumpApp(tester, MockClient((_) async => http.Response('{}', 200)));
      final before = Theme.of(tester.element(find.text('Electra'))).brightness;
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      final after = Theme.of(tester.element(find.text('Electra'))).brightness;
      expect(after, isNot(before));
    });
  });
}
