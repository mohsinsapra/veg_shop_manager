import 'package:hive/hive.dart';
import '../../data/models/missing_item.dart';
import '../constants/app_constants.dart';

class HiveBoxes {
  static Box<MissingItem> get missingItems => 
      Hive.box<MissingItem>(AppConstants.hiveBoxMissingItems);
  
  static Box<String> get auth => 
      Hive.box<String>(AppConstants.hiveBoxAuth);
}