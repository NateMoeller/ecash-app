import 'package:ecashapp/lib.dart';
import 'package:ecashapp/widgets/pin_entry.dart';
import 'package:flutter/material.dart';

class PinLockScreen extends StatelessWidget {
  final VoidCallback onUnlocked;

  const PinLockScreen({super.key, required this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    return PinEntry(
      mode: PinEntryMode.verify,
      onPinSubmitted: (pin) async {
        final ok = await verifyPin(pin: pin);
        if (ok) onUnlocked();
        return ok;
      },
    );
  }
}
