import 'package:flutter/material.dart';
import 'package:pr_app/src/rust/frb_generated.dart';

import 'engine/page_engine.dart';
import 'engine/widget_renderer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const PrApp());
}

class PrApp extends StatelessWidget {
  const PrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pr_app',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const EngineShell(),
    );
  }
}

class EngineShell extends StatefulWidget {
  const EngineShell({super.key});

  @override
  State<EngineShell> createState() => _EngineShellState();
}

class _EngineShellState extends State<EngineShell> {
  static const _bundledPage = 'assets/pages/demo.lua';

  final _urlController = TextEditingController();
  final _engine = PageEngine();

  PageModel? _page;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _engine.onUpdate = (_, __) => setState(() {});
    _loadBundled();
  }

  Future<void> _loadBundled() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _engine.loadFromAsset(_bundledPage);
      if (!mounted) return;
      setState(() => _page = page);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _engine.loadFromUrl(url);
      if (!mounted) return;
      setState(() => _page = page);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_page?.title ?? 'pr_app')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'URL de una página Lua…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _loadFromUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _loadFromUrl,
                  child: const Text('Cargar'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _loadBundled,
                  child: const Text('Demo'),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _page == null
                ? const Center(child: Text('Sin página cargada'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final node in _page!.body)
                        WidgetRenderer.build(
                          context,
                          node,
                          values: _engine.values,
                          onInput: (id, value) {
                            _engine.setInputValue(id, value);
                            setState(() {});
                          },
                          onAction: (name) => _engine.invokeHandler(name),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}