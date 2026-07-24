import 'package:flutter/material.dart';

import '../../domain/content.dart';
import '../theme/app_theme.dart';
import 'content_cover.dart';

class PageTitleBar extends StatelessWidget {
  const PageTitleBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -.35,
            ),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (action != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryText,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action!, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 1),
              const Icon(Icons.chevron_right_rounded, size: 15),
            ],
          ),
        ),
    ],
  );
}

class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    this.hint = '搜索书名 / 作者 / 关键词',
    required this.onTap,
  });

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.sand,
    borderRadius: BorderRadius.circular(AppRadii.pill),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: onTap,
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.tertiaryText,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(
                  color: AppColors.tertiaryText,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NovelListRow extends StatelessWidget {
  const NovelListRow({
    super.key,
    required this.item,
    required this.onTap,
    this.trailing,
    this.progress,
    this.compact = false,
  });

  final ContentItem item;
  final VoidCallback onTap;
  final Widget? trailing;
  final double? progress;
  final bool compact;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentCover(
            asset: item.coverAsset,
            width: compact ? 46 : 54,
            height: compact ? 62 : 72,
            radius: 6,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.latestChapter.isEmpty
                      ? '${item.creator} · ${item.category}'
                      : item.latestChapter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${item.episodeCount}章 · ${item.creator}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.tertiaryText,
                    fontSize: 10,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            value: progress!.clamp(0, 1),
                            backgroundColor: AppColors.divider,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${(progress! * 100).round()}%',
                        style: const TextStyle(
                          color: AppColors.tertiaryText,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ),
  );
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.coralSoft : AppColors.sand,
    borderRadius: BorderRadius.circular(dense ? 8 : 9),
    child: InkWell(
      borderRadius: BorderRadius.circular(dense ? 8 : 9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: BoxConstraints(minWidth: dense ? 52 : 60),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 12,
          vertical: dense ? 7 : 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(dense ? 8 : 9),
          border: Border.all(
            color: selected ? AppColors.coral : Colors.transparent,
            width: .8,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.coral : AppColors.secondaryText,
            fontSize: dense ? 10 : 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
    ),
  );
}

class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.sand,
      foregroundColor: AppColors.text,
    ),
    icon: Icon(icon, size: 18),
  );
}
