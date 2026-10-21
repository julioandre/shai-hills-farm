/// Supabase client settings read from `--dart-define` or
/// `--dart-define-from-file`.
///
/// Both values empty means the on-device mock. Neither value is invented
/// or stored in the repo.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.geminiApiKey = '',
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Optional. When set, a receipt photo is read before the person confirms it.
  final String geminiApiKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Set when only one of the two defines is present.
  String? get partialSupabaseNotice {
    final urlSet = supabaseUrl.isNotEmpty;
    final keySet = supabaseAnonKey.isNotEmpty;
    if (urlSet == keySet) {
      return null;
    }
    return 'Set both SUPABASE_URL and SUPABASE_ANON_KEY. '
        'This session is using on-device records.';
  }

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    const gemini = String.fromEnvironment('GEMINI_API_KEY');
    return AppConfig(
      supabaseUrl: url.trim(),
      supabaseAnonKey: key.trim(),
      geminiApiKey: gemini.trim(),
    );
  }
}
