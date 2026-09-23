import 'dart:io';

import 'package:fake_provider/generator.dart';
import 'package:fake_provider/profile.dart';
import 'package:fake_provider/xmltv.dart' show orphanXmltvId;
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/providers/provider_text.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';

void main() {
  group('normalizeChannelName', () {
    test('holds every example docs/02 rule 3 sets', () {
      const examples = {
        'UK: BBC One HD': 'bbc one',
        '|UK| Sky Sports Main Event FHD': 'sky sports main event',
        '[US] CNN': 'cnn',
        'ESPN 2 (Backup)': 'espn 2',
        'Film4 +1': 'film4 plus1',
        'TV 5 Monde': 'tv 5 monde',
        'Canal+ Sport': 'canal sport',
        'Télé-Québec': 'tele quebec',
        'Sky Sports News & Weather': 'sky sports news and weather',
        'AR | MBC 1 HEVC': 'mbc 1',
        '4K': '',
        '': '',
      };
      for (final MapEntry(key: name, value: key) in examples.entries) {
        expect(normalizeChannelName(name), key, reason: name);
      }
    });

    test('step 1: decodes entities, double-escaped ones too', () {
      expect(normalizeChannelName('Q&amp;A'), 'q and a');
      expect(normalizeChannelName('Children&#39;s'), 'children s');
      expect(normalizeChannelName('Nick&#x2019;s'), 'nick s');
      expect(normalizeChannelName('AT&amp;amp;T'), 'at and t');
      expect(normalizeChannelName('Nat&nbsp;Geo'), 'nat geo');
      // What `cleanText` would leave has to read the same as the raw text.
      const raw = '  UK:&amp;amp; Sky &#39;One&#39;\u00a0 HD ';
      expect(normalizeChannelName(cleanText(raw)!), normalizeChannelName(raw));
    });

    test('step 1: blank and whitespace-only are empty', () {
      for (final blank in ['', ' ', ' \t\n ', '\u00a0\u3000', '\ufffd']) {
        expect(normalizeChannelName(blank), '', reason: blank);
      }
    });

    test('step 2: folds case and Latin diacritics', () {
      const folds = {
        'ÉCOLE': 'ecole',
        'Müller': 'muller',
        'Straße': 'strasse',
        'Søren': 'soren',
        'Åse': 'ase',
        'Façade': 'facade',
        'España': 'espana',
        'Łódź': 'lodz',
        'Đoković': 'dokovic',
        'Œuvre': 'oeuvre',
        'Þór': 'thor',
        'Sjælland': 'sjaelland',
        'Știri Țara': 'stiri tara',
        'İstanbul': 'istanbul',
        // Decomposed: `e` then a combining acute accent.
        'Te\u0301le\u0301': 'tele',
        'ＢＢＣ\u3000Ｏｎｅ': 'bbc one',
      };
      for (final MapEntry(key: name, value: key) in folds.entries) {
        expect(normalizeChannelName(name), key, reason: name);
      }
    });

    test('step 2: reads superscript tags as words of their own', () {
      expect(normalizeChannelName('BBC One ᴴᴰ'), 'bbc one');
      expect(normalizeChannelName('BBC Oneᴴᴰ'), 'bbc one');
      expect(normalizeChannelName('Sky Cinema ᶠᴴᴰ'), 'sky cinema');
      expect(normalizeChannelName('Arena ⁴ᴷ'), 'arena');
      expect(normalizeChannelName('Arena ᴿᴬᵂ'), 'arena');
      expect(normalizeChannelName('Sky Sports¹'), 'sky sports 1');
    });

    test('step 3: strips a leading tag that a separator marks', () {
      const tagged = [
        'UK: BBC Four',
        'UK : BBC Four',
        'UK:BBC Four',
        'UK | BBC Four',
        'UK|BBC Four',
        'UK - BBC Four',
        'UK- BBC Four',
        'UK – BBC Four',
        'UK — BBC Four',
        '|UK| BBC Four',
        '[UK] BBC Four',
        '[ UK ] BBC Four',
        '(UK) BBC Four',
        '{UK} BBC Four',
        'UK ▎ BBC Four',
        'UK ┃ BBC Four',
        'UK • BBC Four',
        'UK · BBC Four',
        'UK ★ BBC Four',
        'USA: BBC Four',
        'EN | BBC Four',
        'EX-YU: BBC Four',
        'EX YU: BBC Four',
        'EXYU | BBC Four',
        '[EX-YU] BBC Four',
        '🇬🇧 UK: BBC Four',
      ];
      for (final name in tagged) {
        expect(normalizeChannelName(name), 'bbc four', reason: name);
      }
    });

    test('step 3: strips tags repeatedly', () {
      expect(normalizeChannelName('UK | EN | BBC Four'), 'bbc four');
      expect(normalizeChannelName('|UK| [FHD] BBC Four'), 'bbc four');
      expect(normalizeChannelName('[US][EN] CNN'), 'cnn');
    });

    test('step 3: never strips a first word with no separator', () {
      const kept = {
        'TV 5 Monde': 'tv 5 monde',
        'ABC News': 'abc news',
        'CNN': 'cnn',
        'UK BBC Four': 'uk bbc four',
        // A dash with no space beside it is part of the name.
        'Al-Jazeera': 'al jazeera',
        'RTL-2': 'rtl 2',
        'UK-BBC Four': 'uk bbc four',
        // Not 2–3 letters: a longer word, digits, or a word it runs into.
        'BBCA: Doctor Who': 'bbca doctor who',
        'TF1: Séries': 'tf1 series',
        'UK1: BBC Four': 'uk1 bbc four',
        '101 | BBC Four': '101 bbc four',
        // Other punctuation is no separator.
        'UK. BBC Four': 'uk bbc four',
        'UK/IE BBC Four': 'uk ie bbc four',
      };
      for (final MapEntry(key: name, value: key) in kept.entries) {
        expect(normalizeChannelName(name), key, reason: name);
      }
    });

    test('step 3: keeps a tag when nothing would be left after it', () {
      expect(normalizeChannelName('UK:'), 'uk');
      expect(normalizeChannelName('[US]'), 'us');
      expect(normalizeChannelName('|AR|'), 'ar');
    });

    test('step 4: drops quality tags as whole words anywhere', () {
      const tags = [
        'HD',
        'FHD',
        'UHD',
        'SD',
        '4K',
        '8K',
        'HEVC',
        'H265',
        'H.265',
        'H264',
        'h.264',
        'x265',
        '1080p',
        '1080i',
        '720p',
        '2160p',
        '576i',
        '50fps',
        '60fps',
        'HDR',
        'RAW',
        'VIP',
        'Backup',
        'MULTI',
        'Full HD',
        '[FHD]',
        '(HD)',
        '(Backup)',
        '[HD/FHD]',
      ];
      for (final tag in tags) {
        expect(normalizeChannelName('Arena $tag Sport'), 'arena sport');
        expect(normalizeChannelName('Arena Sport $tag'), 'arena sport');
        expect(normalizeChannelName(tag), '', reason: tag);
      }
    });

    test('step 4: leaves words that only contain a tag', () {
      expect(normalizeChannelName('HDTV Hits'), 'hdtv hits');
      expect(normalizeChannelName('Sky HD1'), 'sky hd1');
      expect(normalizeChannelName('SDR Rawson'), 'sdr rawson');
      expect(normalizeChannelName('Full Moon'), 'full moon');
    });

    test('steps 4 and 6: a timeshift stays, as one word', () {
      for (final name in [
        'Film4 +1',
        'Film4 + 1',
        'Film4+1',
        'Film4 Plus 1',
        'Film4 plus1',
        'Film4 HD +1',
        'Film4 +1 HD',
        'UK: Film4 (+1)',
      ]) {
        expect(normalizeChannelName(name), 'film4 plus1', reason: name);
      }
      expect(normalizeChannelName('ITV +2'), 'itv plus2');
      expect(
        normalizeChannelName('Film4 +1'),
        isNot(normalizeChannelName('Film4')),
      );
      expect(
        normalizeChannelName('Film4 +1'),
        isNot(normalizeChannelName('Film4 +2')),
      );
      // A `+` before no number is punctuation.
      expect(normalizeChannelName('Canal+'), 'canal');
    });

    test('step 5: & reads as and', () {
      expect(normalizeChannelName('A&E'), 'a and e');
      expect(normalizeChannelName('A & E'), normalizeChannelName('A and E'));
    });

    test('step 7: anything else that is not a letter or digit is a space', () {
      expect(normalizeChannelName('Nick Jr.'), 'nick jr');
      expect(normalizeChannelName('E! Entertainment'), 'e entertainment');
      expect(normalizeChannelName('Sky_Sports/News'), 'sky sports news');
      expect(normalizeChannelName('  Sky   \t News  '), 'sky news');
    });

    test('keeps the letters of other scripts', () {
      expect(normalizeChannelName('AR: قناة الجزيرة HD'), 'قناة الجزيرة');
      expect(normalizeChannelName('Первый канал'), 'первый канал');
      expect(normalizeChannelName('ΕΡΤ1'), 'ερτ1');
    });

    test('leadingCountryTag: the first country tag stripped', () {
      const tags = {
        'UK: BBC One': 'uk',
        '|EN| BBC One': 'en',
        '[US] CNN': 'us',
        'FR | TF1': 'fr',
        'AR - MBC 1': 'ar',
        'UK | EN | BBC One': 'uk',
        // Quality tags are no country; the next tag is.
        '[FHD] UK: BBC One': 'uk',
        // One country, two tags.
        'GB: BBC One': 'uk',
        'USA | CNN': 'us',
        'EX-YU: RTS 1': 'exyu',
      };
      for (final MapEntry(key: name, value: tag) in tags.entries) {
        expect(leadingCountryTag(name), tag, reason: name);
      }
      for (final name in ['BBC One', 'TV 5 Monde', 'UK BBC One', 'UK:', '']) {
        expect(leadingCountryTag(name), isNull, reason: name);
      }
    });

    test('normalizing twice is normalizing once', () {
      final names = [
        for (final line in _corpus()) ...[line.provider, line.guide],
        'Film4 plus-1',
        'h hd 265',
        'Plus HD 1',
        'Full SD HD',
        'Ex-Yu Rts',
        'UK:\u00a0|EN| ᴴᴰ Oneᶠᴴᴰ',
        '&amp;amp;amp;amp;amp;',
      ];
      for (final name in names) {
        final once = normalizeChannelName(name);
        expect(normalizeChannelName(once), once, reason: name);
      }
    });
  });

  group('EpgMatcher', () {
    MatchCandidate candidate(
      String name, {
      int id = 1,
      String? epgKey,
      String? remoteKey,
    }) => MatchCandidate(
      channelId: id,
      remoteKey: remoteKey ?? '$id',
      name: name,
      epgKey: epgKey,
    );

    const guide = [
      GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
      GuideChannel(xmltvId: 'BBCTwo.uk', displayName: 'BBC Two'),
      GuideChannel(xmltvId: 'itv1.uk', displayName: 'ITV 1'),
      GuideChannel(xmltvId: 'film4.uk', displayName: 'Film4'),
    ];

    test('tries manual, then exact id, then case-insensitive, then name', () {
      final matcher = EpgMatcher(guide, mappings: {'7': 'itv1.uk'});
      // Every rule could answer for this one: the mapping wins.
      expect(
        matcher.match(candidate('BBC One', id: 7, epgKey: 'BBCTwo.uk')),
        const ChannelMatch(
          channelId: 7,
          xmltvId: 'itv1.uk',
          rule: GuideMatchRule.manual,
        ),
      );
      expect(
        matcher.match(candidate('BBC One', epgKey: 'BBCTwo.uk')),
        const ChannelMatch(
          channelId: 1,
          xmltvId: 'BBCTwo.uk',
          rule: GuideMatchRule.exactId,
        ),
      );
      expect(
        matcher.match(candidate('BBC One', epgKey: ' bbctwo.UK ')),
        const ChannelMatch(
          channelId: 1,
          xmltvId: 'BBCTwo.uk',
          rule: GuideMatchRule.caseInsensitiveId,
        ),
      );
      // An id the guide does not have falls through to the name.
      expect(
        matcher.match(candidate('UK: BBC One HD', epgKey: 'nothere.uk')),
        const ChannelMatch(
          channelId: 1,
          xmltvId: 'bbcone.uk',
          rule: GuideMatchRule.normalizedName,
        ),
      );
      expect(matcher.match(candidate('UK: Channel 5')), isNull);
    });

    test('trims the channel id, and the exact spelling wins over another '
        'case', () {
      final matcher = EpgMatcher(const [
        GuideChannel(xmltvId: 'cnn.us'),
        GuideChannel(xmltvId: 'CNN.us'),
      ]);
      expect(
        matcher.match(candidate('x', epgKey: ' cnn.us ')),
        const ChannelMatch(
          channelId: 1,
          xmltvId: 'cnn.us',
          rule: GuideMatchRule.exactId,
        ),
      );
      expect(
        matcher.match(candidate('x', epgKey: 'Cnn.US'))?.xmltvId,
        'CNN.us',
        reason: 'the case-insensitive tie goes to the id that sorts first',
      );
    });

    test('keeps a manual mapping to an id the guide lacks', () {
      final matcher = EpgMatcher(guide, mappings: {'42': '  gone.uk '});
      expect(
        matcher.match(candidate('BBC One', id: 9, remoteKey: '42')),
        const ChannelMatch(
          channelId: 9,
          xmltvId: 'gone.uk',
          rule: GuideMatchRule.manual,
        ),
      );
      // With no guide at all, too.
      expect(
        EpgMatcher(
          const [],
          mappings: {'42': 'gone.uk'},
        ).match(candidate('x', remoteKey: '42'))?.rule,
        GuideMatchRule.manual,
      );
    });

    test('ignores blank keys', () {
      final matcher = EpgMatcher(
        const [
          GuideChannel(xmltvId: '', displayName: 'Blank'),
          GuideChannel(xmltvId: '   ', displayName: 'Spaces'),
          GuideChannel(xmltvId: 'nameless.uk'),
          GuideChannel(xmltvId: 'hd.uk', displayName: 'HD'),
          ...guide,
        ],
        mappings: {'1': '', '2': '   '},
      );
      // A blank mapping maps nothing: the channel is matched on its own.
      expect(
        matcher.match(candidate('BBC One', remoteKey: '1'))?.rule,
        GuideMatchRule.normalizedName,
      );
      expect(
        matcher.match(candidate('BBC One', remoteKey: '2'))?.rule,
        GuideMatchRule.normalizedName,
      );
      // A blank guide id is never matched, by id or by its name.
      expect(matcher.match(candidate('x', epgKey: '')), isNull);
      expect(matcher.match(candidate('x', epgKey: '   ')), isNull);
      expect(matcher.match(candidate('Blank')), isNull);
      expect(matcher.match(candidate('Spaces')), isNull);
      // A name that normalizes to nothing matches nothing.
      expect(matcher.match(candidate('HD')), isNull);
      expect(matcher.match(candidate('UK: 4K')), isNull);
      expect(matcher.match(candidate('')), isNull);
    });

    test('resolves a shared key to the id that sorts first, in any order', () {
      const shared = [
        GuideChannel(xmltvId: 'bbcone.uk.b', displayName: 'BBC One HD'),
        GuideChannel(xmltvId: 'bbcone.uk.a', displayName: 'BBC One'),
        GuideChannel(xmltvId: 'bbcone.uk.c', displayName: 'UK: BBC One'),
        GuideChannel(xmltvId: 'CNN', displayName: 'CNN International'),
        GuideChannel(xmltvId: 'cnn', displayName: 'CNN Intl'),
      ];
      for (final order in [shared, shared.reversed.toList()]) {
        final matcher = EpgMatcher(order);
        expect(matcher.match(candidate('BBC One FHD'))?.xmltvId, 'bbcone.uk.a');
        expect(
          matcher.match(candidate('x', epgKey: 'Cnn')),
          const ChannelMatch(
            channelId: 1,
            xmltvId: 'CNN',
            rule: GuideMatchRule.caseInsensitiveId,
          ),
        );
        expect(
          matcher.match(candidate('x', epgKey: 'cnn'))?.rule,
          GuideMatchRule.exactId,
        );
      }
    });

    test("a shared name prefers the feed of the name's country", () {
      const feeds = [
        GuideChannel(xmltvId: 'marlowdrama.de', displayName: 'Marlow Drama'),
        GuideChannel(xmltvId: 'marlowdrama.fr', displayName: 'Marlow Drama'),
        GuideChannel(xmltvId: 'marlowdrama.uk', displayName: 'Marlow Drama'),
        GuideChannel(xmltvId: 'marlowdrama.uk2', displayName: 'Marlow Drama'),
      ];
      for (final order in [feeds, feeds.reversed.toList()]) {
        final matcher = EpgMatcher(order);
        String? feedOf(String name) => matcher.match(candidate(name))?.xmltvId;
        expect(feedOf('UK: Marlow Drama HD'), 'marlowdrama.uk');
        expect(feedOf('[FR] Marlow Drama'), 'marlowdrama.fr');
        // `gb` and `uk` are one country, both ways.
        expect(feedOf('GB | Marlow Drama'), 'marlowdrama.uk');
        // No tag, or one no feed has: the id that sorts first, as before.
        expect(feedOf('Marlow Drama'), 'marlowdrama.de');
        expect(feedOf('IT: Marlow Drama'), 'marlowdrama.de');
      }
      final gb = EpgMatcher(const [
        GuideChannel(xmltvId: 'bbcone.fr', displayName: 'BBC One'),
        GuideChannel(xmltvId: 'BBCOne.GB', displayName: 'BBC One'),
        GuideChannel(xmltvId: 'cnn.ca', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnn.us', displayName: 'CNN'),
      ]);
      expect(gb.match(candidate('UK: BBC One'))?.xmltvId, 'BBCOne.GB');
      expect(gb.match(candidate('USA: CNN'))?.xmltvId, 'cnn.us');
      // Two feeds for one country: the one that sorts first.
      final twice = EpgMatcher(const [
        GuideChannel(xmltvId: 'itv1.uk', displayName: 'ITV 1'),
        GuideChannel(xmltvId: 'itv.uk', displayName: 'ITV1'),
        GuideChannel(xmltvId: 'itv1london.uk', displayName: 'ITV 1'),
      ]);
      expect(twice.match(candidate('UK: ITV 1'))?.xmltvId, 'itv1.uk');
    });

    test('the country chooses among ids without their suffix too, but a '
        'display name still comes first', () {
      final bare = EpgMatcher(const [
        GuideChannel(xmltvId: 'cnn.ca'),
        GuideChannel(xmltvId: 'cnn.us'),
      ]);
      expect(bare.match(candidate('[US] CNN'))?.xmltvId, 'cnn.us');
      expect(bare.match(candidate('CNN'))?.xmltvId, 'cnn.ca');
      final named = EpgMatcher(const [
        GuideChannel(xmltvId: 'cnn.us'),
        GuideChannel(xmltvId: 'cnni.ca', displayName: 'CNN'),
      ]);
      expect(named.match(candidate('[US] CNN'))?.xmltvId, 'cnni.ca');
    });

    test('attaches HD and SD variants to the same guide channel', () {
      final matches = EpgMatcher(guide).matchAll([
        candidate('UK: BBC One HD'),
        candidate('UK: BBC One SD', id: 2),
        candidate('UK: BBC One FHD', id: 3),
        candidate('UK: BBC One ᴴᴰ', id: 4),
        candidate('BBC One', id: 5),
      ]);
      expect(matches.map((m) => m.xmltvId).toSet(), {'bbcone.uk'});
      expect(matches.map((m) => m.channelId), [1, 2, 3, 4, 5]);
    });

    test('never matches a +1 channel to its parent', () {
      expect(EpgMatcher(guide).match(candidate('UK: Film4 +1')), isNull);
      final withTimeshift = EpgMatcher([
        ...guide,
        const GuideChannel(xmltvId: 'film4plus1.uk', displayName: 'Film4 +1'),
      ]);
      expect(
        withTimeshift.match(candidate('Film4 Plus 1 HD'))?.xmltvId,
        'film4plus1.uk',
      );
      expect(withTimeshift.match(candidate('Film4 HD'))?.xmltvId, 'film4.uk');
    });

    test('falls back to the guide id without its country suffix', () {
      final matcher = EpgMatcher(const [
        GuideChannel(xmltvId: 'cnn.us'),
        GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC 1'),
        GuideChannel(xmltvId: 'Sky Sports 1.uk'),
        GuideChannel(xmltvId: 'rts1.rs', displayName: 'RTS 1'),
        GuideChannel(xmltvId: 'b92', displayName: 'Other'),
        GuideChannel(xmltvId: '.uk'),
      ]);
      expect(
        matcher.match(candidate('[US] CNN HD')),
        const ChannelMatch(
          channelId: 1,
          xmltvId: 'cnn.us',
          rule: GuideMatchRule.normalizedName,
        ),
      );
      expect(matcher.match(candidate('bbcone'))?.xmltvId, 'bbcone.uk');
      expect(
        matcher.match(candidate('UK: Sky Sports 1 FHD'))?.xmltvId,
        'Sky Sports 1.uk',
      );
      // Only a country suffix goes: an id without one is not a name.
      expect(matcher.match(candidate('B92')), isNull);
      expect(matcher.match(candidate('UK')), isNull);
    });

    test('prefers a display name over an id without its suffix', () {
      final matcher = EpgMatcher(const [
        GuideChannel(xmltvId: 'zzz.us', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnn.us', displayName: 'CNN International'),
      ]);
      expect(matcher.match(candidate('CNN'))?.xmltvId, 'zzz.us');
    });

    test('matchAll leaves out the unmatched and keeps the order', () {
      final matches = EpgMatcher(guide).matchAll([
        candidate('BBC Two', id: 3),
        candidate('Nowhere', id: 4),
        candidate('ITV 1 HD', id: 5),
      ]);
      expect(matches.map((m) => m.channelId), [3, 5]);
    });

    test('matches 50,000 channels against 5,000 guide channels in well '
        'under a second', () {
      final guide = [
        for (var i = 0; i < 5000; i++)
          GuideChannel(xmltvId: '${_slug(i)}.uk', displayName: _benchName(i)),
      ];
      final channels = [
        for (var i = 0; i < 50000; i++)
          MatchCandidate(
            channelId: i,
            remoteKey: '$i',
            name: switch (i % 5) {
              2 => 'UK: ${_benchName(i % 5000)} HD',
              3 => '|EN| ${_benchName(i % 5000)} ᶠᴴᴰ',
              4 => 'Nowhere &amp; Else $i',
              _ => _benchName(i % 5000),
            },
            epgKey: switch (i % 5) {
              0 => '${_slug(i % 5000)}.uk',
              1 => '${_slug(i % 5000)}.UK',
              _ => null,
            },
          ),
      ];
      final mappings = {for (var i = 0; i < 50000; i += 100) '$i': 'mapped.$i'};

      final watch = Stopwatch()..start();
      final matches = EpgMatcher(guide, mappings: mappings).matchAll(channels);
      watch.stop();

      final byRule = <GuideMatchRule, int>{};
      for (final match in matches) {
        byRule.update(match.rule, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(byRule, {
        GuideMatchRule.manual: 500,
        GuideMatchRule.exactId: 9500,
        GuideMatchRule.caseInsensitiveId: 10000,
        GuideMatchRule.normalizedName: 20000,
      });
      // Measured ~0.17 s in a debug (JIT) test run; the bound is generous.
      expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    });
  });

  group('corpus (test_fixtures/epg_matching/names.tsv)', () {
    for (final line in _corpus()) {
      test('${line.provider} ↔ ${line.guide}: '
          '${line.match ? 'match' : 'no match'}', () {
        final matcher = EpgMatcher([
          GuideChannel(xmltvId: 'g1', displayName: line.guide),
        ]);
        final match = matcher.match(
          MatchCandidate(channelId: 1, remoteKey: '1', name: line.provider),
        );
        final reason =
            '"${normalizeChannelName(line.provider)}" vs '
            '"${normalizeChannelName(line.guide)}"';
        if (line.match) {
          expect(match?.rule, GuideMatchRule.normalizedName, reason: reason);
        } else {
          expect(match, isNull, reason: reason);
        }
      });
    }
  });

  group('the fake panel', () {
    for (final profile in ['default', 'quirky']) {
      final panel = _fakePanel(fakeProfiles[profile]!);

      test('$profile: every channel with a guide id matches it exactly', () {
        final matcher = EpgMatcher(panel.guide);
        for (final channel in panel.channels) {
          final match = matcher.match(channel);
          if (channel.epgKey == null) {
            // Not in the guide, but its name may be another country's feed
            // of the same channel: never an id match.
            expect(
              match?.rule,
              anyOf(isNull, GuideMatchRule.normalizedName),
              reason: channel.name,
            );
          } else {
            expect(
              match,
              ChannelMatch(
                channelId: channel.channelId,
                xmltvId: channel.epgKey!,
                rule: GuideMatchRule.exactId,
              ),
              reason: channel.name,
            );
          }
        }
      });

      test('$profile: with the ids gone, every name still finds its guide '
          'channel', () {
        final matcher = EpgMatcher(panel.guide);
        // Stripping country tags makes one channel's feeds for several
        // countries one key. The name's own tag chooses its country's feed;
        // with none, the id sorting first has it.
        final idsByKey = <String, List<String>>{};
        for (final channel in panel.guide) {
          final key = normalizeChannelName(channel.displayName ?? '');
          (idsByKey[key] ??= []).add(channel.xmltvId);
        }
        var own = 0;
        var tagged = 0;
        final guided = panel.channels.where((c) => c.epgKey != null);
        for (final channel in guided) {
          final match = matcher.match(
            MatchCandidate(
              channelId: channel.channelId,
              remoteKey: channel.remoteKey,
              name: channel.name,
            ),
          );
          expect(match?.rule, GuideMatchRule.normalizedName);
          final ids = idsByKey[normalizeChannelName(channel.name)]!..sort();
          final tag = leadingCountryTag(channel.name);
          final expected = ids.firstWhere(
            (id) => tag != null && id.endsWith('.$tag'),
            orElse: () => ids.first,
          );
          expect(match!.xmltvId, expected, reason: channel.name);
          // Only ever the same channel from another country's feed.
          expect(_bare(match.xmltvId), _bare(channel.epgKey!));
          if (tag != null) {
            // Every tagged channel lands on its own country's feed.
            tagged++;
            expect(match.xmltvId, channel.epgKey, reason: channel.name);
          }
          if (match.xmltvId == channel.epgKey) own++;
        }
        // default: 207 of 214 own (all 149 tagged); quirky: 284 of 285
        // (all 168 tagged). The rest carry no tag, and several countries
        // have a feed of the same name.
        expect(tagged, greaterThan(guided.length ~/ 2));
        expect(own / guided.length, greaterThan(0.9));
      });
    }
  });
}

typedef _Panel = ({List<MatchCandidate> channels, List<GuideChannel> guide});

/// The fake panel's live channels as the app reads them, and the guide
/// `xmltv.php` writes for them (tools/fake_provider/lib/xmltv.dart): a
/// channel's `epg_channel_id` is its guide id and its name the display
/// name.
_Panel _fakePanel(FakeProfile profile) {
  final all = FakeCatalog(profile).channels().toList();
  final guided = all.where((c) => c.epgChannelId != null).toList();
  final messy = profile.quirks.messyXmltv;
  return (
    channels: [
      for (final channel in all)
        MatchCandidate(
          channelId: channel.streamId,
          remoteKey: '${channel.streamId}',
          name: _asRead(channel.name),
          epgKey: channel.epgChannelId,
        ),
    ],
    guide: [
      for (final channel in guided)
        GuideChannel(
          xmltvId: channel.epgChannelId!,
          displayName: _asRead(channel.name),
        ),
      // The quirky guide declares its first channel twice, and one no
      // stream has.
      if (messy)
        GuideChannel(
          xmltvId: guided.first.epgChannelId!,
          displayName: _asRead(guided.first.name),
        ),
      if (messy)
        const GuideChannel(
          xmltvId: orphanXmltvId,
          displayName: 'Ghost Channel',
        ),
    ],
  );
}

/// What the Xtream client and the XMLTV parser both make of a name: the
/// invalid-UTF-8 marker is a U+FFFD on the wire, then `cleanText`.
String _asRead(String name) =>
    cleanText(name.replaceAll(invalidUtf8Marker, '\ufffd')) ?? '';

String _bare(String id) => id.substring(0, id.lastIndexOf('.'));

const _benchBrands = [
  'Northwind',
  'Aurora',
  'Meridian',
  'Kestrel',
  'Halcyon',
  'Vantage',
  'Zephyr',
  'Lumen',
  'Basalt',
  'Cobalt',
];

const _benchTopics = [
  'Sports',
  'Movies',
  'News',
  'Kids',
  'Drama',
  'Music',
  'Docs',
  'Comedy',
  'Life',
  'Cinema',
];

/// 5,000 distinct names: 10 brands × 10 topics × 50 numbers.
String _benchName(int i) =>
    '${_benchBrands[i % 10]} ${_benchTopics[i ~/ 10 % 10]} ${i ~/ 100 + 1}';

String _slug(int i) => _benchName(i).replaceAll(' ', '').toLowerCase();

typedef _CorpusLine = ({String provider, String guide, bool match});

List<_CorpusLine> _corpus() => [
  for (final line in File(
    'test_fixtures/epg_matching/names.tsv',
  ).readAsLinesSync())
    if (line.trim().isNotEmpty && !line.startsWith('#'))
      switch (line.split('\t')) {
        [final provider, final guide, final expected] => (
          provider: provider,
          guide: guide,
          match: switch (expected.trim()) {
            'match' => true,
            'no-match' => false,
            _ => throw FormatException('match or no-match: $line'),
          },
        ),
        _ => throw FormatException('three tab-separated fields: $line'),
      },
];
