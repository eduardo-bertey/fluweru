import 'package:flutter/material.dart';

/// Convierte un nodo Lua (tabla con campos type/id/text/label/value/on_click)
/// en el widget de Flutter correspondiente.
class WidgetRenderer {
  static Widget build(
    BuildContext context,
    Map<String, Object?> node, {
    required Map<String, String> values,
    required ValueChanged<String> onInput,
    required void Function(String name) onAction,
  }) {
    final type = node['type'] as String? ?? 'text';
    final id = node['id'] as String?;
    final text = node['text'] as String? ?? '';
    final label = node['label'] as String?;
    final action = node['on_click'] as String?;

    switch (type) {
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
      case 'input':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            key: ValueKey('input_$id'),
            initialValue: values[id] ?? node['value'] as String? ?? '',
            decoration: InputDecoration(
              labelText: label ?? '',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (id != null) onInput(id, value);
            },
          ),
        );
      case 'button':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton(
            onPressed: action == null ? null : () => onAction(action),
            child: Text(text),
          ),
        );
      case 'divider':
        return const Divider(height: 24);
      case 'spacer':
        return const SizedBox(height: 16);
      case 'text':
      default:
        final display = (id != null && values.containsKey(id))
            ? values[id]!
            : text;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(display),
        );
    }
  }
}