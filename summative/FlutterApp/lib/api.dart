// Calls the deployed FastAPI service.
//
// POST {apiBaseUrl}/predict with the 10 inputs as JSON, and read back "predicted_price_kes".
// Any failure becomes a PredictionException with sentences the page can show as they are.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'inputs.dart';

/// The public Render URL of the API (Swagger UI: $apiBaseUrl/docs).
const apiBaseUrl = 'https://linear-regression-model-k2sr.onrender.com';

/// A free Render service can take up to a minute to wake up, so allow for that.
const requestTimeout = Duration(seconds: 90);

class PredictionException implements Exception {
  PredictionException(this.title, this.messages);
  final String title;
  final List<String> messages;

  @override
  String toString() => '$title: ${messages.join(' ')}';
}

class PredictionApi {
  PredictionApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Sends one device to /predict and returns the predicted upfront price in KES.
  Future<double> predict(Map<String, Object> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$apiBaseUrl/predict'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw PredictionException("Couldn't get a prediction", [
        'The server took too long to answer. The free server may be waking up: wait a moment and press Predict again.',
      ]);
    } on SocketException {
      throw PredictionException("Couldn't get a prediction", [
        "Couldn't reach the server. Check the phone's internet connection and try again.",
      ]);
    } on http.ClientException {
      throw PredictionException("Couldn't get a prediction", [
        "Couldn't reach the server. Check the phone's internet connection and try again.",
      ]);
    }

    if (response.statusCode == 200) {
      final price = (jsonDecode(response.body) as Map<String, dynamic>)['predicted_price_kes'];
      if (price is num) return price.toDouble();
      throw PredictionException("Couldn't get a prediction", ['The server sent an answer the app could not read.']);
    }

    if (response.statusCode == 422) {
      final messages = validationMessages(response.body);
      throw PredictionException(
          "Can't predict yet: ${_count(messages.length)} fixing", messages);
    }

    throw PredictionException("Couldn't get a prediction", [
      'The server had a problem (error ${response.statusCode}). Please try again in a moment.',
    ]);
  }
}

String _count(int n) => n == 1 ? '1 field needs' : '$n fields need';

/// Turns FastAPI's 422 body ({"detail": [{"loc": ["body", "rooms"], "msg": "..."}]}) into sentences.
List<String> validationMessages(String responseBody) {
  try {
    final detail = (jsonDecode(responseBody) as Map<String, dynamic>)['detail'];
    if (detail is List && detail.isNotEmpty) {
      return [
        for (final item in detail.cast<Map<String, dynamic>>())
          '${Fields.shortNames[(item['loc'] as List).last] ?? (item['loc'] as List).last}: '
              '${item['msg']}.'
      ];
    }
  } catch (_) {
    // fall through to the generic message
  }
  return ['The server rejected one of the values. Check the fields and try again.'];
}
