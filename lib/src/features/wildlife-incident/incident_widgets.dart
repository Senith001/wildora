import 'package:flutter/material.dart';

const incidentGreen = Color(0xFF10583F);

class IncidentActionButton extends StatelessWidget {
  const IncidentActionButton({
    super.key,
    required this.label,
    this.filled = true,
    required this.onPressed,
  });
  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: incidentGreen),
            child: Text(label),
          )
        : OutlinedButton(onPressed: onPressed, child: Text(label)),
  );
}

class IncidentPage extends StatelessWidget {
  const IncidentPage({
    super.key,
    required this.title,
    required this.children,
    this.step,
    this.onBack,
    this.footer,
  });
  final String title;
  final List<Widget> children;
  final int? step;
  final VoidCallback? onBack;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F6F3),
    appBar: AppBar(
      backgroundColor: incidentGreen,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(title),
      automaticallyImplyLeading: false,
      leading: onBack == null
          ? null
          : IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              if (step != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: List.generate(7, (index) {
                      if (index.isOdd) return const Expanded(child: Divider());
                      final number = index ~/ 2 + 1;
                      return CircleAvatar(
                        radius: 14,
                        backgroundColor: number == step
                            ? incidentGreen
                            : const Color(0xFFDCE6E2),
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 12,
                            color: number == step
                                ? Colors.white
                                : incidentGreen,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: children,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class IncidentInfoCard extends StatelessWidget {
  const IncidentInfoCard({super.key, required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    ),
  );
}
