import 'package:flutter/material.dart';

/// A basic test/placeholder home screen with responsive layout.
/// This is for testing purposes and does not contain business logic.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wildora'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Header section
                      Icon(
                        Icons.home,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to Wildora',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Initial setup is working ✅',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Cards section - responsive layout
                      if (isWide)
                        _buildWideLayout(context)
                      else
                        _buildNarrowLayout(context),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildCard(context, Icons.widgets, 'Section A'),
        const SizedBox(height: 12),
        _buildCard(context, Icons.settings, 'Section B'),
        const SizedBox(height: 12),
        _buildCard(context, Icons.info, 'Section C'),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 280,
          child: _buildCard(context, Icons.widgets, 'Section A'),
        ),
        SizedBox(
          width: 280,
          child: _buildCard(context, Icons.settings, 'Section B'),
        ),
        SizedBox(
          width: 280,
          child: _buildCard(context, Icons.info, 'Section C'),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        subtitle: Text(
          'Placeholder content',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
