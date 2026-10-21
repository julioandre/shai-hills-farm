import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/feed_stock.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/receipt_draft.dart';

void main() {
  test('feed on hand is bought minus used', () {
    final today = DateTime(2026, 10, 12);
    final bins = feedBins(
      FarmLedger(
        purchases: [
          FeedPurchase(
            id: 'buy',
            happenedOn: today,
            supplier: 'Mill',
            feedType: 'Maize bran',
            costCedis: 100,
            quantityKg: 200,
            locationId: 'piggery',
            updatedAt: today,
          ),
        ],
        feedUses: [
          FeedUse(
            id: 'use',
            happenedOn: today,
            locationId: 'piggery',
            species: Species.pig,
            feedType: 'Maize bran',
            quantityKg: 80,
            updatedAt: today,
          ),
        ],
      ),
    );
    expect(bins.single.feedType, 'Maize bran');
    expect(bins.single.onHandKg, 120);
    expect(bins.single.short, isFalse);
  });

  test('a short bin is used more than was bought', () {
    final today = DateTime(2026, 10, 12);
    final bins = feedBins(
      FarmLedger(
        feedUses: [
          FeedUse(
            id: 'use',
            happenedOn: today,
            locationId: 'piggery',
            species: Species.pig,
            feedType: 'Concentrate',
            quantityKg: 10,
            updatedAt: today,
          ),
        ],
      ),
    );
    expect(bins.single.short, isTrue);
  });

  test('receipt text becomes supplier and amount', () {
    final draft = parseReceiptText(
      'Here is the receipt {"supplier":"Shai Hills mill","amount":960,"note":"Maize bran"} thanks',
    );
    expect(draft!.supplier, 'Shai Hills mill');
    expect(draft.amountCedis, 960);
    expect(draft.note, 'Maize bran');
    expect(parseReceiptText('no json here'), isNull);
    final lines = parseReceiptText(
      '{"supplier":"Tema mill","category":"feed","items":[{"name":"Maize bran","quantity":40,"amount":120,"site":"piggery"},{"name":"Salt","quantity":2,"amount":10,"site":"all"}]}',
    );
    expect(lines!.items, hasLength(2));
    expect(lines.items.first.quantity, 40);
    expect(lines.items.last.site, 'all');
  });
}
