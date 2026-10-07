import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

/// The root application widget for Wildora
class WildoraApp extends StatelessWidget {
  const WildoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wildora',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeScreen(),
    );
  }
}
