import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';

void main() {
  test('a birth stays on the phone until the server accepts it', () async {
    final repository = LocalLedgerRepository(MemoryStore());
    await repository.addBirth(
      BirthRecord(
        id: 'birth-1',
        happenedOn: DateTime(2026, 10, 20),
        species: Species.pig,
        damTag: 'SOW-1',
        bornAlive: 9,
        stillborn: 1,
        locationId: 'main',
        updatedAt: DateTime.utc(2026, 10, 20),
      ),
    );

    expect((await repository.read()).births.single.damTag, 'SOW-1');
    expect((await repository.read()).pendingCount, 1);

    final offline = _RejectingSync();
    expect(() => repository.flush(offline), throwsA(isA<LedgerFailure>()));
    expect((await repository.read()).pendingCount, 1);

    final online = _RecordingSync();
    expect(await repository.flush(online), 1);
    expect(online.tables, ['births']);
    expect((await repository.read()).pendingCount, 0);
    expect(await repository.flush(online), 0);
  });
}

class _RejectingSync implements SyncTarget {
  @override
  Future<void> push(PendingOp op) async {
    throw Exception('offline');
  }
}

class _RecordingSync implements SyncTarget {
  final tables = <String>[];

  @override
  Future<void> push(PendingOp op) async {
    tables.add(op.table);
  }
}
