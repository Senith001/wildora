import 'package:flutter/material.dart';

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
      home: const Scaffold(body: Center(child: Text('Wildora'))),
    );
  }
}
