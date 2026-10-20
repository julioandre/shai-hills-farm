/// The signed-in farm account.
class FarmSession {
  const FarmSession({required this.userId, required this.email});

  final String userId;
  final String email;
}
