import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'src/bindings/app_binding.dart';
import 'src/constants/app_themes.dart';
import 'src/views/home/home_screen.dart';
import 'src/views/preview/preview_screen.dart';
import 'src/views/downloading/downloading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'GLOWLOAD',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.darkTheme,
      initialBinding: AppBinding(),
      initialRoute: '/',
      getPages: [
        GetPage(
          name: '/',
          page: () => const HomeScreen(),
        ),
        GetPage(
          name: '/preview',
          page: () => const PreviewScreen(),
          transition: Transition.rightToLeftWithFade,
          transitionDuration: const Duration(milliseconds: 350),
        ),
        GetPage(
          name: '/downloading',
          page: () => const DownloadingScreen(),
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
