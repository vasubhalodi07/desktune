import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/app_settings.dart';
import '../../services/media_controller_service.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsService settingsService;
  final MediaControllerService mediaService;

  const SettingsScreen({
    super.key,
    required this.settingsService,
    required this.mediaService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeskTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.chevron_left,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: settingsService.settings,
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              _buildSectionHeader('CLOCK DISPLAY'),
              _buildGlassSection([
                _buildCupertinoRow(
                  icon: CupertinoIcons.clock,
                  title: 'Follow Phone Time Format',
                  value: settings.followSystemTimeFormat,
                  onChanged: (val) => settingsService.updateSettings(
                    settings.copyWith(followSystemTimeFormat: val),
                  ),
                  showDivider: true,
                ),
                // Only needed when not following the phone's own setting.
                if (!settings.followSystemTimeFormat)
                  _buildCupertinoRow(
                    icon: CupertinoIcons.textformat_123,
                    title: '24-Hour Time',
                    value: settings.is24HourFormat,
                    onChanged: (val) => settingsService.updateSettings(
                      settings.copyWith(is24HourFormat: val),
                    ),
                    showDivider: true,
                  ),
                _buildCupertinoRow(
                  icon: CupertinoIcons.stopwatch,
                  title: 'Show Seconds',
                  value: settings.showSeconds,
                  onChanged: (val) => settingsService.updateSettings(
                    settings.copyWith(showSeconds: val),
                  ),
                  showDivider: true,
                ),
                _buildCupertinoRow(
                  icon: CupertinoIcons.calendar,
                  title: 'Show Date',
                  value: settings.showDate,
                  onChanged: (val) => settingsService.updateSettings(
                    settings.copyWith(showDate: val),
                  ),
                  showDivider: false,
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionHeader('SYSTEM & PERMISSIONS'),
              _buildGlassSection([
                GestureDetector(
                  onTap: () => mediaService.openNotificationSettings(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.slider_horizontal_3,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Android Media Access',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 36),

              Center(
                child: Text(
                  'DeskTune • StandBy Mode\nControls auto-hide after 5 seconds of inactivity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.35),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGlassSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildCupertinoRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool showDivider,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: CupertinoColors.activeGreen,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
      ],
    );
  }
}
