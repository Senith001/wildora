import 'package:flutter/material.dart';

import 'src/app/app.dart';
import 'src/app/mobile_preview.dart';
import 'src/core/firebase/firebase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitializer.ensureInitialized();
  runApp(const MobilePreview(child: WildoraApp()));
}
