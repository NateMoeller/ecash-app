import 'package:ecashapp/lib.dart';
import 'package:ecashapp/screens/pin_lock_screen.dart';
import 'package:ecashapp/theme.dart';
import 'package:flutter/material.dart';

class PinGatedApp extends StatefulWidget {
  final bool pinRequired;
  final Widget child;

  const PinGatedApp({
    super.key,
    required this.pinRequired,
    required this.child,
  });

  @override
  State<PinGatedApp> createState() => _PinGatedAppState();
}

class _PinGatedAppState extends State<PinGatedApp> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _locked = widget.pinRequired;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkLockOnResume();
    }
  }

  Future<void> _checkLockOnResume() async {
    if (_backgroundedAt == null) return;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (elapsed.inSeconds > 30) {
      final pinSet = await hasPinCode();
      if (pinSet && mounted) {
        setState(() => _locked = true);
      }
    }
  }

  void _unlock() {
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: cypherpunkNinjaTheme,
        home: PinLockScreen(onUnlocked: _unlock),
      );
    }
    return widget.child;
  }
}
