import 'package:shai_hills_farm/domain/ledger.dart';

/// Sends one saved record to the server. Throw to leave it pending.
abstract interface class SyncTarget {
  Future<void> push(PendingOp op);
}

/// Used when Supabase is not connected. The phone already holds the record.
class LocalSyncTarget implements SyncTarget {
  @override
  Future<void> push(PendingOp op) async {}
}
