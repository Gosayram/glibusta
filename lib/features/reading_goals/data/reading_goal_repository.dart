import 'package:shared_preferences/shared_preferences.dart';

class ReadingGoal {
  final int dailyMinutes;
  final bool isEnabled;

  const ReadingGoal({
    this.dailyMinutes = 30,
    this.isEnabled = false,
  });

  ReadingGoal copyWith({int? dailyMinutes, bool? isEnabled}) {
    return ReadingGoal(
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  String get displayText {
    final h = dailyMinutes ~/ 60;
    final m = dailyMinutes % 60;
    if (h == 0) return '$m мин в день';
    return m > 0 ? '$h ч $m мин в день' : '$h ч в день';
  }
}

class ReadingGoalRepository {
  ReadingGoalRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _dailyMinutesKey = 'reading_goal_daily_minutes';
  static const _enabledKey = 'reading_goal_enabled';

  ReadingGoal getGoal() {
    final minutes = _prefs.getInt(_dailyMinutesKey) ?? 30;
    final enabled = _prefs.getBool(_enabledKey) ?? false;
    return ReadingGoal(dailyMinutes: minutes, isEnabled: enabled);
  }

  Future<void> saveGoal(ReadingGoal goal) async {
    await _prefs.setInt(_dailyMinutesKey, goal.dailyMinutes);
    await _prefs.setBool(_enabledKey, goal.isEnabled);
  }

  int getTodayProgress(int todayMinutes) {
    final goal = getGoal();
    if (!goal.isEnabled || goal.dailyMinutes == 0) return 0;
    return ((todayMinutes / goal.dailyMinutes) * 100).clamp(0, 100).round();
  }

  bool isGoalMet(int todayMinutes) {
    final goal = getGoal();
    if (!goal.isEnabled) return false;
    return todayMinutes >= goal.dailyMinutes;
  }
}
