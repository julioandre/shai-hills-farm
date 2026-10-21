import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upserts a pending farm record. The phone keeps it if this throws.
class SupabaseSyncTarget implements SyncTarget {
  SupabaseSyncTarget(this._client);

  final SupabaseClient _client;

  @override
  Future<void> push(PendingOp op) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const LedgerFailure('Sign in before syncing.');
    }
    try {
      await _client.from(op.table).upsert({...op.row, 'user_id': userId});
    } catch (error) {
      throw LedgerFailure(
        error is PostgrestException
            ? 'The farm server did not take that record yet.'
            : 'Still offline. The record stays on this phone.',
      );
    }
  }
}
