// Electra: estimates the upfront price of a solar device in Kenya by calling the deployed
// Solar Device Price API (see api.dart).

import 'package:flutter/material.dart';

import 'api.dart';
import 'predict_page.dart';
import 'theme.dart';

void main() => runApp(const ElectraApp());

class ElectraApp extends StatefulWidget {
  const ElectraApp({super.key, this.api});

  /// Lets tests pass in a fake API; the app uses the real one.
  final PredictionApi? api;

  @override
  State<ElectraApp> createState() => _ElectraAppState();
}

class _ElectraAppState extends State<ElectraApp> {
  late final PredictionApi _api = widget.api ?? PredictionApi();

  // Follows the phone's light/dark setting until the user taps the toggle in the header.
  ThemeMode _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electra',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _mode,
      home: Builder(builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PredictPage(
          api: _api,
          isDark: isDark,
          onToggleTheme: () => setState(() => _mode = isDark ? ThemeMode.light : ThemeMode.dark),
        );
      }),
    );
  }
}
