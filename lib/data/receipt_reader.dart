import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shai_hills_farm/domain/receipt_draft.dart';

/// Reads a receipt photo when a Gemini key is configured.
class ReceiptReader {
  const ReceiptReader(this.apiKey);

  final String apiKey;

  Future<ReceiptDraft?> read(Uint8List bytes) {
    return readAll([bytes]);
  }

  /// Reads every page of one shop receipt. Photos are not stored.
  Future<ReceiptDraft?> readAll(List<Uint8List> photos) async {
    final key = apiKey.trim();
    final images = [
      for (final bytes in photos)
        if (bytes.isNotEmpty) bytes,
    ];
    if (key.isEmpty || images.isEmpty) {
      return null;
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$key',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': 'These photos are pages of one farm receipt from Ghana. Reply with JSON only, no markdown: {"supplier":"","category":"feed","items":[{"name":"","quantity":0,"amount":0,"site":"all","group":"Other"}]}. category is feed when the lines are animal feed, including premix and Cerelac, otherwise other. group is the closest of Energy source, Forage, Additives, Cerelac, or Other. Use Other only when you cannot tell which group a feed line belongs to. quantity is kilos for feed and a count for other goods. amount is the cedis for that line, not a guess. site is piggery, cattle_poultry, or all when the line is for the whole farm. Leave a field empty if you cannot read it.',
                  },
                  for (final bytes in images)
                    {
                      'inlineData': {
                        'mimeType': 'image/jpeg',
                        'data': base64Encode(bytes),
                      },
                    },
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return null;
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }
    final content = candidates.first;
    if (content is! Map) {
      return null;
    }
    final parts = content['content'];
    if (parts is! Map ||
        parts['parts'] is! List ||
        (parts['parts'] as List).isEmpty) {
      return null;
    }
    final text = [
      for (final part in parts['parts'] as List)
        if (part is Map && part['text'] is String) part['text'] as String,
    ].join('\n');
    if (text.trim().isEmpty) {
      return null;
    }
    return parseReceiptText(text);
  }
}
