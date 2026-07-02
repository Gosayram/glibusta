import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/features/reader/data/parsers/smil_parser.dart';

void main() {
  group('SmilParser', () {
    test('parses basic SMIL with par/text/audio', () {
      final xml = '''
      <smil xmlns="http://www.w3.org/ns/SMIL">
        <body>
          <par id="par1">
            <text src="chapter.xhtml#p1"/>
            <audio src="audio/ch1.mp3" clipBegin="0s" clipEnd="5.2s"/>
          </par>
          <par id="par2">
            <text src="chapter.xhtml#p2"/>
            <audio src="audio/ch1.mp3" clipBegin="5.2s" clipEnd="10.8s"/>
          </par>
        </body>
      </smil>
      ''';

      final entries = SmilParser.parse(xml);
      expect(entries.length, 2);
      expect(entries[0].paragraphId, 'p1');
      expect(entries[0].audioSrc, 'audio/ch1.mp3');
      expect(entries[0].clipBegin, Duration.zero);
      expect(entries[0].clipEnd, const Duration(milliseconds: 5200));
      expect(entries[1].paragraphId, 'p2');
      expect(entries[1].clipBegin, const Duration(milliseconds: 5200));
      expect(entries[1].clipEnd, const Duration(milliseconds: 10800));
      expect(entries[1].duration, const Duration(milliseconds: 5600));
    });

    test('parses clock time format', () {
      final xml = '''
      <smil xmlns="http://www.w3.org/ns/SMIL">
        <body>
          <par>
            <text src="ch.xhtml#p1"/>
            <audio src="audio.mp3" clipBegin="00:01:30.5" clipEnd="00:02:15.750"/>
          </par>
        </body>
      </smil>
      ''';

      final entries = SmilParser.parse(xml);
      expect(entries.length, 1);
      expect(entries[0].clipBegin, const Duration(minutes: 1, seconds: 30, milliseconds: 500));
      expect(entries[0].clipEnd, const Duration(minutes: 2, seconds: 15, milliseconds: 750));
    });

    test('parses millisecond format', () {
      final xml = '''
      <smil xmlns="http://www.w3.org/ns/SMIL">
        <body>
          <par>
            <text src="ch.xhtml#p1"/>
            <audio src="audio.mp3" clipBegin="1500ms" clipEnd="3200ms"/>
          </par>
        </body>
      </smil>
      ''';

      final entries = SmilParser.parse(xml);
      expect(entries.length, 1);
      expect(entries[0].clipBegin, const Duration(milliseconds: 1500));
      expect(entries[0].clipEnd, const Duration(milliseconds: 3200));
    });

    test('returns empty for SMIL without par elements', () {
      final xml = '''
      <smil xmlns="http://www.w3.org/ns/SMIL">
        <body/>
      </smil>
      ''';
      expect(SmilParser.parse(xml), isEmpty);
    });

    test('extracts paragraph ID from text reference', () {
      final xml = '''
      <smil xmlns="http://www.w3.org/ns/SMIL">
        <body>
          <par>
            <text src="chapter.xhtml#paragraph_42"/>
            <audio src="audio.mp3" clipBegin="0s" clipEnd="3s"/>
          </par>
        </body>
      </smil>
      ''';

      final entries = SmilParser.parse(xml);
      expect(entries.length, 1);
      expect(entries[0].paragraphId, 'paragraph_42');
      expect(entries[0].textRef, 'chapter.xhtml#paragraph_42');
    });
  });
}
