import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class ReleaseNotesView extends StatelessWidget {
  final String markdown;
  final double maxHeight;

  const ReleaseNotesView({
    super.key,
    required this.markdown,
    this.maxHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        color: theme.colorScheme.onSurface,
      ),
      h1: theme.textTheme.titleLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      h2: theme.textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      h3: theme.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13,
        color: theme.colorScheme.onSurface,
      ),
      a: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: markdown,
          selectable: true,
          shrinkWrap: true,
          styleSheet: baseStyle,
          onTapLink: (text, href, title) async {
            if (href == null) return;
            final uri = Uri.tryParse(href);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }
}
