import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/firebase_auth_provider.dart';
import '../home/home_landing_page.dart';
import 'login_page.dart';
import 'no_access_page.dart';

/// Routes the top of the app based on the Firebase auth session state.
/// Phase 1 endpoint: proves Google sign-in + member resolution end to end.
/// The signed-in destination is a temporary landing that Phase 1b/2 replace
/// with the real admin dashboard and shop entry screens.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    switch (session.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginPage();
      case AuthStatus.noAccess:
        return const NoAccessPage();
      case AuthStatus.signedIn:
        return const HomeLandingPage();
    }
  }
}
