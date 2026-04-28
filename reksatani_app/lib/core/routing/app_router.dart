import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../services/hive_service.dart';

class AppRouter {
  static Widget getGatekeeper() {
    final usersBox = HiveService().usersBox;
    final currentUser = usersBox.get('currentUser');

    if (currentUser == null) {
      return const LoginScreen();
    }

    // --- LOGIKA RBAC FINAL ---
    if (currentUser.role == 'pengepul') {
      return _buildPlaceholder(role: 'Pengepul', color: Colors.green, contextName: currentUser.username);
    } else if (currentUser.role == 'manajer') {
      return _buildPlaceholder(role: 'Manajer Gudang', color: Colors.amber, contextName: currentUser.username);
    }

    return const LoginScreen();
  }

  // --- UI SEMENTARA UNTUK TEST LOGOUT (WIP) ---
  static Widget _buildPlaceholder({required String role, required Color color, required String contextName}) {
    return Builder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text('WIP: Dasbor $role'),
            backgroundColor: color,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Test Logout',
                onPressed: () async {
                  // Panggil fungsi logout dari controller buatanmu
                  await AuthController().logout();
                  
                  // Refresh Gatekeeper
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AppRouter.getGatekeeper()),
                    );
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: Text(
              'Login sukses sebagai $contextName ($role).\n\nSilakan teman UI melanjutkan slicing di sini!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      }
    );
  }
}