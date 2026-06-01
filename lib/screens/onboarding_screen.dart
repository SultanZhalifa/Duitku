import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A single onboarding page definition.
class _Page {
  const _Page(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

/// A short, animated first-run walkthrough. Shown once; on completion the
/// caller persists the onboarded flag so it never appears again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _Page(Icons.account_balance_wallet, 'Welcome to Duitku',
        'Track income and expenses across multiple wallets — all offline, all on your device.'),
    _Page(Icons.insights, 'Understand your money',
        'See spending by category, monthly trends, and smart insights drawn only from your real data.'),
    _Page(Icons.savings, 'Stay on budget',
        'Set per-category budgets, automate recurring transactions, and get reminders.'),
    _Page(Icons.lock, 'Yours and private',
        'Lock the app with biometrics and back up everything to a file whenever you like.'),
  ];

  bool get _isLast => _index == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(_isLast ? '' : 'Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardingPage(page: _pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppTheme.seed
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: _next,
                child: Text(_isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppTheme.heroGradient),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(page.icon, size: 56, color: Colors.white),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
