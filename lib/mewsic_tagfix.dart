/// Reads, completes and writes the metadata of music files -- built for the
/// iTunes Store purchases that arrive with names missing.
///
/// Parsing: [Mp4TagParser] and [Mp3TagParser] read `.m4a`/`.mp4`/`.m4b` and
/// `.mp3` into a [RawTags]; [TagReader] picks the parser and adds filename
/// and folder fallbacks. Completing: [SiblingTags] fills a nameless track
/// from album-mates sharing its store IDs, [StoreCatalogue] asks the store
/// itself, and [TagRepairer] combines every source into a [TagRepair].
/// Writing: [TagWriter] saves a [TagEdit] back into the file.
library;

export 'src/mp3_tag_writer.dart';
export 'src/mp3_tags.dart';
export 'src/mp4_tag_writer.dart';
export 'src/mp4_tags.dart';
export 'src/raw_tags.dart';
export 'src/sibling_tags.dart';
export 'src/store_catalogue.dart';
export 'src/tag_edit.dart';
export 'src/tag_reader.dart';
export 'src/tag_repair.dart';
export 'src/tag_writer.dart';
