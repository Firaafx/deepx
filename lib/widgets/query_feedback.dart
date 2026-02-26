import 'package:flutter/material.dart';

class QueryRetryPane extends StatelessWidget {
  const QueryRetryPane({
    super.key,
    required this.onRetry,
    this.title,
    this.subtitle,
    this.offline = false,
  });

  final VoidCallback onRetry;
  final String? title;
  final String? subtitle;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final String resolvedTitle = title ??
        (offline ? 'No internet connection' : 'Unable to load content');
    final String resolvedSubtitle = subtitle ??
        (offline
            ? 'Check your network and try again.'
            : 'Please retry in a moment.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              resolvedTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              resolvedSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
