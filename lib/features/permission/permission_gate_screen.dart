import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/media_controller_service.dart';

class PermissionGateScreen extends StatefulWidget {
  final MediaControllerService mediaService;
  final VoidCallback onContinue;

  const PermissionGateScreen({
    super.key,
    required this.mediaService,
    required this.onContinue,
  });

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _restrictedLikely = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshRestrictedState();
  }

  Future<void> _refreshRestrictedState() async {
    final blocked = await widget.mediaService.isRestrictedSettingsLikely();
    if (mounted && blocked != _restrictedLikely) {
      setState(() => _restrictedLikely = blocked);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRestrictedState();
      widget.mediaService.checkPermission().then((granted) {
        if (granted && mounted) {
          // Re-init streams (safe to call multiple times)
          widget.mediaService.init().then((_) {
            if (mounted) widget.onContinue();

            // MIUI: NotificationListenerService takes 1-4s to connect after
            // permission grant — retry refreshSessions a few times with delays
            for (final delay in [1000, 2000, 4000]) {
              Future.delayed(Duration(milliseconds: delay), () {
                if (mounted) widget.mediaService.refreshSessions();
              });
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // DeskTune is landscape-only. The main flow sits on the left; when Android
    // is likely to lock Notification access, the unlock steps take the right.
    return Scaffold(
      backgroundColor: DeskTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildIntroAndActions(),
                        ),
                      ),
                    ),
                  ),
                  if (_restrictedLikely) ...[
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: SingleChildScrollView(
                          child: _RestrictedSettingsCard(
                            onOpenAppInfo: widget.mediaService.openAppInfo,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroAndActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DeskTheme.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 26,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Welcome to DeskTune',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: DeskTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'A desk clock and music controller for your phone. '
          'Allow media access to show what\'s playing and control playback.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: DeskTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: widget.mediaService.openNotificationSettings,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'Enable Media Access',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: widget.onContinue,
          child: const Text(
            'Preview Clock Mode Without Media',
            style: TextStyle(fontSize: 13, color: DeskTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Explains Android's "Restricted settings" lock, which greys out the
/// Notification access toggle for apps installed outside a store.
class _RestrictedSettingsCard extends StatelessWidget {
  final VoidCallback onOpenAppInfo;

  const _RestrictedSettingsCard({required this.onOpenAppInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DeskTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DeskTheme.warning.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: DeskTheme.warning,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notification access may be locked',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DeskTheme.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Android locks Notification access for apps installed from a file. '
            'If the switch is greyed out, unlock it once:',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: DeskTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          const _Step(number: '1', text: 'Tap "Open App Info" below'),
          const _Step(
            number: '2',
            text:
                'Turn on "Allow restricted settings" at the bottom of the page '
                '(on some phones: three-dot menu, top right)',
          ),
          const _Step(
            number: '3',
            text: 'Come back and tap "Enable Media Access"',
          ),
          const SizedBox(height: 6),
          const Text(
            'Not there yet? Tap "Enable Media Access" once and try the '
            'switch, then repeat step 1.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: DeskTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onOpenAppInfo,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text(
                'Open App Info',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: DeskTheme.warning,
                side: BorderSide(
                  color: DeskTheme.warning.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DeskTheme.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: DeskTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
