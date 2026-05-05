import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/pengepul_dashboard/screens/main_shell.dart';
import '../../services/hive_service.dart';

class AppRouter {
  static Widget getGatekeeper() {
    final currentUser = HiveService().usersBox.get('currentUser');

    if (currentUser == null) return const LoginScreen();

    if (currentUser.role == 'pengepul') {
      return const MainShell(); // ✅ Dashboard pengepul
    } else if (currentUser.role == 'manajer') {
      return _ManajerPlaceholder(username: currentUser.username);
    }

    return const LoginScreen();
  }
}

/// Placeholder manajer — sprint berikutnya
class _ManajerPlaceholder extends StatelessWidget {
  final String username;
  const _ManajerPlaceholder({required this.username});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Dasbor Manajer'),
          backgroundColor: Colors.amber,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthController().logout();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AppRouter.getGatekeeper()),
                  );
                }
              },
            ),
          ],
        ),
        body: Center(
          child: Text(
            'Login sebagai $username (Manajer).\nDashboard manajer coming soon!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      );
}