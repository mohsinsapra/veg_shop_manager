import 'package:hive/hive.dart';

part 'user_role.g.dart';

@HiveType(typeId: 1)
enum UserRole {
  @HiveField(0)
  shop,
  @HiveField(1)
  admin,
}