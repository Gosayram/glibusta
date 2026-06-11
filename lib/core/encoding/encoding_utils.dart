import 'dart:convert';
import 'dart:typed_data';

/// BOM detection, UTF-16 decode, encoding name normalization.
bool startsWith(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String decodeUtf16Le(Uint8List bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

String decodeUtf16Be(Uint8List bytes) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add((bytes[i] << 8) | bytes[i + 1]);
  }
  return String.fromCharCodes(units);
}

/// Try to extract declared encoding from XML declaration or HTML meta charset.
String? detectDeclaredEncoding(Uint8List bytes) {
  final sampleLength = bytes.length < 4096 ? bytes.length : 4096;
  final sample = latin1.decode(bytes.sublist(0, sampleLength));

  // XML: <?xml version="1.0" encoding="windows-1251"?>
  final xml = RegExp(
    r'''<\?xml[^>]+encoding\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(sample);
  if (xml != null) {
    return normalizeEncodingName(xml.group(1)!);
  }

  // HTML: <meta charset="windows-1251">
  // or: <meta http-equiv="Content-Type" content="text/html; charset=windows-1251">
  final htmlMeta = RegExp(
    r'''charset\s*=\s*["']?([a-zA-Z0-9_\-]+)''',
    caseSensitive: false,
  ).firstMatch(sample);
  if (htmlMeta != null) {
    return normalizeEncodingName(htmlMeta.group(1)!);
  }

  return null;
}

String normalizeEncodingName(String value) {
  final v = value.trim().toLowerCase().replaceAll('_', '-');
  return switch (v) {
    'utf8' => 'utf-8',
    'utf-16' => 'utf-16le',
    'utf16' => 'utf-16le',
    'utf-16-le' => 'utf-16le',
    'utf-16-be' => 'utf-16be',
    'windows-1251' || 'cp1251' || 'win1251' => 'windows-1251',
    'cp866' || 'ibm866' || '866' => 'ibm866',
    'koi8r' || 'koi8-r' => 'koi8-r',
    'iso8859-5' || 'iso-8859-5' => 'iso-8859-5',
    'latin1' || 'iso-8859-1' => 'iso-8859-1',
    _ => v,
  };
}
