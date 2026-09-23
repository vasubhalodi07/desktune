class AppSettings {
  final bool is24HourFormat;
  final bool showSeconds;
  final bool showDate;
  final bool autoHideControls;
  final int autoHideDelaySeconds;
  final bool keepScreenAwake;

  const AppSettings({
    this.is24HourFormat = false,
    this.showSeconds = false,
    this.showDate = true,
    this.autoHideControls = true,
    this.autoHideDelaySeconds = 5,
    this.keepScreenAwake = true,
  });

  AppSettings copyWith({
    bool? is24HourFormat,
    bool? showSeconds,
    bool? showDate,
    bool? autoHideControls,
    int? autoHideDelaySeconds,
    bool? keepScreenAwake,
  }) {
    return AppSettings(
      is24HourFormat: is24HourFormat ?? this.is24HourFormat,
      showSeconds: showSeconds ?? this.showSeconds,
      showDate: showDate ?? this.showDate,
      autoHideControls: autoHideControls ?? this.autoHideControls,
      autoHideDelaySeconds: autoHideDelaySeconds ?? this.autoHideDelaySeconds,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is24HourFormat': is24HourFormat,
      'showSeconds': showSeconds,
      'showDate': showDate,
      'autoHideControls': autoHideControls,
      'autoHideDelaySeconds': autoHideDelaySeconds,
      'keepScreenAwake': keepScreenAwake,
    };
  }

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      is24HourFormat: map['is24HourFormat'] as bool? ?? false,
      showSeconds: map['showSeconds'] as bool? ?? false,
      showDate: map['showDate'] as bool? ?? true,
      autoHideControls: map['autoHideControls'] as bool? ?? true,
      autoHideDelaySeconds: map['autoHideDelaySeconds'] as int? ?? 5,
      keepScreenAwake: map['keepScreenAwake'] as bool? ?? true,
    );
  }
}
