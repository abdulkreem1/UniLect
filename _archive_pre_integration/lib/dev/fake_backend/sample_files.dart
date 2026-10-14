import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// Generates small but valid sample files for the dev fake backend so the
/// secure viewer can be exercised without any bundled documents.
abstract final class SampleFiles {
  /// A multi-page PDF using the built-in Helvetica font (ASCII text only).
  static Uint8List pdf({required String title, int pages = 3}) {
    final objects = <String>[];
    final pageIds = <int>[];
    // 1: catalog, 2: pages, 3: font, then page/content pairs.
    const fontId = 3;
    var nextId = 4;
    final pageObjects = <int, String>{};
    for (var i = 1; i <= pages; i++) {
      final pageId = nextId++;
      final contentId = nextId++;
      pageIds.add(pageId);
      final lines = [
        _text(56, 760, 26, 'UniLect'),
        _text(56, 720, 16, _ascii(title)),
        _text(56, 690, 11, 'Sample document served by the DEV fake backend.'),
        _text(56, 672, 11, 'Replace with real content once the API is live.'),
        for (var l = 0; l < 22; l++)
          _text(
            56,
            630 - l * 22,
            11,
            'Page $i  -  line ${l + 1}: lorem ipsum dolor sit amet.',
          ),
        _text(280, 40, 10, '$i / $pages'),
      ].join('\n');
      final stream = 'BT\n$lines\nET';
      pageObjects[pageId] =
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Resources << /Font << /F1 $fontId 0 R >> >> /Contents $contentId 0 R >>';
      pageObjects[contentId] =
          '<< /Length ${stream.length} >>\nstream\n$stream\nendstream';
    }
    objects
      ..add('<< /Type /Catalog /Pages 2 0 R >>')
      ..add(
        '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
        '/Count $pages >>',
      )
      ..add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    for (var id = 4; id < nextId; id++) {
      objects.add(pageObjects[id]!);
    }

    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = out.length;
    out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    out.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n'
      'startxref\n$xref\n%%EOF\n',
    );
    return Uint8List.fromList(latin1.encode(out.toString()));
  }

  /// A gradient PNG (brand colors) used as an "image" exam sample.
  static Uint8List png({int width = 480, int height = 640}) {
    final raw = BytesBuilder();
    for (var y = 0; y < height; y++) {
      raw.addByte(0); // filter: none
      final t = y / height;
      for (var x = 0; x < width; x++) {
        final stripe = ((x ~/ 40) + (y ~/ 40)).isEven ? 0 : 10;
        raw
          ..addByte((4 + 30 * t).round() + stripe)
          ..addByte((40 + 140 * t).round() + stripe)
          ..addByte((120 + 120 * t).round().clamp(0, 245) + stripe);
      }
    }
    final ihdr = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2) // color type RGB
      ..setUint8(10, 0)
      ..setUint8(11, 0)
      ..setUint8(12, 0);
    final png = BytesBuilder()
      ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
      ..add(_chunk('IHDR', ihdr.buffer.asUint8List()))
      ..add(_chunk('IDAT', ZLibCodec().encode(raw.toBytes())))
      ..add(_chunk('IEND', const []));
    return png.toBytes();
  }

  static String _text(int x, int y, int size, String s) =>
      '/F1 $size Tf 1 0 0 1 $x $y Tm (${_escape(s)}) Tj';

  static String _escape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  static String _ascii(String s) =>
      String.fromCharCodes(s.runes.where((r) => r >= 32 && r < 127));

  static List<int> _chunk(String type, List<int> data) {
    final typeBytes = ascii.encode(type);
    final len = ByteData(4)..setUint32(0, data.length);
    final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
    return [
      ...len.buffer.asUint8List(),
      ...typeBytes,
      ...data,
      ...crc.buffer.asUint8List(),
    ];
  }

  static final List<int> _crcTable = List.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    return c;
  });

  static int _crc32(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = _crcTable[(c ^ b) & 0xFF] ^ (c >>> 8);
    }
    return c ^ 0xFFFFFFFF;
  }
}
