import 'package:ecashapp/lib.dart';
import 'package:ecashapp/widgets/pin_entry.dart';
import 'package:flutter/material.dart';

Future<bool> checkSpendingPin(BuildContext context) async {
  final requirePin = await getRequirePinForSpending();
  final hasPin = await hasPinCode();
  if (!requirePin || !hasPin) return true;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder:
        (ctx) => Dialog.fullscreen(
          child: PinEntry(
            mode: PinEntryMode.verify,
            onCancel: () => Navigator.pop(ctx, false),
            onPinSubmitted: (pin) async {
              final ok = await verifyPin(pin: pin);
              if (ok && ctx.mounted) {
                Navigator.pop(ctx, true);
              }
              return ok;
            },
          ),
        ),
  );

  return result ?? false;
}
