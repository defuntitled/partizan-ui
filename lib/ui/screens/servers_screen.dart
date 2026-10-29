import 'package:flutter/material.dart';

import 'stub.dart';

/// Server profiles (A07).
class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('СЕРВЕРЫ')),
    body: const StubBody('Здесь будет список серверов'),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Добавить сервер',
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AddServerScreen())),
      child: const Icon(Icons.add),
    ),
  );
}

/// Import from a `partizan://` link or a QR code (A07).
class AddServerScreen extends StatelessWidget {
  const AddServerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ДОБАВИТЬ СЕРВЕР')),
    body: const StubBody(
      'Здесь будет вставка ссылки partizan:// и скан QR-кода',
    ),
  );
}
