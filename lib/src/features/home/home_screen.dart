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

                      const SizedBox(height: 32),

                      // High-Risk Movement Monitoring entry point
                      _buildMonitoringCard(context),
                      const SizedBox(height: 16),
                      _buildConflictCard(context),
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

  Widget _buildConflictCard(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.campaign),
        title: const Text('Report Human-Wildlife Conflict'),
        subtitle: const Text(
          'Submit sightings, crop raids and safety concerns',
        ),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () => Navigator.pushNamed(context, '/conflict'),
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

  /// Build monitoring dashboard entry card
  Widget _buildMonitoringCard(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/monitoring'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.security,
                size: 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(height: 12),
              Text(
                'High-Risk Movement Monitoring',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor wildlife movement alerts and coordinate emergency responses',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Dashboard',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
