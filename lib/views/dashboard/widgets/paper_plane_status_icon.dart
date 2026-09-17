import 'package:flutter/material.dart';

/// Paper plane icon that rotates based on connection state
class PaperPlaneStatusIcon extends StatelessWidget {
  final bool disconnected;

  const PaperPlaneStatusIcon({
    super.key,
    required this.disconnected,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: disconnected ? 0 : -0.785398, // 0° disconnected, -45° connected
      child: const Icon(Icons.send_rounded),
    );
  }
}
