import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../models/app_settings.dart';
import '../../models/media_info.dart';
import '../../services/artwork_palette_extractor.dart';
import '../../services/battery_service.dart';
import '../../services/clock_service.dart';
import '../../services/media_controller_service.dart';
import '../../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'widgets/burn_in_shift.dart';
import 'widgets/clock_view.dart';
import 'widgets/desk_layout.dart';
import 'widgets/ios_control_slider.dart';
import 'widgets/liquid_glass_card.dart';
import 'widgets/music_artwork.dart';
import 'widgets/music_controls.dart';
import 'widgets/music_info.dart';
import 'widgets/player_app_icon.dart';
import 'widgets/progress_slider.dart';

enum DeskViewMode { dual, fullClock, fullMusic }

class DeskModeScreen extends StatefulWidget {
  final ClockService clockService;
  final MediaControllerService mediaService;
  final SettingsService settingsService;
  final BatteryService? batteryService;

  const DeskModeScreen({
    super.key,
    required this.clockService,
    required this.mediaService,
    required this.settingsService,
    this.batteryService,
  });

  @override
  State<DeskModeScreen> createState() => _DeskModeScreenState();
}

class _DeskModeScreenState extends State<DeskModeScreen>
    with WidgetsBindingObserver {
  DeskViewMode _viewMode = DeskViewMode.dual;
  DeskViewMode _previousViewMode = DeskViewMode.dual;
  bool _showControls = true;
  Timer? _inactivityTimer;
  Color? _artworkAccentColor;
  List<Color>? _artworkColors;
  int? _lastArtworkHash;
  late final BatteryService _batteryService;
  bool _ownsBatteryService = false;

  void _setViewMode(DeskViewMode mode) {
    if (_viewMode == mode) return;
    setState(() {
      _previousViewMode = _viewMode;
      _viewMode = mode;
      if (mode == DeskViewMode.fullClock) {
        _showControls = true;
        _startReturnHintTimer();
      } else if (mode == DeskViewMode.dual) {
        _showControls = true;
        _inactivityTimer?.cancel();
      }
    });
    _syncClockResolution();
  }

  /// Seconds only appear on the full-screen clock, so that is the only time the
  /// clock needs to tick every second; otherwise it ticks once a minute.
  void _syncClockResolution() {
    widget.clockService.showSeconds =
        _viewMode == DeskViewMode.fullClock &&
        widget.settingsService.settings.value.showSeconds;
  }

  void _onMediaInfoChanged() {
    _updateArtworkAccentColor(widget.mediaService.mediaInfo.value.artworkBytes);
  }

  void _updateArtworkAccentColor(Uint8List? artworkBytes) {
    if (artworkBytes == null || artworkBytes.isEmpty) {
      if (_artworkAccentColor != null || _artworkColors != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _artworkAccentColor = null;
              _artworkColors = null;
              _lastArtworkHash = null;
            });
          }
        });
      }
      return;
    }

    final hash = Object.hash(
      artworkBytes.length,
      artworkBytes.first,
      artworkBytes.last,
      artworkBytes[artworkBytes.length ~/ 2],
    );
    if (hash == _lastArtworkHash) return;
    _lastArtworkHash = hash;

    ArtworkPaletteExtractor.extract(artworkBytes)
        .then((palette) {
          if (mounted) {
            setState(() {
              _artworkAccentColor = palette.primary;
              _artworkColors = palette.allColors;
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.batteryService != null) {
      _batteryService = widget.batteryService!;
    } else {
      _batteryService = BatteryService();
      _ownsBatteryService = true;
      _batteryService.init();
    }

    // Track active album art for ambient glow
    widget.mediaService.mediaInfo.addListener(_onMediaInfoChanged);
    _updateArtworkAccentColor(widget.mediaService.mediaInfo.value.artworkBytes);

    // Immersive sticky full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Keep screen awake
    widget.mediaService.setKeepScreenOn(
      widget.settingsService.settings.value.keepScreenAwake,
    );

    widget.settingsService.settings.addListener(_syncClockResolution);
    _syncClockResolution();
    widget.clockService.start();
    _resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeBackgroundWork();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _pauseBackgroundWork();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Screen off or another app in front: stop the clock and the native event
  /// streams so nothing wakes the CPU for a UI nobody can see.
  void _pauseBackgroundWork() {
    _inactivityTimer?.cancel();
    widget.clockService.stop();
    widget.mediaService.pause();
    _batteryService.pause();
  }

  void _resumeBackgroundWork() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.clockService.start();
    widget.mediaService.resume();
    _batteryService.init();
    // The 12/24-hour setting may have changed while the app was away.
    widget.settingsService.refreshSystemTimeFormat();
    _resetInactivityTimer();
    // Retry once more to handle slow listener reconnections on MIUI
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.mediaService.refreshSessions();
    });
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!mounted) return;

    final settings = widget.settingsService.settings.value;
    if (!settings.autoHideControls) {
      if (!_showControls) {
        setState(() => _showControls = true);
      }
      return;
    }

    if (!_showControls) {
      setState(() => _showControls = true);
    }

    _inactivityTimer = Timer(
      Duration(seconds: settings.autoHideDelaySeconds),
      () {
        if (mounted) {
          setState(() => _showControls = false);
        }
      },
    );
  }

  void _onUserInteraction() {
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    if (_ownsBatteryService) {
      _batteryService.dispose();
    }
    widget.mediaService.mediaInfo.removeListener(_onMediaInfoChanged);
    widget.settingsService.settings.removeListener(_syncClockResolution);
    WidgetsBinding.instance.removeObserver(this);
    widget.clockService.stop();
    _inactivityTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DeskTheme.background,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _onUserInteraction(),
        onPointerMove: (_) => _onUserInteraction(),
        child: Stack(
          children: [
            // Main StandBy Stage. The clock ticks inside ClockView only, so a tick
            // never rebuilds the music card or sliders. Burn-in protection steps
            // the whole stage a few pixels each minute.
            BurnInShift(
              time: widget.clockService.currentTime,
              child: SymmetricSafeArea(
                child: ValueListenableBuilder<AppSettings>(
                  valueListenable: widget.settingsService.settings,
                  builder: (context, settings, _) {
                    return ValueListenableBuilder<MediaInfo>(
                      valueListenable: widget.mediaService.mediaInfo,
                      builder: (context, media, _) {
                        return ValueListenableBuilder<BatteryInfo>(
                          valueListenable: _batteryService.batteryInfo,
                          builder: (context, batteryInfo, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable:
                                  widget.settingsService.systemIs24Hour,
                              builder: (context, systemIs24Hour, _) {
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 380),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  layoutBuilder: _viewLayoutBuilder,
                                  transitionBuilder: _viewTransitionBuilder,
                                  child: _buildCurrentView(
                                    // Resolve "follow the phone" into a concrete
                                    // 12/24-hour choice for the clock.
                                    settings: settings.withSystemTimeFormat(
                                      systemIs24Hour: systemIs24Hour,
                                    ),
                                    media: media,
                                    batteryInfo: batteryInfo,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // OLED / Nightstand Display Brightness Dimmer Overlay
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: widget.mediaService.brightness,
                builder: (context, brightness, _) {
                  final dimOpacity = (1.0 - brightness).clamp(0.0, 0.88);
                  if (dimOpacity <= 0.01) return const SizedBox.shrink();
                  return IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: dimOpacity),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settingsService: widget.settingsService,
          mediaService: widget.mediaService,
        ),
      ),
    );
  }

  Widget _viewLayoutBuilder(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[...previousChildren, ?currentChild],
    );
  }

  /// Direction the incoming view slides in from when switching view modes.
  Offset _incomingSlideOffset() {
    if (_viewMode == DeskViewMode.fullClock) return const Offset(-0.04, 0.0);
    if (_viewMode == DeskViewMode.fullMusic) return const Offset(0.04, 0.0);
    if (_previousViewMode == DeskViewMode.fullClock) {
      return const Offset(0.04, 0.0);
    }
    if (_previousViewMode == DeskViewMode.fullMusic) {
      return const Offset(-0.04, 0.0);
    }
    return Offset.zero;
  }

  Widget _viewTransitionBuilder(Widget child, Animation<double> animation) {
    final isIncoming = child.key == ValueKey(_viewMode);

    if (isIncoming) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.22, 1.0, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: _incomingSlideOffset(),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    }

    // Outgoing child dissolves within the first 35% to prevent double-clock ghosting
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInCubic),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCurrentView({
    required AppSettings settings,
    required MediaInfo media,
    required BatteryInfo batteryInfo,
  }) {
    switch (_viewMode) {
      case DeskViewMode.fullClock:
        return _buildFullClockView(settings, batteryInfo);
      case DeskViewMode.fullMusic:
        return _buildFullMusicView(media);
      case DeskViewMode.dual:
        return _buildDualStandByView(settings, media, batteryInfo);
    }
  }

  // 1. Dual StandBy View: 50% Clock + 50% Liquid Glass Music Card
  Widget _buildDualStandByView(
    AppSettings settings,
    MediaInfo media,
    BatteryInfo batteryInfo,
  ) {
    final hasMusic = media.hasActiveSession && media.hasContent;

    // One balanced composition: the clock and the player are designed at a fixed
    // size and scaled together to fit any screen, so the space on the left and
    // right is always equal (see DeskSplitLayout).
    return DeskSplitLayout(
      key: const ValueKey(DeskViewMode.dual),
      // Clock half (Settings & Full Clock buttons are part of the clock view).
      left: FittedBox(
        fit: BoxFit.scaleDown,
        child: ClockView(
          time: widget.clockService.currentTime,
          settings: settings,
          batteryInfo: batteryInfo,
          isExpanded: false,
          onSettingsTap: _openSettings,
          onExpandTap: _openFullClock,
        ),
      ),
      // Player half: the glass card with the brightness / volume sliders below.
      right: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiquidGlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              accentColor: _artworkAccentColor,
              paletteColors: _artworkColors,
              showShadow: hasMusic,
              animate: media.isPlaying,
              child: hasMusic
                  ? _buildActiveCardContent(media, false)
                  : _buildEmptyCardContent(),
            ),
            // Breathing room between the player card and the sliders.
            const SizedBox(height: 22),
            _buildHorizontalSliders(height: 44.0),
          ],
        ),
      ),
    );
  }

  void _openFullClock() {
    _setViewMode(DeskViewMode.fullClock);
  }

  void _startReturnHintTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _viewMode == DeskViewMode.fullClock) {
        setState(() => _showControls = false);
      }
    });
  }

  void _returnToSplitStandby() {
    _setViewMode(DeskViewMode.dual);
  }

  // 2. Full Clock Mode (Edge-to-edge Apple StandBy giant digits centered perfectly)
  Widget _buildFullClockView(AppSettings settings, BatteryInfo batteryInfo) {
    return SizedBox.expand(
      key: const ValueKey(DeskViewMode.fullClock),
      child: Stack(
        children: [
          // Geometrically centered clock (horizontal & vertical)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DeskSplitLayout.marginFor(
                MediaQuery.sizeOf(context).width,
              ),
              vertical: 12,
            ),
            // Scales the clock to fit: larger on tablets, smaller on small phones.
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: ClockView(
                  time: widget.clockService.currentTime,
                  settings: settings,
                  batteryInfo: batteryInfo,
                  isExpanded: true,
                  showControls: _showControls,
                  onTap: _returnToSplitStandby,
                ),
              ),
            ),
          ),

          // Bottom subtle hint (fades out after 3.5s interval, lifted from edge)
          Positioned(
            bottom: 34,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Center(
                child: Text(
                  'TAP TO RETURN TO SPLIT STANDBY',
                  style: TextStyle(
                    fontFamily: 'Comfortaa',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.32),
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Full Music Mode (Expanded iOS Now Playing Stage)
  Widget _buildFullMusicView(MediaInfo media) {
    final hasMusic = media.hasActiveSession && media.hasContent;

    return Center(
      key: const ValueKey(DeskViewMode.fullMusic),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LiquidGlassCard(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 16,
                ),
                accentColor: _artworkAccentColor,
                paletteColors: _artworkColors,
                showShadow: hasMusic,
                animate: media.isPlaying,
                child: hasMusic
                    ? _buildActiveCardContent(media, true)
                    : _buildEmptyCardContent(),
              ),
              const SizedBox(height: 14),
              _buildHorizontalSliders(height: 46.0),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onTap: () => _setViewMode(DeskViewMode.dual),
                  child: Text(
                    'TAP TO RETURN TO SPLIT STANDBY',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.25),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardContent(MediaInfo media, bool isExpanded) {
    final artworkSize = isExpanded ? 90.0 : 68.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Artwork + Track info row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tapping the artwork jumps to the app that is playing.
            MusicArtwork(
              artworkBytes: media.artworkBytes,
              size: artworkSize,
              onTap: widget.mediaService.openPlayerApp,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MusicInfo(
                title: media.title,
                artist: media.artist,
                album: media.album,
                isExpanded: isExpanded,
                isPlaying: media.isPlaying,
                hasActiveSession: media.hasActiveSession,
                accentColor: _artworkAccentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Progress bar with timing
        ProgressSlider(
          media: media,
          onSeek: (pos) => widget.mediaService.seekTo(pos),
        ),
        const SizedBox(height: 6),

        // Playback controls (Liquid Glass controls), kept centred. The playing
        // app's icon uses the free space at the right end of the same row; the
        // matching empty space on the left keeps the controls exactly centred.
        Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            MusicControls(
              media: media,
              size: isExpanded ? 54 : 46,
              onPrevious: () => widget.mediaService.previous(),
              onTogglePlayPause: () => widget.mediaService.togglePlayPause(),
              onNext: () => widget.mediaService.next(),
            ),
            Expanded(
              child: media.packageName.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerRight,
                      child: PlayerAppIcon(
                        packageName: media.packageName,
                        appName: media.appName,
                        // Same size as the previous / next buttons beside it.
                        size: (isExpanded ? 54 : 46) * 0.84,
                        loadIcon: widget.mediaService.appIconFor,
                        onTap: widget.mediaService.openPlayerApp,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyCardContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
            child: Icon(
              CupertinoIcons.music_note,
              size: 28,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Music Playing',
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DeskTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Play something in any music app',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Comfortaa',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: DeskTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSliders({double height = 44.0}) {
    return Row(
      children: [
        Expanded(
          child: IosControlSlider(
            type: IosSliderType.brightness,
            orientation: Axis.horizontal,
            valueListenable: widget.mediaService.brightness,
            onChanged: (val) => widget.mediaService.setBrightness(val),
            height: height,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: IosControlSlider(
            type: IosSliderType.volume,
            orientation: Axis.horizontal,
            valueListenable: widget.mediaService.volumeRatio,
            onChanged: (val) => widget.mediaService.setVolume(val),
            height: height,
          ),
        ),
      ],
    );
  }
}
