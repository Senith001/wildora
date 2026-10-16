import 'package:flutter/foundation.dart';

/// Lightweight cross-screen channel for requesting an app-shell tab switch.
///
/// Any screen can call [AppShellTabController.go] to ask the
/// [MainNavigationScreen] shell to select a given tab index without taking a
/// direct dependency on the shell's internals. The shell listens to
/// [selectedTab] and mirrors its own selected index back into it so the two
/// stay in sync.
class AppShellTabController {
  AppShellTabController._();

  /// The currently requested / active shell tab index.
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);

  /// Request the shell to switch to [index].
  static void go(int index) {
    selectedTab.value = index;
  }
}
