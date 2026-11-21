// Electra - estimates what a solar device costs upfront in Kenya.

import 'package:flutter/material.dart';

import 'api.dart';
import 'predict_page.dart';
import 'theme.dart';

void main() => runApp(const ElectraApp());

class ElectraApp extends StatefulWidget {
  const ElectraApp({super.key, this.api});

  /// for tests
  final PredictionApi? api;

  @override
  State<ElectraApp> createState() => _ElectraAppState();
}

class _ElectraAppState extends State<ElectraApp> {
  late final PredictionApi _api = widget.api ?? PredictionApi();

  // follows the phone until the user hits the toggle
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
