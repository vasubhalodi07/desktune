class AppSettings {
  /// Follow the phone's own 12/24-hour setting. When false, [is24HourFormat]
  /// decides.
  final bool followSystemTimeFormat;
  final bool is24HourFormat;
  final bool showSeconds;
  final bool showDate;
  final bool autoHideControls;
  final int autoHideDelaySeconds;
  final bool keepScreenAwake;

  const AppSettings({
    this.followSystemTimeFormat = true,
    this.is24HourFormat = false,
    this.showSeconds = false,
    this.showDate = true,
    this.autoHideControls = true,
    this.autoHideDelaySeconds = 5,
    this.keepScreenAwake = true,
  });

  AppSettings copyWith({
    bool? followSystemTimeFormat,
    bool? is24HourFormat,
    bool? showSeconds,
    bool? showDate,
    bool? autoHideControls,
    int? autoHideDelaySeconds,
    bool? keepScreenAwake,
  }) {
    return AppSettings(
      followSystemTimeFormat:
          followSystemTimeFormat ?? this.followSystemTimeFormat,
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
      'followSystemTimeFormat': followSystemTimeFormat,
      'is24HourFormat': is24HourFormat,
      'showSeconds': showSeconds,
      'showDate': showDate,
      'autoHideControls': autoHideControls,
      'autoHideDelaySeconds': autoHideDelaySeconds,
      'keepScreenAwake': keepScreenAwake,
    };
  }

  /// These settings with [is24HourFormat] resolved for display: the phone's own
  /// setting when [followSystemTimeFormat] is on, otherwise the user's choice.
  AppSettings withSystemTimeFormat({required bool systemIs24Hour}) =>
      followSystemTimeFormat ? copyWith(is24HourFormat: systemIs24Hour) : this;

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) {
    return AppSettings(
      followSystemTimeFormat: map['followSystemTimeFormat'] as bool? ?? true,
      is24HourFormat: map['is24HourFormat'] as bool? ?? false,
      showSeconds: map['showSeconds'] as bool? ?? false,
      showDate: map['showDate'] as bool? ?? true,
      autoHideControls: map['autoHideControls'] as bool? ?? true,
      autoHideDelaySeconds: map['autoHideDelaySeconds'] as int? ?? 5,
      keepScreenAwake: map['keepScreenAwake'] as bool? ?? true,
    );
  }
}
