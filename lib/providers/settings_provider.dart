import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds lightweight app preferences: whether onboarding has been completed,
/// whether the biometric app lock is enabled, and whether recurring reminders
/// are on. Each is a real, persisted flag the corresponding feature reads.
class SettingsProvider extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  SettingsProvider({SharedPreferences? prefs}) : _prefs = prefs;

  static const _onboardedKey = 'onboarded';
  static const _appLockKey = 'app_lock_enabled';
  static const _remindersKey = 'reminders_enabled';

  SharedPreferences? _prefs;

  bool _onboarded = false;
  bool _appLockEnabled = false;
  bool _remindersEnabled = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get onboarded => _onboarded;
  bool get appLockEnabled => _appLockEnabled;
  bool get remindersEnabled => _remindersEnabled;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _onboarded = _prefs!.getBool(_onboardedKey) ?? false;
    _appLockEnabled = _prefs!.getBool(_appLockKey) ?? false;
    _remindersEnabled = _prefs!.getBool(_remindersKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_onboardedKey, true);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_appLockKey, value);
    notifyListeners();
  }

  Future<void> setRemindersEnabled(bool value) async {
    _remindersEnabled = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_remindersKey, value);
    notifyListeners();
  }
}
