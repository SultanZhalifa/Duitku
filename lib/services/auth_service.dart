import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` for an optional app lock using device biometrics or the
/// device passcode.
///
/// Biometric authentication is a native capability. On web (and any platform
/// without an enrolled authenticator) [canCheck] is false and [authenticate]
/// returns false, so the UI keeps the lock toggle disabled rather than pretend
/// it works. Real platform/hardware detection, not a stub.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether this device can perform biometric / device-credential checks.
  Future<bool> canCheck() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return supported || canCheckBiometrics;
    } on Exception {
      return false;
    }
  }

  /// Prompts the user to authenticate. Returns true only on success.
  Future<bool> authenticate({
    String reason = 'Unlock Duitku',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // Allow falling back to the device PIN/passcode.
          biometricOnly: false,
        ),
      );
    } on Exception {
      return false;
    }
  }
}
