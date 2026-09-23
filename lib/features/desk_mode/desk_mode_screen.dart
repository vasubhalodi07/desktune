import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme.dart';
import '../../models/app_settings.dart';
import '../../models/media_info.dart';
import '../../services/battery_service.dart';
import '../../services/clock_service.dart';
import '../../services/media_controller_service.dart';
import '../../services/settings_service.dart';
import '../settings/settings_screen.dart';
import 'widgets/clock_view.dart';
import 'widgets/ios_control_slider.dart';
import 'widgets/liquid_glass_card.dart';
import 'widgets/music_artwork.dart';
import 'widgets/music_controls.dart';
import 'widgets/music_info.dart';
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
  }

  void _onMediaInfoChanged() {
    _updateArtworkAccentColor(widget.mediaService.mediaInfo.value.artworkBytes);
  }

  void _updateArtworkAccentColor(Uint8List? artworkBytes) {
    if (artworkBytes == null || artworkBytes.isEmpty) {
      if (_artworkAccentColor != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _artworkAccentColor = null;
              _lastArtworkHash = null;
            });
          }
        });
      }
      return;
    }

    final hash = artworkBytes.hashCode;
    if (hash == _lastArtworkHash) return;
    _lastArtworkHash = hash;

    ColorScheme.fromImageProvider(
      provider: MemoryImage(artworkBytes),
      brightness: Brightness.dark,
    ).then((scheme) {
      if (mounted) {
        setState(() {
          _artworkAccentColor = scheme.primary;
        });
      }
    }).catchError((_) {});
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

    // Lock to landscape for Desk StandBy mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Immersive sticky full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Keep screen awake
    widget.mediaService.setKeepScreenOn(
      widget.settingsService.settings.value.keepScreenAwake,
    );

    widget.clockService.start();
    _resetInactivityTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.mediaService.refreshSessions();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _inactivityTimer?.cancel();
    SystemChrome.setPreferredOrientations([]);
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
            // Main StandBy Stage
            SafeArea(
              child: ValueListenableBuilder<AppSettings>(
                valueListenable: widget.settingsService.settings,
                builder: (context, settings, _) {
                  return ValueListenableBuilder<DateTime>(
                    valueListenable: widget.clockService.currentTime,
                    builder: (context, dateTime, _) {
                      return ValueListenableBuilder<MediaInfo>(
                        valueListenable: widget.mediaService.mediaInfo,
                        builder: (context, media, _) {
                          return ValueListenableBuilder<BatteryInfo>(
                            valueListenable: _batteryService.batteryInfo,
                            builder: (context, batteryInfo, _) {
                              return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 380),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  ...previousChildren,
                                  ?currentChild,
                                ],
                              );
                            },
                            transitionBuilder: (child, animation) {
                              final isIncoming = child.key == ValueKey(_viewMode);

                              if (isIncoming) {
                                final curved = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                );

                                final fadeAnim = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.22, 1.0, curve: Curves.easeOut),
                                );

                                Offset startOffset = Offset.zero;
                                if (_viewMode == DeskViewMode.fullClock) {
                                  // Entering full clock from split: subtle slide in from left
                                  startOffset = const Offset(-0.04, 0.0);
                                } else if (_viewMode == DeskViewMode.fullMusic) {
                                  // Entering full music from split: subtle slide in from right
                                  startOffset = const Offset(0.04, 0.0);
                                } else if (_previousViewMode == DeskViewMode.fullClock) {
                                  // Returning to split from full clock: subtle slide in from right
                                  startOffset = const Offset(0.04, 0.0);
                                } else if (_previousViewMode == DeskViewMode.fullMusic) {
                                  // Returning to split from full music: subtle slide in from left
                                  startOffset = const Offset(-0.04, 0.0);
                                }

                                final slideAnim = Tween<Offset>(
                                  begin: startOffset,
                                  end: Offset.zero,
                                ).animate(curved);

                                final scaleAnim = Tween<double>(
                                  begin: 0.94,
                                  end: 1.0,
                                ).animate(curved);

                                return FadeTransition(
                                  opacity: fadeAnim,
                                  child: SlideTransition(
                                    position: slideAnim,
                                    child: ScaleTransition(
                                      scale: scaleAnim,
                                      child: child,
                                    ),
                                  ),
                                );
                              } else {
                                // Outgoing child: cleanly dissolves within first 35% to prevent double-clock ghosting
                                final fadeAnim = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
                                );

                                final scaleAnim = Tween<double>(
                                  begin: 0.96,
                                  end: 1.0,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInCubic,
                                ));

                                return FadeTransition(
                                  opacity: fadeAnim,
                                  child: ScaleTransition(
                                    scale: scaleAnim,
                                    child: child,
                                  ),
                                );
                              }
                            },
                            child: _buildCurrentView(
                              dateTime: dateTime,
                              settings: settings,
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

  Widget _buildCurrentView({
    required DateTime dateTime,
    required AppSettings settings,
    required MediaInfo media,
    required BatteryInfo batteryInfo,
  }) {
    switch (_viewMode) {
      case DeskViewMode.fullClock:
        return _buildFullClockView(dateTime, settings, batteryInfo);
      case DeskViewMode.fullMusic:
        return _buildFullMusicView(media);
      case DeskViewMode.dual:
        return _buildDualStandByView(dateTime, settings, media, batteryInfo);
    }
  }

  // 1. Dual StandBy View: 50% Clock + 50% Liquid Glass Music Card
  Widget _buildDualStandByView(
    DateTime dateTime,
    AppSettings settings,
    MediaInfo media,
    BatteryInfo batteryInfo,
  ) {
    return Row(
      key: const ValueKey(DeskViewMode.dual),
      children: [
        // Left Half: StandBy Clock (Directly renders Settings & Full Clock icon buttons)
        Expanded(
          flex: 5,
          child: Center(
            child: ClockView(
              dateTime: dateTime,
              settings: settings,
              batteryInfo: batteryInfo,
              isExpanded: false,
              onSettingsTap: _openSettings,
              onExpandTap: _openFullClock,
            ),
          ),
        ),

        // Right Half: Liquid Glass Music Card
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, top: 14, bottom: 14),
            child: LiquidGlassCard(
              borderRadius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              accentColor: _artworkAccentColor,
              child: media.hasActiveSession && media.hasContent
                  ? _buildActiveCardContent(media, false)
                  : _buildEmptyCardContent(),
            ),
          ),
        ),
      ],
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
  Widget _buildFullClockView(DateTime dateTime, AppSettings settings, BatteryInfo batteryInfo) {
    return SizedBox.expand(
      key: const ValueKey(DeskViewMode.fullClock),
      child: Stack(
        children: [
          // Geometrically centered clock (horizontal & vertical)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: ClockView(
                dateTime: dateTime,
                settings: settings,
                batteryInfo: batteryInfo,
                isExpanded: true,
                showControls: _showControls,
                onTap: _returnToSplitStandby,
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
    return Center(
      key: const ValueKey(DeskViewMode.fullMusic),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiquidGlassCard(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                accentColor: _artworkAccentColor,
                child: media.hasActiveSession && media.hasContent
                    ? _buildActiveCardContent(media, true)
                    : _buildEmptyCardContent(),
              ),
              const SizedBox(height: 12),
              GestureDetector(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCardContent(MediaInfo media, bool isExpanded) {
    final artworkSize = isExpanded ? 90.0 : 68.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Music Artwork, Info, Seek Slider & Controls
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Artwork + Track info row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MusicArtwork(
                    artworkBytes: media.artworkBytes,
                    size: artworkSize,
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

              // Playback controls (iOS Cupertino icons)
              MusicControls(
                media: media,
                size: isExpanded ? 52 : 44,
                onPrevious: () => widget.mediaService.previous(),
                onTogglePlayPause: () => widget.mediaService.togglePlayPause(),
                onNext: () => widget.mediaService.next(),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: iOS Control Center Vertical Sliders (Brightness & Volume)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosControlSlider(
              type: IosSliderType.brightness,
              valueListenable: widget.mediaService.brightness,
              onChanged: (val) => widget.mediaService.setBrightness(val),
              width: 44.0,
              height: isExpanded ? 148.0 : 134.0,
            ),
            const SizedBox(width: 10),
            IosControlSlider(
              type: IosSliderType.volume,
              valueListenable: widget.mediaService.volumeRatio,
              onChanged: (val) => widget.mediaService.setVolume(val),
              width: 44.0,
              height: isExpanded ? 148.0 : 134.0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyCardContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: No Music placeholder
        Expanded(
          child: Center(
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
                  'Play audio in Amazon Music or Spotify',
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
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: iOS Control Center Sliders (Brightness & Volume)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosControlSlider(
              type: IosSliderType.brightness,
              valueListenable: widget.mediaService.brightness,
              onChanged: (val) => widget.mediaService.setBrightness(val),
              width: 44.0,
              height: 134.0,
            ),
            const SizedBox(width: 10),
            IosControlSlider(
              type: IosSliderType.volume,
              valueListenable: widget.mediaService.volumeRatio,
              onChanged: (val) => widget.mediaService.setVolume(val),
              width: 44.0,
              height: 134.0,
            ),
          ],
        ),
      ],
    );
  }
}
