import 'package:hive/hive.dart';

part 'user_hive_model.g.dart';

@HiveType(typeId: 0)
class UserHiveModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String username;

  @HiveField(2)
  String passwordHash;

  @HiveField(3)
  String role;

  @HiveField(4)
  double sisaUangJalan;

  @HiveField(5)
  DateTime waktuDibuat;

  UserHiveModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.sisaUangJalan,
    required this.waktuDibuat,
  });
}
