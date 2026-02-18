import 'package:flutter/material.dart';

import '../app_state.dart';

class Toolbar extends StatelessWidget {
  const Toolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.of(context);
    final actions = AppStateWidget.of(context);

    return Container(
      width: 72,
      color: const Color(0xFF2C2C2E),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 8),
              // ツール選択セクション
              _SectionLabel('ツール'),
              _ToolButton(
                icon: Icons.edit,
                label: '手書き',
                tool: ToolType.freehand,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.freehand),
              ),
              _ToolButton(
                icon: Icons.horizontal_rule,
                label: '実線',
                tool: ToolType.lineSolid,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.lineSolid),
              ),
              _ToolButton(
                icon: Icons.more_horiz,
                label: '破線',
                tool: ToolType.lineDashed,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.lineDashed),
              ),
              _ToolButton(
                icon: Icons.auto_fix_high,
                label: '消しゴム',
                tool: ToolType.eraser,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.eraser),
              ),
              _ToolButton(
                icon: Icons.near_me,
                label: '選択',
                tool: ToolType.select,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.select),
              ),
              const _Divider(),
              // 図形スタンプセクション
              _SectionLabel('図形'),
              _ToolButton(
                icon: Icons.crop_square,
                label: '正方形',
                tool: ToolType.shapeSquare,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.shapeSquare),
              ),
              _ToolButton(
                icon: Icons.radio_button_unchecked,
                label: '円形',
                tool: ToolType.shapeCircle,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.shapeCircle),
              ),
              _ToolButton(
                icon: Icons.change_history,
                label: '三角形',
                tool: ToolType.shapeTriangle,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.shapeTriangle),
              ),
              _ToolButton(
                icon: Icons.diamond,
                label: '菱形',
                tool: ToolType.shapeDiamond,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.shapeDiamond),
              ),
              _ToolButton(
                icon: Icons.star_border,
                label: '星形',
                tool: ToolType.shapeStar,
                currentTool: state.selectedTool,
                onTap: () => actions.setTool(ToolType.shapeStar),
              ),
              const _Divider(),
              // カラーパレットセクション
              _SectionLabel('色'),
              for (final color in kPaletteColors)
                _ColorButton(
                  color: color,
                  isSelected: state.selectedColor == color,
                  onTap: () => actions.setColor(color),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 内部ウィジェット ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Divider(color: Color(0xFF48484A), height: 1, thickness: 1),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final ToolType tool;
  final ToolType currentTool;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.tool,
    required this.currentTool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = tool == currentTool;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0A84FF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : const Color(0xFFAEAEB2),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFF48484A),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(77),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}


