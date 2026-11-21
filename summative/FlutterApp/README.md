# Electra (Flutter app)

One-page mobile app that sends 10 inputs to the Solar Device Price API (`POST /predict`) and shows
the predicted upfront price in KES, or a readable error.

- API: https://linear-regression-model-k2sr.onrender.com/docs
- The API call is in `lib/api.dart`; input checks are in `lib/inputs.dart`; the page is `lib/predict_page.dart`.
- Light and dark mode: follows the phone setting; the sun/moon button in the header switches it.

## Run it

1. Install Flutter (stable) and Android Studio with an Android emulator, then check with `flutter doctor`.
2. Start an emulator (or connect a phone with USB debugging on): `flutter emulators --launch <id>`
3. From this folder:
   ```
   flutter pub get
   flutter run
   ```
4. Fill in the fields and press **Predict**. The first prediction can take up to a minute while the
   free Render server wakes up.

Run the tests with `flutter test`.
