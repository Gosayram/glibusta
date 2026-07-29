import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reading_trend.dart';

/// A local-only, explicit preference for showing reading-rhythm insights.
class ReadingTrendSettings {
  const ReadingTrendSettings({
    this.isEnabled = false,
    this.period = ReadingTrendPeriod.week,
  });

  final bool isEnabled;
  final ReadingTrendPeriod period;

  ReadingTrendSettings copyWith({
    bool? isEnabled,
    ReadingTrendPeriod? period,
  }) {
    return ReadingTrendSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      period: period ?? this.period,
    );
  }
}

final class ReadingTrendSettingsRepository {
  ReadingTrendSettingsRepository(this._preferences);

  static const _enabledKey = 'reading_trend_enabled';
  static const _periodKey = 'reading_trend_period';

  final SharedPreferences _preferences;

  ReadingTrendSettings load() {
    final periodName = _preferences.getString(_periodKey);
    final period =
        ReadingTrendPeriod.values.where((value) => value.name == periodName).firstOrNull ??
        ReadingTrendPeriod.week;
    return ReadingTrendSettings(
      isEnabled: _preferences.getBool(_enabledKey) ?? false,
      period: period,
    );
  }

  Future<void> save(ReadingTrendSettings settings) async {
    await _preferences.setBool(_enabledKey, settings.isEnabled);
    await _preferences.setString(_periodKey, settings.period.name);
  }
}

final readingTrendSettingsProvider =
    AsyncNotifierProvider<ReadingTrendSettingsNotifier, ReadingTrendSettings>(
      ReadingTrendSettingsNotifier.new,
    );

final class ReadingTrendSettingsNotifier extends AsyncNotifier<ReadingTrendSettings> {
  late final ReadingTrendSettingsRepository _repository;

  @override
  Future<ReadingTrendSettings> build() async {
    _repository = ReadingTrendSettingsRepository(await SharedPreferences.getInstance());
    return _repository.load();
  }

  Future<void> saveSettings(ReadingTrendSettings settings) async {
    final previous = state.asData?.value;
    state = AsyncData(settings);
    try {
      await _repository.save(settings);
    } on Object catch (error, stackTrace) {
      state = previous == null ? AsyncError(error, stackTrace) : AsyncData(previous);
    }
  }
}
