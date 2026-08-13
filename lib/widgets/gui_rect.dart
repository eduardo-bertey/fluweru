import 'gui_node.dart';

/// Caja/rectángulo con fondo opcional. En Lua:
/// ```lua
/// { type = "rect", text = "caja", bg_color = "#EEEEEE", radius = 12, padding = 8, border_color = "#999", border_width = 1 }
/// ```
class GuiRect extends GuiNode {
  final String? bgColor;
  final double radius;
  final String? borderColor;
  final double borderWidth;

  GuiRect({
    required super.style,
    this.bgColor,
    this.radius = 0,
    this.borderColor,
    this.borderWidth = 0,
  }) : super(type: 'rect');

  factory GuiRect.fromMap(Map<String, Object?> m) => GuiRect(
        style: GuiNode.parseStyle(m),
        bgColor: m['bg_color'] as String?,
        radius: (m['radius'] as num?)?.toDouble() ?? 0,
        borderColor: m['border_color'] as String?,
        borderWidth: (m['border_width'] as num?)?.toDouble() ?? 0,
      );
}
