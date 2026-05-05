import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/pengepul_dashboard/screens/main_shell.dart';
import '../../features/manajer_dashboard/screens/manajer_shell.dart';
import '../../services/hive_service.dart';

class AppRouter {
  static Widget getGatekeeper() {
    final currentUser = HiveService().usersBox.get('currentUser');

    if (currentUser == null) return const LoginScreen();

    if (currentUser.role == 'pengepul') {
      return const MainShell();
    } else if (currentUser.role == 'manajer') {
      return const ManajerShell();
    }

    return const LoginScreen();
  }
}