import 'package:flutter/material.dart';
import '../../domain/content.dart';

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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
