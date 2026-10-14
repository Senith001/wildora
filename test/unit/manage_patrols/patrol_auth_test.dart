import 'package:flutter_test/flutter_test.dart';
import 'package:wildora/src/features/manage_patrols/data/patrol_auth_service.dart';

void main() {
  group('PatrolAuthService', () {
    late InMemoryPatrolAuthService authService;

    setUp(() {
      authService = InMemoryPatrolAuthService(
        currentRole: 'ranger',
        currentUserId: 'ranger_yala_001',
        currentUserName: 'Mihiranga R P (R-4089)',
      );
    });

    test('defaults to least privilege ranger role', () async {
      expect(await authService.getCurrentRole(), 'ranger');
      expect(await authService.isParkManager(), isFalse);
      expect(await authService.getCurrentUserId(), 'ranger_yala_001');
      expect(await authService.getCurrentUserName(), 'Mihiranga R P (R-4089)');
    });

    test('identifies park manager privileges accurately', () async {
      await authService.signIn(
        role: 'manager',
        officerId: 'mgr_001',
        name: 'Chief Park Warden',
      );

      expect(await authService.getCurrentRole(), 'manager');
      expect(await authService.isParkManager(), isTrue);
      expect(await authService.getCurrentUserId(), 'mgr_001');
      expect(await authService.getCurrentUserName(), 'Chief Park Warden');
    });

    test('admin role also satisfies isParkManager check', () async {
      await authService.signIn(
        role: 'admin',
        officerId: 'admin_001',
        name: 'System Administrator',
      );

      expect(await authService.isParkManager(), isTrue);
    });

    test('retrieves registered rangers list with real contact and ID info',
        () async {
      final rangers = await authService.getRegisteredRangers();

      expect(rangers.isNotEmpty, isTrue);
      expect(rangers.every((r) => r.role == 'ranger'), isTrue);
      expect(rangers.any((r) => r.officerId.isNotEmpty), isTrue);
    });

    test('FirebasePatrolAuthService falls back safely to unauthenticated when uninitialized',
        () async {
      final fbAuth = FirebasePatrolAuthService();

      // Should not throw even without Firebase.initializeApp()
      final role = await fbAuth.getCurrentRole();
      expect(role, isNull);

      final isManager = await fbAuth.isParkManager();
      expect(isManager, isFalse);

      final rangers = await fbAuth.getRegisteredRangers();
      expect(rangers.isEmpty, isTrue);
    });

    test('supports signInWithEmail and signOut on auth service', () async {
      await authService.signInWithEmail('manager@wildora.example', 'secret123');
      expect(await authService.isParkManager(), isTrue);

      await authService.signOut();
      expect(await authService.getCurrentRole(), isNull);
      expect(await authService.isParkManager(), isFalse);
    });
  });
}
