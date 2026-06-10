import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/reading_goal_repository.dart';

final readingGoalRepositoryProvider = FutureProvider<ReadingGoalRepository>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ReadingGoalRepository(prefs);
});

final readingGoalProvider = FutureProvider<ReadingGoal>((ref) async {
  final repo = await ref.watch(readingGoalRepositoryProvider.future);
  return repo.getGoal();
});
