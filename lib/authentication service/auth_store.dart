import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/http.dart';


class AuthStore extends ChangeNotifier {
  static const _kToken = 'jwt_token';
  String? _token;


  String? get token => _token;
  bool get hasToken => (_token ?? '').isNotEmpty;


  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString(_kToken);
    HttpClient.setup(this);
    notifyListeners();
  }


  Future<void> setToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
    _token = token;
    HttpClient.setup(this);
    notifyListeners();
  }


  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    _token = null;
    HttpClient.setup(this);
    notifyListeners();
  }
}