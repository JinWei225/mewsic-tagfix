import 'dart:io';
import 'dart:typed_data';

import 'mp3_tags.dart';
import 'mp4_tags.dart';
import 'raw_tags.dart';

/// Reads a file's tags with the right parser for its format, plus the
/// filename and folder fallbacks a player can use when a file is untagged.
class TagReader {
  /// Extensions we attempt to read and play.
  static const supportedExtensions = {'.m4a', '.mp4', '.m4b', '.mp3', '.aac'};

  static bool isSupported(String path) =>
      supportedExtensions.contains(_extension(path));

  /// Reads whatever tags [file] carries. Never null: a malformed or untagged
  /// file yields an empty [RawTags] so the caller's fallbacks apply.
  static Future<RawTags> parse(File file) async {
    RawTags? tags;
    try {
      switch (_extension(file.path)) {
        case '.m4a':
        case '.mp4':
        case '.m4b':
          tags = await Mp4TagParser.parse(file);
          break;
        case '.mp3':
        case '.aac':
          tags = await Mp3TagParser.parse(file);
          break;
      }
    } catch (_) {
      // A malformed file should drop to filename fallbacks, not sink the scan.
      tags = null;
    }
    return tags ?? RawTags();
  }

  /// The embedded cover of [file], or null when it has none or the format
  /// is not one we read.
  static Future<Uint8List?> readArtwork(File file) async {
    try {
      switch (_extension(file.path)) {
        case '.m4a':
        case '.mp4':
        case '.m4b':
          return await Mp4TagParser.readArtwork(file);
        case '.mp3':
          return await Mp3TagParser.readArtwork(file);
      }
    } catch (_) {
      // Malformed art is no reason to fail the row that shows it.
    }
    return null;
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot).toLowerCase();
  }

  /// Recovers a track number from a "04 Magic.m4a" style filename.
  ///
  /// Only a fallback: some store downloads carry no `trkn` atom at all, and
  /// without this their album would list in alphabetical order instead of the
  /// running order the numbers in the filenames imply.
  static int? trackNumberFromFileName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final match = RegExp(r'^\s*(\d{1,3})\s*[-._ ]').firstMatch(name);
    if (match == null) return null;
    final value = int.tryParse(match.group(1)!);
    return (value == null || value == 0) ? null : value;
  }

  /// Recovers artist and album from an `<Artist>/<Album>/<file>` layout.
  ///
  /// Only a fallback, and a last-resort one: some iTunes Store purchases
  /// arrive with *no* title, artist or album atoms at all -- just the store's
  /// numeric IDs -- and Apple's own Music app only shows them correctly
  /// because it reads its library database rather than the file. The folder
  /// layout it writes is the one place the names survive on disk.
  ///
  /// Requires the file to sit at least two folders below [root], so a loose
  /// `~/Music/song.mp3` never reports "Music" as its album and the home
  /// folder as its artist.
  static ({String artist, String album})? folderTagsFromPath(
    String path,
    Directory root,
  ) {
    final sep = Platform.pathSeparator;
    final rootPath = root.path.endsWith(sep) ? root.path : '${root.path}$sep';
    if (!path.startsWith(rootPath)) return null;

    final parts = path.substring(rootPath.length).split(sep);
    // Artist, album, file -- anything shallower is not a library layout.
    if (parts.length < 3) return null;
    final album = parts[parts.length - 2].trim();
    final artist = parts[parts.length - 3].trim();
    if (album.isEmpty || artist.isEmpty) return null;
    return (artist: artist, album: album);
  }

  /// Strips the extension and any leading track number ("04 Magic" -> "Magic").
  static String titleFromFileName(String path) {
    var name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot > 0) name = name.substring(0, dot);
    name = name.replaceFirst(RegExp(r'^\s*\d{1,3}\s*[-._ ]\s*'), '');
    return name.trim().isEmpty ? 'Unknown Title' : name.trim();
  }
}
