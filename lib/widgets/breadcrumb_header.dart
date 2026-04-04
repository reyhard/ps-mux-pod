import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/mux_provider.dart';
import '../services/mux/mux_node.dart';
import '../theme/design_colors.dart';

/// Breadcrumb navigation header
///
/// Example: [psmux:work] -> [wsl:Ubuntu] -> [tmux:dev] -> window:editor -> pane:0
/// Tap each segment to navigate through MuxProvider.
class BreadcrumbHeader extends ConsumerWidget {
  const BreadcrumbHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muxState = ref.watch(muxProvider);
    final breadcrumbs = ref.read(muxProvider.notifier).breadcrumbPath;

    if (breadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? DesignColors.textMuted : DesignColors.textMutedLight;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: breadcrumbs.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Text(
              '\u2192', // →
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: mutedColor,
              ),
            ),
          ),
        ),
        itemBuilder: (context, index) {
          final node = breadcrumbs[index];
          final isCurrentNode = node == muxState.currentNode;
          return _BreadcrumbChip(
            node: node,
            isActive: isCurrentNode,
            onTap: () {
              if (!isCurrentNode) {
                ref.read(muxProvider.notifier).setCurrentNode(node);
              }
            },
          );
        },
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final MuxNode node;
  final bool isActive;
  final VoidCallback onTap;

  const _BreadcrumbChip({
    required this.node,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.15)
                : (isDark
                    ? DesignColors.surfaceDark
                    : DesignColors.surfaceLight)
                    .withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            node.label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
