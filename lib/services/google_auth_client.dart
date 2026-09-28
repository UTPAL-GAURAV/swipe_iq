import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class GoogleAuthClient {
  static const _scopes = [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/generative-language',
  ];

  static Future<http.Client> getClient() async {
    final jsonStr = await rootBundle.loadString('assets/service_account.json');
    final credentials = ServiceAccountCredentials.fromJson(jsonDecode(jsonStr));
    return clientViaServiceAccount(credentials, _scopes);
  }
}
