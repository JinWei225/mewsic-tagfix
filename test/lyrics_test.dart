import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mewsic_tagfix/mewsic_tagfix.dart';
import 'package:test/test.dart';

import 'tag_writer_test.dart'
    show binaryAtom, buildM4a, buildMp3, id3Frame, latin1Text, textAtom;

/// A `USLT` frame: encoding, language, content descriptor, then the lyrics.
Uint8List uslt(String lyrics, {int encoding = 3, String descriptor = ''}) {
  if (encoding == 1) {
    List<int> utf16(String s) => [
      0xff, 0xfe, // little-endian BOM
      for (final unit in s.codeUnits) ...[unit & 0xff, unit >> 8],
    ];
    return Uint8List.fromList([
      1,
      ...ascii.encode('kor'),
      ...utf16(descriptor),
      0,
      0,
      ...utf16(lyrics),
    ]);
  }
  return Uint8List.fromList([
    encoding,
    ...ascii.encode('eng'),
    ...utf8.encode(descriptor),
    0,
    ...utf8.encode(lyrics),
  ]);
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lyrics');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<File> write(String name, Uint8List bytes) async {
    final f = File('${tmp.path}${Platform.pathSeparator}$name');
    await f.writeAsBytes(bytes);
    return f;
  }

  group('m4a', () {
    test('reads the ©lyr atom', () async {
      final f = await write(
        'lyrics.m4a',
        buildM4a([
          textAtom('©nam', 'ABCD'),
          textAtom('©lyr', 'First line\nSecond line\n'),
        ]).bytes,
      );

      expect(await TagReader.readLyrics(f), 'First line\nSecond line');
    });

    test('keeps non-Latin text intact', () async {
      final f = await write(
        'hangul.m4a',
        buildM4a([textAtom('©lyr', '나는 나비\n날아올라')]).bytes,
      );

      expect(await Mp4TagParser.readLyrics(f), '나는 나비\n날아올라');
    });

    test('returns null without a ©lyr atom', () async {
      final f = await write(
        'none.m4a',
        buildM4a([
          textAtom('©nam', 'Heaven'),
          binaryAtom('covr', 13, [0xff, 0xd8, 0xff, 0xd9]),
        ]).bytes,
      );

      expect(await TagReader.readLyrics(f), isNull);
    });

    test('ignores a blank ©lyr atom', () async {
      final f = await write(
        'blank.m4a',
        buildM4a([textAtom('©lyr', '  \n ')]).bytes,
      );

      expect(await TagReader.readLyrics(f), isNull);
    });

    test('artwork still reads beside lyrics', () async {
      final jpeg = [0xff, 0xd8, 0xff, 0xe0, 1, 2, 0xff, 0xd9];
      final f = await write(
        'both.m4a',
        buildM4a([textAtom('©lyr', 'La la la'), binaryAtom('covr', 13, jpeg)])
            .bytes,
      );

      expect(await TagReader.readArtwork(f), equals(jpeg));
      expect(await TagReader.readLyrics(f), 'La la la');
    });
  });

  group('mp3', () {
    test('reads a UTF-8 USLT frame', () async {
      final f = await write(
        'utf8.mp3',
        buildMp3(4, [
          id3Frame(4, 'TIT2', latin1Text('Magic')),
          id3Frame(4, 'USLT', uslt('One\nTwo', descriptor: 'desc')),
        ]),
      );

      expect(await TagReader.readLyrics(f), 'One\nTwo');
    });

    test('reads a UTF-16 USLT frame', () async {
      final f = await write(
        'utf16.mp3',
        buildMp3(3, [
          id3Frame(3, 'USLT', uslt('하늘\nsky', encoding: 1, descriptor: 'x')),
        ]),
      );

      expect(await Mp3TagParser.readLyrics(f), '하늘\nsky');
    });

    test('returns null without a USLT frame', () async {
      final f = await write(
        'none.mp3',
        buildMp3(3, [id3Frame(3, 'TIT2', latin1Text('Air'))]),
      );

      expect(await TagReader.readLyrics(f), isNull);
    });
  });

  test('other formats have no lyrics to read', () async {
    final f = await write('song.flac', Uint8List.fromList([1, 2, 3]));
    expect(await TagReader.readLyrics(f), isNull);
  });
}
