import 'package:flutter/material.dart';

import '../../domain/content.dart';
import '../theme/app_theme.dart';

class SmileIndicatorPainter extends CustomPainter {
  SmileIndicatorPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(2, 2)
      ..quadraticBezierTo(size.width / 2, size.height + 2, size.width - 2, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChannelTabs extends StatelessWidget {
  const ChannelTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.channels = ContentChannel.values,
  });

  final ContentChannel value;
  final ValueChanged<ContentChannel> onChanged;
  final List<ContentChannel> channels;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = channels.indexOf(value);
    final count = channels.length;
    final double alignX = count > 1 
        ? -1.0 + (selectedIndex / (count - 1)) * 2.0
        : 0.0;

    return SizedBox(
      height: 50,
      child: Stack(
        children: [
          Row(
            children: channels.map((channel) {
              final selected = channel == value;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: '${channel.label}频道',
                  child: InkWell(
                    onTap: () => onChanged(channel),
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          style: TextStyle(
                            color: selected
                                ? AppColors.sage
                                : AppColors.secondaryText,
                            fontSize: 16,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(channel.label),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              alignment: Alignment(alignX, 1.0),
              child: FractionallySizedBox(
                widthFactor: 1.0 / count,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 5,
                    child: CustomPaint(
                      painter: SmileIndicatorPainter(color: AppColors.sage),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
