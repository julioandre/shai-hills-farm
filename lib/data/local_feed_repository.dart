import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';

const feedMillKey = 'shai_hills.feed';

/// Feed ingredients, recipes, mixes, and issues saved on the phone.
class LocalFeedRepository {
  LocalFeedRepository(this._store);

  final KeyValueStore _store;

  Future<FeedMill> read() async {
    final raw = await _store.read(feedMillKey);
    if (raw == null || raw.isEmpty) {
      return FeedMill.empty;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FeedFailure(
        'The feed records on this phone could not be read.',
      );
    }
    return FeedMill.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> write(FeedMill mill) {
    return _store.write(feedMillKey, jsonEncode(mill.toJson()));
  }
}
