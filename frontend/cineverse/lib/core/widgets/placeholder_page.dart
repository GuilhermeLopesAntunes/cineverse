import 'package:flutter/material.dart';

/// Tela ainda não implementada. Existe só para o `go_router` ter um
/// `builder` válido enquanto a feature correspondente não chega no backlog
/// — nunca deve ficar visível na versão entregue.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.details});

  final String title;
  final String? details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 12),
              Text('$title — em construção', textAlign: TextAlign.center),
              if (details != null) ...[
                const SizedBox(height: 8),
                Text(details!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
