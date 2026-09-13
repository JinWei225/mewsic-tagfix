# mewsic-tagfix

Completes the metadata of music files — built for the iTunes Store purchases
that arrive with names missing.

Some purchased `.m4a` files carry **no title, artist or album at all**: only
the store's catalogue IDs, a date and a copyright line. Others carry only the
sort-order atoms (`sonm`/`soar`/`soal`), which most players — Android's media
scanner among them — do not read. Apple's Music app shows all of these
correctly because it reads its own library database, not the file; every
other player shows *Unknown Artist*, and none of them show a cover, because
purchases don't embed one.

`mewsic-tagfix` writes what is missing *into the files*, so they are right in
every player and on every device you copy them to. It is a command-line tool
and a Dart library ([used by the Mewsic player](https://github.com/JinWei225/flutter-music-player)
for its own tag reading and its Edit Info sheet).

## What it fills, and from where

Files are only ever **completed, never changed**: a field that is present
stays exactly as it is. Sources, in order of trust:

1. **The file's own sort atoms** — a file with only `sonm`/`soar`/`soal` gets
   real `©nam`/`©ART`/`©alb` atoms with the same values.
2. **The iTunes Store**, looked up through the public catalogue API by the
   `plID`/`cnID`/`sfID` atoms every purchase carries (no account or key). It
   is the only source that knows a title's real punctuation (iTunes writes
   `Can’t` as `Can_t` on disk), each track's own artist credit, album artist,
   genre, disc number, release date — and the **album cover**, embedded at
   1200×1200 into any file lacking one.
3. **Album-mates** sharing the same store IDs, for artist, album, album
   artist and genre.
4. **The `Artist/Album/` folder layout** for artist and album.
5. **The filename** for the title and track number (`02 CAKE.m4a`).

Everything else in a file — artwork it already has, store IDs, lyrics, sort
names — is left untouched. Files are rewritten through a temporary file and
renamed over the original, so an interruption cannot damage a song. For
`.m4a`, iTunes' own padding after `moov` absorbs the change, so the audio
never moves and the file usually does not even change size; when there is no
padding, every chunk offset is adjusted. `.mp3` (ID3v2.3/2.4, plus the v1
trailer) is supported as well.

## Usage

```
mewsic-tagfix check [folder]   report what is missing and how it would be filled
mewsic-tagfix fix   [folder]   write the missing names into the files
mewsic-tagfix watch [folder]   keep running; fix new files as they arrive

  --dry-run   with fix/watch: report only, change nothing
  --quiet     with watch: log only when something is written
  --offline   do not ask the iTunes Store; use only what is on disk
```

`[folder]` defaults to the Apple Music library on macOS
(`~/Music/Music/Media.localized/Music`) and `~/Music` elsewhere. `check`
exits 1 when something would be changed, so it can gate a script.

`watch` handles each album folder as a unit ~15 s after files stop arriving
in it, so a fresh purchase is completed once its download has settled.

## Installing on macOS

Needs the [Dart SDK](https://dart.dev/get-dart) (a Flutter install includes
one). This builds a standalone binary into `~/.local/bin/mewsic-tagfix` and
registers a launch agent that runs `watch` at login:

```bash
./packaging/install_tagfix_macos.sh
```

The first run asks for **Media & Apple Music** access. Log:
`~/Library/Logs/mewsic-tagfix.log`. Remove with `--uninstall`.

macOS ties that permission to the binary's code signature, and an ad-hoc
signature changes with every build, so each reinstall would ask again. To
keep the grant across builds, create a local signing certificate once (it
asks for your login password to trust it); the install script then signs
with it automatically:

```bash
./packaging/signing_identity_macos.sh
```

Elsewhere, build it yourself: `dart compile exe bin/tagfix.dart -o mewsic-tagfix`.

## As a library

```yaml
dependencies:
  mewsic_tagfix:
    git:
      url: https://github.com/JinWei225/mewsic-tagfix.git
      ref: v1.0.0
```

```dart
import 'package:mewsic_tagfix/mewsic_tagfix.dart';

final tags = await TagReader.parse(File('song.m4a'));       // RawTags
final art  = await TagReader.readArtwork(File('song.m4a')); // Uint8List?
await TagWriter.write(File('song.m4a'), TagEdit(...));       // save tags
final repairs = await TagRepairer(catalogue: ItunesCatalogue()).planTree(dir);
```

`Mp4TagParser`, `Mp3TagParser`, `SiblingTags`, `StoreCatalogue` (with
`ItunesCatalogue`) and `TagRepairer` are the pieces underneath.

## Development

```bash
dart analyze
dart test
```

The suite builds its own MP4 and MP3 fixtures — including real `stco` chunk
tables to prove the audio stays findable — and fakes the store. One test
round-trips a genuine purchase from the Apple Music folder when there is one,
checking with `ffmpeg` (if installed) that the result still decodes.

## Limits

- Fill-only by design: a wrong value that is present is not corrected (the
  Mewsic app's Edit Info sheet is for that).
- A nameless track on a *Various Artists* album, or one that is really a
  collaboration, is credited correctly only when the store knows it;
  offline, it gets the album's most common artist.
- Old DRM `.m4p` purchases, `.aac`, FLAC and WAV are not handled.
