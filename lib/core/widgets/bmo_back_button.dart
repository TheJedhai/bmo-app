import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back button that always renders — suitable as [AppBar.leading] on every
/// feature screen.
///
/// When there is history on the shell navigator, it calls [GoRouter.pop].
/// When opened directly (no history, e.g. /chat typed in the address bar), it
/// navigates to `/` so the user always has a way back to the dashboard.
class BmoBackButton extends StatelessWidget {
  const BmoBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
    );
  }
}
