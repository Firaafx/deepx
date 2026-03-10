// lib/main.dart
import 'package:flutter/material.dart';
import 'tracker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeepX',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Tracker(),
      ),
    );
  }
}
