import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'storage_backend_base.dart';

class _IoStorageBackend implements StorageBackend {
  @override
  Future<String?> read(String key) async {
    final file = await _resolveFile(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _resolveFile(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
  }

  Future<File> _resolveFile(String key) async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, '$key.json'));
  }
}

StorageBackend createStorageBackendImpl() => _IoStorageBackend();
