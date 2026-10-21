import 'dart:convert';

import 'package:shai_hills_farm/domain/farm_scope.dart';

/// One line read from a receipt photo.
class ReceiptItem {
  const ReceiptItem({
    this.name = '',
    this.quantity,
    this.amountCedis,
    this.site = '',
    this.group = '',
  });

  final String name;
  final double? quantity;
  final double? amountCedis;

  /// Site id when the photo names a yard. Empty means the whole farm.
  final String site;

  /// Energy source, Forage, Additives, Cerelac, or Other. Empty if unread.
  final String group;
}

/// Fields read from receipt photos, for the person to check.
class ReceiptDraft {
  const ReceiptDraft({
    this.supplier = '',
    this.amountCedis,
    this.note = '',
    this.category = '',
    this.items = const [],
  });

  final String supplier;
  final double? amountCedis;
  final String note;

  /// `feed` or `other` when the photos are a shop receipt.
  final String category;
  final List<ReceiptItem> items;

  bool get isEmpty =>
      supplier.trim().isEmpty &&
      (amountCedis == null || amountCedis! <= 0) &&
      items.isEmpty;
}

/// Pulls a JSON object out of a vision-model reply.
ReceiptDraft? parseReceiptText(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) {
      return null;
    }
    final supplier = decoded['supplier'];
    final note = decoded['note'] ?? decoded['items'];
    final amount = decoded['amount'] ?? decoded['amountCedis'];
    final category = decoded['category'];
    return ReceiptDraft(
      supplier: supplier is String ? supplier.trim() : '',
      amountCedis: _receiptNumber(amount),
      note: note is String ? note.trim() : '',
      category: category is String ? category.trim().toLowerCase() : '',
      items: _receiptItems(decoded['items']),
    );
  } on FormatException {
    return null;
  }
}

List<ReceiptItem> _receiptItems(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final items = <ReceiptItem>[];
  for (final row in raw) {
    if (row is! Map) {
      continue;
    }
    final name = row['name'];
    final site = row['site'];
    final group = row['group'];
    items.add(
      ReceiptItem(
        name: name is String ? name.trim() : '',
        quantity: _receiptNumber(row['quantity'] ?? row['kilos'] ?? row['kg']),
        amountCedis: _receiptNumber(row['amount'] ?? row['amountCedis']),
        site: site is String ? site.trim() : '',
        group: group is String ? normalizeResourceCategory(group) : '',
      ),
    );
  }
  return items;
}

double? _receiptNumber(Object? amount) {
  if (amount is num) {
    return amount.toDouble();
  }
  if (amount is String) {
    return double.tryParse(amount.replaceAll(RegExp(r'[^0-9.]'), ''));
  }
  return null;
}
