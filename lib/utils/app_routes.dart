import 'package:flutter/material.dart';

import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/home_screen.dart';

class AppRoutes {
  AppRoutes._();

  static Route<void> signup() {
    return MaterialPageRoute<void>(builder: (_) => const SignupScreen());
  }

  static Route<void> homePreview() {
    return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
  }
}
