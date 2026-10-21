import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/role.dart';

/// The signed-in farm account. [phone] is the Ghana number, such as +233….
class FarmSession {
  const FarmSession({
    required this.userId,
    required this.phone,
    required this.role,
    this.herds = const {},
  });

  final String userId;
  final String phone;
  final FarmRole role;
  final Set<Species> herds;

  FarmAccess get access => FarmAccess(role, herds: herds);
}
