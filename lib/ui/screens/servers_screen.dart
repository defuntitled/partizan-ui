import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/link.dart';
import '../../core/profile.dart';
import '../../core/vpn_bridge.dart';
import '../../state/profiles.dart';
import '../../state/vpn.dart';
import '../theme.dart';
import '../widgets/art.dart';
import 'stub.dart';

/// Server profiles: tap to make one active, drag to reorder, menu to rename or delete.
class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider).value;
    final store = ref.read(profileStoreProvider);
    // Under the map, above the stones.
    final padding = EdgeInsets.fromLTRB(
      16,
      _WorldMap.height + 20,
      16,
      Debris.top(MediaQuery.sizeOf(context).width) + 16,
    );
    const add = _AddServerTile();
    return DarkScaffold(
      title: 'СЕРВЕРЫ',
      behind: const _WorldMap(),
      body: switch (profiles) {
        AsyncData(:final value) when value.isEmpty => ListView(
          padding: padding,
          children: const [
            add,
            SizedBox(height: 24),
            StubBody(
              'Серверов пока нет.\nДобавьте сервер по ссылке partizan:// или QR-коду.',
            ),
          ],
        ),
        AsyncData(:final value) => ReorderableListView.builder(
          padding: padding,
          header: add,
          buildDefaultDragHandles: false,
          itemCount: value.length,
          onReorderItem: (from, to) {
            final ids = [for (final p in value) p.id];
            ids.insert(to, ids.removeAt(from));
            store.reorder(ids);
          },
          itemBuilder: (context, i) => _ProfileTile(
            key: ValueKey(value[i].id),
            index: i,
            profile: value[i],
            active: value[i].id == active?.id,
          ),
        ),
        AsyncError(:final error) => StubBody('Список недоступен: $error'),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The first row of the list: adds a server.
class _AddServerTile extends StatelessWidget {
  const _AddServerTile();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      key: const Key('add-server'),
      leading: const Icon(Icons.add, color: PartizanColors.red),
      title: const Text('Добавить сервер'),
      subtitle: const Text('Ссылка partizan:// или QR-код'),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddServerScreen())),
    ),
  );
}

/// The world map, dim, along the top of the list.
class _WorldMap extends StatelessWidget {
  const _WorldMap();

  /// The map's height, top padding included: the list starts below it.
  static const double height = 154;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: SvgPicture.asset(
          Art.world,
          key: const Key('world-map'),
          height: height - 4,
          colorFilter: const ColorFilter.mode(
            Color(0xFF3A3A3A),
            BlendMode.srcIn,
          ),
        ),
      ),
    ),
  );
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({
    super.key,
    required this.index,
    required this.profile,
    required this.active,
  });

  final int index;
  final ServerProfile profile;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(profileStoreProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: active ? PartizanColors.red : PartizanColors.muted,
        ),
        title: Text(profile.name),
        subtitle: Text(profile.address),
        onTap: () async {
          await store.setActive(profile.id);
          if (context.mounted) Navigator.of(context).pop();
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Действия',
              onSelected: (action) async {
                if (action == 'rename') {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => _RenameDialog(profile.name),
                  );
                  if (name != null) await store.rename(profile.id, name);
                } else {
                  await store.delete(profile.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog(this.name);

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Название'),
    content: TextField(
      key: const Key('rename-field'),
      controller: _controller,
      autofocus: true,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          final name = _controller.text.trim();
          if (name.isNotEmpty) Navigator.of(context).pop(name);
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}

/// Import from a pasted `partizan://` link or a QR code. The core checks the link
/// (`check_uri`) before it is saved; the name defaults to the host.
class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _link = TextEditingController();
  final _name = TextEditingController();
  bool _checking = false;
  LinkCheckException? _problem;

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  LinkInfo? get _info => LinkInfo.parse(_link.text);

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final problem = _problem;
    return DarkScaffold(
      title: 'ДОБАВИТЬ СЕРВЕР',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          // The keyboard must not learn the token: no suggestions, no autocorrect.
          TextField(
            key: const Key('link-field'),
            controller: _link,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              labelText: 'Ссылка partizan://',
              errorText: _link.text.isNotEmpty && info == null
                  ? 'Это не ссылка partizan://'
                  : null,
            ),
            onChanged: (_) => setState(() => _problem = null),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Вставить'),
                  onPressed: _paste,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR-код'),
                  onPressed: _scan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('name-field'),
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Название',
              hintText: info?.host ?? 'по умолчанию — адрес сервера',
            ),
          ),
          if (info != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Сервер ${info.address}',
                key: const Key('link-address'),
              ),
            ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                switch (problem.problem) {
                  LinkProblem.invalid =>
                    'Ссылка некорректна: ${problem.message}',
                  LinkProblem.unreachable =>
                    'Сервер не отвечает: ${problem.message}',
                },
                key: const Key('link-problem'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save'),
            onPressed: info == null || _checking ? null : () => _save(info),
            child: _checking
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Проверить и сохранить'),
          ),
          if (problem?.problem == LinkProblem.unreachable && info != null)
            TextButton(
              key: const Key('save-unchecked'),
              onPressed: () => _store(info),
              child: const Text('Сохранить без проверки'),
            ),
        ],
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _link.text = text;
      _problem = null;
    });
  }

  Future<void> _scan() async {
    final text = await Navigator.of(context)
        .push(MaterialPageRoute<String>(builder: (_) => const ScanScreen()));
    if (text == null) return;
    setState(() {
      _link.text = text;
      _problem = null;
    });
  }

  Future<void> _save(LinkInfo info) async {
    setState(() {
      _checking = true;
      _problem = null;
    });
    try {
      await ref.read(vpnBridgeProvider).checkUri(_link.text.trim());
      await _store(info);
    } on LinkCheckException catch (e) {
      if (mounted) setState(() => _problem = e);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _store(LinkInfo info) async {
    final name = _name.text.trim();
    await ref
        .read(profileStoreProvider)
        .add(
          name: name.isEmpty ? info.host : name,
          info: info,
          link: _link.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }
}

/// Camera view that returns the first `partizan://` link it sees.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR-КОД')),
    body: MobileScanner(
      onDetect: (capture) {
        if (_done) return;
        for (final code in capture.barcodes) {
          final text = code.rawValue?.trim();
          if (text != null && text.startsWith(LinkInfo.scheme)) {
            _done = true;
            Navigator.of(context).pop(text);
            return;
          }
        }
      },
    ),
  );
}
