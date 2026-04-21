import 'storage_backend_base.dart';
import 'storage_backend_io.dart'
    if (dart.library.html) 'storage_backend_web.dart';

StorageBackend createStorageBackend() => createStorageBackendImpl();
