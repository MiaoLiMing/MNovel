import 'package:flutter/material.dart';

import '../../domain/content.dart';
import '../theme/app_theme.dart';

class ChannelTabs extends StatelessWidget {
  const ChannelTabs({super.key, required this.value, required this.onChanged});

  final ContentChannel value;
  final ValueChanged<ContentChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: ContentChannel.values.map((channel) {
          final selected = channel == value;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: '${channel.label}频道',
              child: InkWell(
                onTap: () => onChanged(channel),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      channel.label,
                      style: TextStyle(
                        color: selected
                            ? AppColors.text
                            : AppColors.secondaryText,
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 28 : 0,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
