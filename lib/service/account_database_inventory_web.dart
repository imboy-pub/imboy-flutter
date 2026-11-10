import 'package:idb_shim/idb_client_native.dart';

// Never fall back to an empty in-memory store when browser storage is blocked.
IdbFactory get accountInventoryIdbFactory => idbFactoryNative;
