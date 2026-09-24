# Player logos

Monochrome logos DeskTune draws as translucent glass glyphs for popular players.
Any player without a file here just shows the icon Android provides.

| File | Player | Package | Source |
| --- | --- | --- | --- |
| `amazon-music.svg` | Amazon Music | `com.amazon.mp3` | SVG Repo, icon 514597 ("amazon-music") |
| `spotify.svg` | Spotify | `com.spotify.music` | Simple Icons (CC0) |
| `youtube-music.svg` | YouTube Music | `com.google.android.apps.youtube.music` | Simple Icons (CC0) |

To add a player: put its SVG in this folder and add its package name to
`PlayerGlyphs` in `lib/features/desk_mode/widgets/player_glyphs.dart`.

The logos are trademarks of their owners and are used only to identify the app
that is playing. Check the licence of any icon you add; the SVG Repo licence for
`amazon-music.svg` was not verified.
