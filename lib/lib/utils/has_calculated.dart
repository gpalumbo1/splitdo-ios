import 'package:shared_preferences/shared_preferences.dart';

Future<bool> getHasCalculatedOnce(String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('hasCalculatedOnce_$groupId') ?? false;
}

Future<void> setHasCalculatedOnce(String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('hasCalculatedOnce_$groupId', true);
}

