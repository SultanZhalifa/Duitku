import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// A full-screen lock shown when the app-lock setting is enabled. It blocks the
/// app until the user authenticates with biometrics or the device passcode.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    // Prompt automatically as soon as the gate appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await AuthService.instance.authenticate();
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppTheme.heroGradient),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.lock, size: 44, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('Duitku is locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Authenticate to continue',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _authenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: Text(_authenticating ? 'Authenticating…' : 'Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
