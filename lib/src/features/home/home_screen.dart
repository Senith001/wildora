import 'package:flutter/material.dart';

/// Refined home screen with themed dashboard design.
/// Features a header band and quick-actions grid for production use.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wildora'),
        // Removed explicit backgroundColor to use theme's conservation-green appBarTheme
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          return SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      // Conservation-green header band
                      _buildHeaderBand(context),
                      
                      // Main content with padding
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            
                            // Quick actions grid
                            _buildQuickActionsGrid(context, isWide),
                            
                            const SizedBox(height: 32),

                            // High-Risk Movement Monitoring entry point
                            _buildMonitoringCard(context),
                          ],
                        ),
                      ),
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

  /// Build conservation-green header band with title and subtitle
  Widget _buildHeaderBand(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wildlife Monitor',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ranger Dashboard',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build responsive quick actions grid
  Widget _buildQuickActionsGrid(BuildContext context, bool isWide) {
    final crossAxisCount = isWide ? 3 : 2;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildQuickActionCard(
          context,
          icon: Icons.warning_amber_rounded,
          title: 'Risk Alerts',
          subtitle: 'Monitor threats',
          onTap: () => Navigator.pushNamed(context, '/monitoring'),
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.map_outlined,
          title: 'Live Map',
          subtitle: 'Track locations',
          onTap: () => _showComingSoon(context, 'Live Map'),
          isActive: false,
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.pets_outlined,
          title: 'Animals',
          subtitle: 'Wildlife data',
          onTap: () => _showComingSoon(context, 'Animal Tracking'),
          isActive: false,
        ),
        _buildQuickActionCard(
          context,
          icon: Icons.assignment_outlined,
          title: 'Reports',
          subtitle: 'Generate reports',
          onTap: () => _showComingSoon(context, 'Reports'),
          isActive: false,
        ),
      ],
    );
  }

  /// Build individual quick action card
  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isActive = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: isActive ? 2 : 1,
      color: isActive 
        ? colorScheme.surfaceContainerLow 
        : colorScheme.surfaceContainerLow.withOpacity(0.6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isActive 
                  ? colorScheme.primary 
                  : colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isActive 
                    ? colorScheme.onSurface 
                    : colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isActive 
                    ? colorScheme.onSurfaceVariant 
                    : colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show coming soon message for inactive features
  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        duration: const Duration(seconds: 2),
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
