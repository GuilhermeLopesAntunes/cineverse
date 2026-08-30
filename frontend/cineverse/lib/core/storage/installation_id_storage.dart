import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Identificador estável de instalação, gerado uma vez e persistido. Usado
/// como "token de push" quando não há projeto Firebase configurado — o
/// backend aceita qualquer string em `POST /push-tokens` (ver CLAUDE.md §
/// Armadilhas, item 8).
class InstallationIdStorage {
  InstallationIdStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'installation_id';

  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null) return existing;

    final generated = const Uuid().v4();
    await _storage.write(key: _key, value: generated);
    return generated;
  }
}
