/// What to show after a sign-in code is sent.
class SentCode {
  const SentCode({required this.message, this.previewCode});

  final String message;

  /// Set on this device when a text message cannot be delivered yet.
  final String? previewCode;
}
