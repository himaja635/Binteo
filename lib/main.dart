import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConstants.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Binteo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E17EB)),
      ),
      home: const LaundryIntroScreen(), // ✅ always start at splash
    );
  }
}


