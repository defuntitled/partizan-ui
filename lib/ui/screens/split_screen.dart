import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile.dart';
import '../../core/split.dart';
import '../../core/vpn_status.dart';
import '../../state/profiles.dart';
import '../../state/vpn.dart';
import '../theme.dart';
import '../widgets/art.dart';

/// Split tunneling by addresses and networks (A09): shared rules or the active server's own,
/// the mode, the list, import and export as a file.
class SplitTunnelScreen extends ConsumerWidget {
  const SplitTunnelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProfileProvider).value;
    final scope = active != null && active.ownRules ? active.id : null;
    final rules = ref.watch(_rulesProvider(scope));
    final running = isActive(
      ref.watch(vpnStatusProvider).value?.state ?? VpnState.idle,
    );
    return DarkScaffold(
      title: 'РАЗДЕЛЬНОЕ ТУННЕЛИРОВАНИЕ',
      // The list runs to the bottom: stones there would sit under its text.
      debris: false,
      actions: [
        IconButton(
          tooltip: 'Импорт из файла',
          icon: const Icon(Icons.file_open_outlined),
          onPressed: rules.value == null
              ? null
              : () => _import(context, ref, scope, rules.value!),
        ),
        IconButton(
          tooltip: 'Экспорт в файл',
          icon: const Icon(Icons.save_alt),
          onPressed: rules.value == null
              ? null
              : () => _export(context, ref, rules.value!),
        ),
      ],
      body: switch (rules) {
        AsyncData(:final value) => _Body(
          active: active,
          scope: scope,
          rules: value,
          running: running,
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _import(
    BuildContext context,
    WidgetRef ref,
    int? scope,
    SplitRules rules,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await ref.read(routeFilesProvider).open();
    if (text == null || !context.mounted) return;
    final parsed = parseRoutes(text);
    final choice = await showDialog<_ImportChoice>(
      context: context,
      builder: (_) =>
          _ImportDialog(parsed, hasCurrent: rules.routes.isNotEmpty),
    );
    if (choice == null) return;
    final routes = switch (choice) {
      _ImportChoice.add => mergeRoutes(rules.routes, parsed.routes),
      _ImportChoice.replace => parsed.routes,
    };
    await ref
        .read(profileStoreProvider)
        .saveRules(scope, rules.copyWith(routes: routes));
    messenger.showSnackBar(
      SnackBar(content: Text('В списке ${routes.length} записей')),
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    SplitRules rules,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(routeFilesProvider)
        .save('partizan-routes.txt', '${formatRoutes(rules.routes)}\n');
    if (saved) {
      messenger.showSnackBar(
        SnackBar(content: Text('Сохранено записей: ${rules.routes.length}')),
      );
    }
  }
}

final _rulesProvider = StreamProvider.family<SplitRules, int?>(
  (ref, scope) => ref.watch(profileStoreProvider).watchRules(scope),
);

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.active,
    required this.scope,
    required this.rules,
    required this.running,
  });

  final ServerProfile? active;
  final int? scope;
  final SplitRules rules;
  final bool running;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _entry = TextEditingController();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  Future<void> _save(SplitRules rules) =>
      ref.read(profileStoreProvider).saveRules(widget.scope, rules);

  Future<void> _add() async {
    final parsed = parseRoutes(_entry.text);
    if (parsed.routes.isNotEmpty) {
      await _save(
        widget.rules.copyWith(
          routes: mergeRoutes(widget.rules.routes, parsed.routes),
        ),
      );
    }
    if (!mounted) return;
    if (parsed.rejected.isEmpty) {
      _entry.clear();
    } else {
      _entry.text = parsed.rejected.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не распознано: ${parsed.rejected.join(', ')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final rules = widget.rules;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: PartizanColors.muted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (active != null) ...[
          SegmentedButton<bool>(
            key: const Key('rules-scope'),
            segments: [
              const ButtonSegment(value: false, label: Text('Общие')),
              ButtonSegment(value: true, label: Text('Для «${active.name}»')),
            ],
            selected: {active.ownRules},
            onSelectionChanged: (own) => ref
                .read(profileStoreProvider)
                .setOwnRules(active.id, own.single),
          ),
          const SizedBox(height: 16),
        ],
        SegmentedButton<SplitMode>(
          key: const Key('rules-mode'),
          segments: const [
            ButtonSegment(
              value: SplitMode.include,
              label: Text('Только список'),
            ),
            ButtonSegment(value: SplitMode.exclude, label: Text('Всё, кроме')),
          ],
          selected: {rules.mode},
          onSelectionChanged: (mode) =>
              _save(rules.copyWith(mode: mode.single)),
        ),
        const SizedBox(height: 8),
        Text(switch (rules.mode) {
          SplitMode.include =>
            'Через VPN идут только адреса из списка, остальное — напрямую.',
          SplitMode.exclude => 'Через VPN идёт всё, кроме адресов из списка.',
        }, style: muted),
        Text('DNS-запросы всегда идут через VPN.', style: muted),
        if (widget.running)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Изменения применятся при следующем подключении.',
              key: const Key('rules-next-time'),
              style: muted,
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('route-field'),
                controller: _entry,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: '99.84.0.0/16, 203.0.113.7',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: 'Добавить',
              icon: const Icon(Icons.add),
              onPressed: _add,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rules.routes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              rules.mode == SplitMode.include
                  ? 'Список пуст: через VPN пойдёт только DNS.'
                  : 'Список пуст: через VPN идёт весь трафик.',
              textAlign: TextAlign.center,
              style: muted,
            ),
          ),
        for (final net in rules.routes)
          ListTile(
            key: ValueKey('route-$net'),
            title: Text('$net'),
            trailing: IconButton(
              tooltip: 'Удалить $net',
              icon: const Icon(Icons.close),
              onPressed: () => _save(
                rules.copyWith(
                  routes: rules.routes.where((r) => r != net).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum _ImportChoice { add, replace }

class _ImportDialog extends StatelessWidget {
  const _ImportDialog(this.parsed, {required this.hasCurrent});

  final ParsedRoutes parsed;
  final bool hasCurrent;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Импорт'),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Распознано записей: ${parsed.routes.length}',
            key: const Key('import-count'),
          ),
          if (parsed.rejected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Отклонено (${parsed.rejected.length}):'),
            for (final line in parsed.rejected)
              Text(
                line,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      if (hasCurrent)
        TextButton(
          onPressed: parsed.routes.isEmpty
              ? null
              : () => Navigator.of(context).pop(_ImportChoice.replace),
          child: const Text('Заменить'),
        ),
      FilledButton(
        onPressed: parsed.routes.isEmpty
            ? null
            : () => Navigator.of(context).pop(_ImportChoice.add),
        child: Text(hasCurrent ? 'Добавить' : 'Импортировать'),
      ),
    ],
  );
}
