import 'package:flutter/material.dart';

/// Compact horizontal up/down arrow controls for sections
class ReorderControls extends StatelessWidget {
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool isCompact;
  
  const ReorderControls({
    super.key,
    required this.canMoveUp,
    required this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isCompact ? 16.0 : 18.0;
    final buttonSize = isCompact ? 26.0 : 30.0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            icon: Icons.keyboard_arrow_up,
            enabled: canMoveUp,
            onPressed: onMoveUp,
            tooltip: 'Move up',
            iconSize: iconSize,
            buttonSize: buttonSize,
          ),
          Container(width: 1, height: buttonSize - 8, color: Colors.grey.shade200),
          _buildButton(
            icon: Icons.keyboard_arrow_down,
            enabled: canMoveDown,
            onPressed: onMoveDown,
            tooltip: 'Move down',
            iconSize: iconSize,
            buttonSize: buttonSize,
          ),
        ],
      ),
    );
  }
  
  Widget _buildButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback? onPressed,
    required String tooltip,
    required double iconSize,
    required double buttonSize,
  }) {
    return SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: iconSize),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: enabled ? Colors.grey.shade700 : Colors.grey.shade300,
        tooltip: tooltip,
        splashRadius: buttonSize / 2,
      ),
    );
  }
}

/// Vertical variant - more compact for inline with cards
class ReorderControlsVertical extends StatelessWidget {
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  
  const ReorderControlsVertical({
    super.key,
    required this.canMoveUp,
    required this.canMoveDown,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 24,
            child: IconButton(
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: canMoveUp ? Colors.grey.shade700 : Colors.grey.shade300,
              tooltip: 'Move up',
              splashRadius: 12,
            ),
          ),
          Container(width: 20, height: 1, color: Colors.grey.shade200),
          SizedBox(
            width: 28,
            height: 24,
            child: IconButton(
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: canMoveDown ? Colors.grey.shade700 : Colors.grey.shade300,
              tooltip: 'Move down',
              splashRadius: 12,
            ),
          ),
        ],
      ),
    );
  }
}

