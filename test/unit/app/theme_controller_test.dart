import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wildora/src/app/theme/theme_controller.dart';

import '../../fakes/in_memory_repositories.dart';

void main() {
  group('ThemeController', () {
    late InMemoryUserPreferencesRepository fakeRepository;
    late ThemeController controller;

    setUp(() {
      fakeRepository = InMemoryUserPreferencesRepository();
      controller = ThemeController(fakeRepository);
    });

    tearDown(() {
      controller.dispose();
      fakeRepository.dispose();
    });

    test('initializes with system theme mode by default', () {
      expect(controller.themeMode, equals(ThemeMode.system));
    });

    test('loads saved light theme from repository', () async {
      // Arrange: seed repository with light theme preference
      await fakeRepository.setThemeMode('demo-user', 'light');

      // Act: load saved theme
      await controller.loadSavedTheme();

      // Assert: controller has light theme
      expect(controller.themeMode, equals(ThemeMode.light));
    });

    test('loads saved dark theme from repository', () async {
      // Arrange: seed repository with dark theme preference
      await fakeRepository.setThemeMode('demo-user', 'dark');

      // Act: load saved theme
      await controller.loadSavedTheme();

      // Assert: controller has dark theme
      expect(controller.themeMode, equals(ThemeMode.dark));
    });

    test('defaults to system theme when no saved preference exists', () async {
      // Act: load theme when repository is empty
      await controller.loadSavedTheme();

      // Assert: defaults to system theme
      expect(controller.themeMode, equals(ThemeMode.system));
    });

    test('defaults to system theme when repository throws error', () async {
      // Arrange: force repository to throw error
      fakeRepository.forceError = true;

      // Act: attempt to load theme
      await controller.loadSavedTheme();

      // Assert: gracefully defaults to system theme
      expect(controller.themeMode, equals(ThemeMode.system));
    });

    test('setThemeMode updates theme and persists to repository', () async {
      // Act: set theme to dark
      await controller.setThemeMode(ThemeMode.dark);

      // Assert: controller theme updated
      expect(controller.themeMode, equals(ThemeMode.dark));

      // Assert: repository was updated
      final saved = await fakeRepository.getThemeMode('demo-user');
      expect(saved, equals('dark'));
    });

    test('setThemeMode notifies listeners', () async {
      // Arrange: listen for notifications
      var notified = false;
      controller.addListener(() {
        notified = true;
      });

      // Act: set theme mode
      await controller.setThemeMode(ThemeMode.light);

      // Assert: listener was notified
      expect(notified, isTrue);
    });

    test('setThemeMode handles repository errors gracefully', () async {
      // Arrange: force repository to throw on write
      fakeRepository.forceError = true;

      // Act: attempt to set theme (should not throw)
      await controller.setThemeMode(ThemeMode.dark);

      // Assert: theme is still updated in memory despite persistence failure
      expect(controller.themeMode, equals(ThemeMode.dark));
    });

    test('supports all theme modes', () async {
      // Test system mode
      await controller.setThemeMode(ThemeMode.system);
      expect(controller.themeMode, equals(ThemeMode.system));

      // Test light mode
      await controller.setThemeMode(ThemeMode.light);
      expect(controller.themeMode, equals(ThemeMode.light));

      // Test dark mode
      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, equals(ThemeMode.dark));
    });

    test('persists theme mode with correct string values', () async {
      // Test light mode persistence
      await controller.setThemeMode(ThemeMode.light);
      var saved = await fakeRepository.getThemeMode('demo-user');
      expect(saved, equals('light'));

      // Test dark mode persistence
      await controller.setThemeMode(ThemeMode.dark);
      saved = await fakeRepository.getThemeMode('demo-user');
      expect(saved, equals('dark'));

      // Test system mode persistence
      await controller.setThemeMode(ThemeMode.system);
      saved = await fakeRepository.getThemeMode('demo-user');
      expect(saved, equals('system'));
    });
  });
}
