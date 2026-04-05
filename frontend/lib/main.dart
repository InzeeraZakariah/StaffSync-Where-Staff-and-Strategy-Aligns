import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/main_nav_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Initialize notifications
  await NotificationService().initialize();
  await NotificationService().requestPermission();

  // Check login state
  final isLoggedIn = await AuthService().isLoggedIn();

  runApp(StaffSyncApp(isLoggedIn: isLoggedIn));
}

class StaffSyncApp extends StatelessWidget {
  final bool isLoggedIn;
  const StaffSyncApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Staff Sync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: child,
        );
      },
      child: isLoggedIn ? const MainNavScreen() : const LoginScreen(),
    );
  }
}