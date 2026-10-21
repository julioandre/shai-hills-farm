/// Practice accounts so the farm can try sign-in without a new number.
const demoPhone = '+233244120008';
const demoOtp = '123456';
const demoUserId = '00000000-0000-4000-8000-000000000008';

/// Practice farm worker. Same code as the admin, and no access to money.
const workerPhone = '+233244120009';
const workerUserId = '00000000-0000-4000-8000-000000000009';

const phoneHint = '024 412 0008';

/// Ghana mobile number as +233 and 9 digits, or null when it is not one.
String? normalizePhone(String raw) {
  var text = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (text.startsWith('+')) {
    text = text.substring(1);
  }
  if (text.startsWith('233') && text.length == 12) {
    text = text.substring(3);
  } else if (text.startsWith('0') && text.length == 10) {
    text = text.substring(1);
  }
  if (!RegExp(r'^\d{9}$').hasMatch(text)) {
    return null;
  }
  return '+233$text';
}

String? validatePhone(String raw) {
  if (normalizePhone(raw) == null) {
    return 'Enter the phone number you use, like $phoneHint.';
  }
  return null;
}

/// Six digits from the text message.
String? validateOtp(String raw) {
  final code = raw.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    return 'Enter the 6-digit code from the text.';
  }
  return null;
}

String otpDigits(String raw) => raw.replaceAll(RegExp(r'\s'), '');

/// 024 412 0008. Leaves any other text as it was written.
String displayPhone(String phone) {
  final normalized = normalizePhone(phone);
  if (normalized == null) {
    return phone;
  }
  final national = '0${normalized.substring(4)}';
  return '${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
}
