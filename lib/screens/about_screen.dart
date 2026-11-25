import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Vraja Mandala', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Vraja Mandala is an offline guide to the holy personalities, '
            'places and stories of Vraja. Each page links to related pages, '
            'so you can wander from one to the next.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text('About the content', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'The stories are short retellings in simple language. Each one '
            'names the scripture and verses it is based on, so that you can '
            'read the original. Pages marked as drafts have not yet been '
            'reviewed by a qualified reader.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
