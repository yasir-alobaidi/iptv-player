import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/guide/domain/epg.dart';
import 'package:iptv_player/features/guide/domain/epg_matcher.dart';
import 'package:iptv_player/features/guide/domain/guide_channel_ranking.dart';
import 'package:iptv_player/features/guide/domain/guide_matching.dart';

/// The Match… picker's ranking (Phase 4 step 5, "Rules for the ranking
/// agent"): every rule with the names panels and public guides write.
void main() {
  group('RankableGuideChannel.of', () {
    test('nameKey is the normalized display name, empty without one', () {
      expect(
        _of('bbcone.uk', 'UK: BBC One ᴴᴰ').nameKey,
        normalizeChannelName('UK: BBC One ᴴᴰ'),
      );
      expect(_of('bbcone.uk', 'UK: BBC One ᴴᴰ').nameKey, 'bbc one');
      expect(_of('ae.us', 'A&amp;E').nameKey, 'a and e');
      expect(_of('bbcone.uk').nameKey, '');
      expect(_of('hd.uk', 'HD').nameKey, '');
    });

    test('idKey drops the country suffix the way the matcher does, then '
        'normalizes', () {
      const ids = {
        'cnn.us': 'cnn',
        'bbc1.uk': 'bbc1',
        'BBCOne.uk': 'bbcone',
        ' CNN.US ': 'cnn',
        'espn.com': 'espn',
        'marlowdrama.gb': 'marlowdrama',
        'sky.news.uk': 'sky news',
        'Sky_Sports_Main_Event.uk': 'sky sports main event',
        'Film4Plus1.uk': 'film4plus1',
        // No dot: as it is.
        'skynews': 'skynews',
        // Not a country suffix: one letter, or digits.
        'bbcone.uk.b': 'bbcone uk b',
        'arena.sport.1': 'arena sport 1',
        // Nothing before the suffix: the id as it is.
        '.uk': 'uk',
        '': '',
      };
      for (final MapEntry(key: id, value: key) in ids.entries) {
        expect(_of(id).idKey, key, reason: id);
      }
    });

    test('guideIdKey is normalizeChannelName of the bare id, fast path or '
        'not', () {
      const ids = [
        'bbcone.uk',
        'BBCOne.UK',
        'BBC1',
        'cnn',
        'HD',
        'hd.uk',
        'FHD',
        '4K',
        '4k.us',
        'H264',
        'x265.tv',
        '1080p',
        'hevc',
        'plus1',
        'exyu',
        'ExYu.rs',
        'uk',
        'us.uk',
        '12345',
        'a',
        'sky.news.uk',
        'sky_news.uk',
        'Sky News.uk',
        'UK:BBCOne',
        'UK:BBC One.uk',
        '[US]CNN',
        'film4+1.uk',
        'a&amp;e.us',
        'télé.fr',
        'ｂｂｃ.uk',
        '.uk',
        ' cnn.us ',
        '',
        '   ',
      ];
      for (final id in ids) {
        expect(
          guideIdKey(id),
          normalizeChannelName(splitGuideId(id).bare),
          reason: id,
        );
      }
    });

    test('splitGuideId: a dot and two or three letters end the id', () {
      expect(splitGuideId('cnn.us'), (bare: 'cnn', country: 'us'));
      expect(splitGuideId(' CNN.US '), (bare: 'CNN', country: 'us'));
      expect(splitGuideId('espn.com'), (bare: 'espn', country: 'com'));
      expect(splitGuideId('bbc.gb'), (bare: 'bbc', country: 'uk'));
      expect(splitGuideId('cnn.usa'), (bare: 'cnn', country: 'us'));
      expect(splitGuideId('x..uk'), (bare: 'x.', country: 'uk'));
      expect(splitGuideId('.uk'), (bare: '.uk', country: 'uk'));
      for (final id in ['cnn', 'cnn.u', 'cnn.usaa', 'cnn.u1', 'cnn.1', '']) {
        expect(splitGuideId(id), (bare: id, country: null), reason: id);
      }
      expect(splitGuideId('bbcone.uk.b'), (bare: 'bbcone.uk.b', country: null));
    });

    test('prepareGuideChannels keeps the guide and its order', () {
      const guide = [
        GuideChannel(xmltvId: 'itv1.uk', displayName: 'ITV 1'),
        GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
        GuideChannel(xmltvId: 'cnn.us'),
      ];
      final prepared = prepareGuideChannels(guide);
      expect(prepared.map((c) => c.channel), guide);
      expect(prepared.map((c) => c.nameKey), ['itv 1', 'bbc one', '']);
      expect(prepared.map((c) => c.idKey), ['itv1', 'bbcone', 'cnn']);
    });
  });

  group('similarity', () {
    test('equal name keys score 1', () {
      final scores = _scores(
        [
          const GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
          const GuideChannel(xmltvId: 'cnn.us', displayName: 'CNN'),
          const GuideChannel(xmltvId: 'ae.us', displayName: 'A&E'),
          const GuideChannel(
            xmltvId: 'telequebec.ca',
            displayName: 'Tele Quebec',
          ),
          const GuideChannel(xmltvId: 'aljazeera.qa', displayName: 'الجزيرة'),
        ],
        {
          'UK: BBC One ᴴᴰ': 'bbcone.uk',
          '|EN| CNN': 'cnn.us',
          'US: A&amp;amp;E HD': 'ae.us',
          'US: A and E': 'ae.us',
          'FR: Télé-Québec': 'telequebec.ca',
          'AR | الجزيرة HD': 'aljazeera.qa',
        },
      );
      for (final MapEntry(key: name, value: score) in scores.entries) {
        expect(score, 1.0, reason: name);
      }
    });

    test('equal id keys score 1, spaces or not', () {
      final guide = prepareGuideChannels(const [
        GuideChannel(xmltvId: 'cnn.us'),
        GuideChannel(xmltvId: 'arenasports1.rs', displayName: 'Arena Sp. 1'),
        GuideChannel(xmltvId: 'sky.news.uk'),
        GuideChannel(xmltvId: 'Film4Plus1.uk'),
      ]);
      double score(String channelName, String id) => rankGuideChannels(
        guide,
        channelName: channelName,
      ).singleWhere((c) => c.channel.xmltvId == id).score;

      expect(score('US: CNN HD', 'cnn.us'), 1.0);
      expect(score('Arena Sports 1', 'arenasports1.rs'), 1.0);
      expect(score('UK: Sky News', 'sky.news.uk'), 1.0);
      expect(score('UK: SkyNews', 'sky.news.uk'), 1.0);
      expect(score('Film4 +1', 'Film4Plus1.uk'), 1.0);
    });

    test('names equal only without their spaces score below 1', () {
      final ranked = _rank('UK: 5 USA', const [
        GuideChannel(xmltvId: 'fiveusa', displayName: '5USA'),
      ]);
      expect(ranked.single.score, lessThan(1.0));
    });

    test('"arena sports 1": the same name, then a close one, then other '
        'numbers, then an unrelated one', () {
      const guide = [
        GuideChannel(xmltvId: 'velocity.us', displayName: 'Velocity Motors'),
        GuideChannel(
          xmltvId: 'arenasport10.rs',
          displayName: 'Arena Sports 10',
        ),
        GuideChannel(xmltvId: 'arenasport2.rs', displayName: 'Arena Sports 2'),
        GuideChannel(xmltvId: 'arenasp1.ba', displayName: 'Arena Sport 1'),
        GuideChannel(xmltvId: 'arenahd.rs', displayName: 'Arena Sports 1 HD'),
      ];
      for (final order in _orders(guide)) {
        final ranked = _rank('Arena Sports 1', order);
        expect(_labels(ranked), [
          'Arena Sports 1 HD',
          'Arena Sport 1',
          'Arena Sports 2',
          'Arena Sports 10',
          'Velocity Motors',
        ]);
        expect(ranked.first.score, 1.0);
        // Strictly decreasing: no ties to settle.
        for (var i = 1; i < ranked.length; i++) {
          expect(ranked[i].score, lessThan(ranked[i - 1].score));
        }
      }
    });

    test('a timeshift is a different channel: Film4 +1 before Film4', () {
      const guide = [
        GuideChannel(xmltvId: 'film4.uk', displayName: 'Film4'),
        GuideChannel(xmltvId: 'film4plus1.uk', displayName: 'Film4 +1'),
        GuideChannel(xmltvId: 'more4plus1.uk', displayName: 'More4 +1'),
      ];
      final plusOne = _rank('UK: Film4 +1 HD', guide);
      expect(plusOne.first.channel.xmltvId, 'film4plus1.uk');
      expect(plusOne.first.score, 1.0);
      expect(_score(plusOne, 'film4.uk'), lessThan(1.0));

      // The +1 known only by its id.
      final byId = _rank('UK: Film4 +1', const [
        GuideChannel(xmltvId: 'film4.uk', displayName: 'Film4'),
        GuideChannel(xmltvId: 'film4plus1.uk'),
      ]);
      expect(_ids(byId), ['film4plus1.uk', 'film4.uk']);
      expect(byId.first.score, 1.0);

      // And the other way round.
      final plain = _rank('UK: Film4', guide);
      expect(plain.first.channel.xmltvId, 'film4.uk');
      expect(_score(plain, 'film4plus1.uk'), lessThan(1.0));
    });

    test('the whole name inside a longer one beats a word that only looks '
        'alike', () {
      final ranked = _rank('UK: BBC One HD', const [
        GuideChannel(xmltvId: 'bbcnews.uk', displayName: 'BBC News'),
        GuideChannel(xmltvId: 'bbctwo.uk', displayName: 'BBC Two'),
        GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
        GuideChannel(xmltvId: 'bbconesc.uk', displayName: 'BBC One Scotland'),
      ]);
      expect(_ids(ranked).take(2), ['bbcone.uk', 'bbconesc.uk']);
      final cartoon = _rank('US: Cartoon Network (East)', const [
        GuideChannel(xmltvId: 'cnn.us', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnwest.us', displayName: 'Cartoon Network West'),
        GuideChannel(xmltvId: 'cn.us', displayName: 'Cartoon Network'),
        GuideChannel(xmltvId: 'cneast.us', displayName: 'Cartoon Network East'),
      ]);
      expect(_ids(cartoon), ['cneast.us', 'cn.us', 'cnwest.us', 'cnn.us']);
    });

    test('numbers are words: a different number is a real difference', () {
      final ranked = _rank('beIN Sports 1', const [
        GuideChannel(xmltvId: 'bein12.qa', displayName: 'beIN Sports 12'),
        GuideChannel(xmltvId: 'bein2.qa', displayName: 'beIN Sports 2'),
        GuideChannel(xmltvId: 'bein1.qa', displayName: 'beIN SPORTS 1 HD'),
        GuideChannel(xmltvId: 'bein11.qa', displayName: 'beIN Sports 11'),
      ]);
      expect(ranked.first.channel.xmltvId, 'bein1.qa');
      expect(ranked.first.score, 1.0);
      for (final other in ranked.skip(1)) {
        expect(other.score, lessThan(0.95), reason: other.channel.label);
      }
      // 11 and 12 start like 1, but are no closer to it than 2 is.
      expect(
        _score(ranked, 'bein2.qa'),
        greaterThan(_score(ranked, 'bein11.qa')),
      );
      expect(
        _score(ranked, 'bein2.qa'),
        greaterThan(_score(ranked, 'bein12.qa')),
      );
    });

    test('scores are 0..1, and 1 only for an equal key', () {
      final ranked = _rank('UK: Sky Sports Main Event', const [
        GuideChannel(xmltvId: 'ssme.uk', displayName: 'Sky Sports Main Event'),
        GuideChannel(xmltvId: 'ssme2.uk', displayName: 'Main Event Sky Sports'),
        GuideChannel(xmltvId: 'ssn.uk', displayName: 'Sky Sports News'),
        GuideChannel(xmltvId: 'skyone.uk', displayName: 'Sky One'),
        GuideChannel(xmltvId: 'qvc.uk', displayName: 'QVC'),
        GuideChannel(xmltvId: 'x.uk', displayName: 'Sky Sports Main Events'),
      ]);
      expect(_score(ranked, 'ssme.uk'), 1.0);
      for (final other in ranked.where((c) => c.channel.xmltvId != 'ssme.uk')) {
        expect(other.score, inInclusiveRange(0, 1), reason: other.toString());
        expect(other.score, lessThan(1.0), reason: other.toString());
      }
      // Sharing words and letters counts; sharing nothing is 0.
      expect(
        _score(ranked, 'ssn.uk'),
        greaterThan(_score(ranked, 'skyone.uk')),
      );
      expect(_score(ranked, 'skyone.uk'), greaterThan(0));
      expect(_score(ranked, 'qvc.uk'), 0);
    });

    test('an empty target or an empty key scores 0', () {
      const guide = [
        GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
        // No display name, and an id that normalizes to nothing.
        GuideChannel(xmltvId: 'hd.uk'),
        GuideChannel(xmltvId: '4k', displayName: 'FHD'),
      ];
      for (final name in ['', '   ', 'HD', 'UK: 4K', '[FHD]', '📺']) {
        final ranked = _rank(name, guide);
        expect(ranked, hasLength(3), reason: name);
        expect(ranked.map((c) => c.score), everyElement(0), reason: name);
      }
      final one = _rank('BBC One HD', guide);
      expect(_score(one, 'hd.uk'), 0);
      expect(_score(one, '4k'), 0);
    });
  });

  group('ties', () {
    const feeds = [
      GuideChannel(xmltvId: 'marlowdrama.fr', displayName: 'Marlow Drama'),
      GuideChannel(xmltvId: 'marlowdrama.uk', displayName: 'Marlow Drama'),
      GuideChannel(xmltvId: 'marlowdrama.de', displayName: 'Marlow Drama'),
    ];

    test("the feed for the channel's own country first", () {
      for (final order in _orders(feeds)) {
        expect(_ids(_rank('UK: Marlow Drama', order)).first, 'marlowdrama.uk');
        expect(
          _ids(_rank('|FR| Marlow Drama HD', order)).first,
          'marlowdrama.fr',
        );
        expect(_ids(_rank('[DE] Marlow Drama', order)).first, 'marlowdrama.de');
        // No tag: by label, then by id.
        expect(_ids(_rank('Marlow Drama', order)), [
          'marlowdrama.de',
          'marlowdrama.fr',
          'marlowdrama.uk',
        ]);
        // A tag no feed has.
        expect(_ids(_rank('IT: Marlow Drama', order)), [
          'marlowdrama.de',
          'marlowdrama.fr',
          'marlowdrama.uk',
        ]);
      }
    });

    test('gb is uk and usa is us, on either side', () {
      const guide = [
        GuideChannel(xmltvId: 'cnn.ca', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnn.gb', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnn.usa', displayName: 'CNN'),
      ];
      expect(_ids(_rank('UK: CNN', guide)).first, 'cnn.gb');
      expect(_ids(_rank('US: CNN', guide)).first, 'cnn.usa');
      expect(_ids(_rank('USA | CNN', guide)).first, 'cnn.usa');
      expect(_ids(_rank('GB: Marlow Drama', feeds)).first, 'marlowdrama.uk');
    });

    test('the country only settles a tie, never outranks a closer name', () {
      final ranked = _rank('UK: Marlow Drama', const [
        GuideChannel(xmltvId: 'marlowdrama.fr', displayName: 'Marlow Drama'),
        GuideChannel(
          xmltvId: 'marlowdramaplus.uk',
          displayName: 'Marlow Drama Plus',
        ),
      ]);
      expect(_ids(ranked), ['marlowdrama.fr', 'marlowdramaplus.uk']);
    });

    test('then the label, ignoring case', () {
      // Both names normalize to `nick jr`: the same score, no country.
      const guide = [
        GuideChannel(xmltvId: 'a.nickjr', displayName: 'Nick Jr.'),
        GuideChannel(xmltvId: 'b.nickjr', displayName: 'nick jr'),
      ];
      for (final order in _orders(guide)) {
        final ranked = _rank('Nick Jr', order);
        expect(ranked.map((c) => c.score), everyElement(1.0));
        // Case-sensitive, `Nick Jr.` would sort first.
        expect(_labels(ranked), ['nick jr', 'Nick Jr.']);
      }
      // All 0: the label alone orders them.
      const unrelated = [
        GuideChannel(xmltvId: 'c', displayName: 'bravo'),
        GuideChannel(xmltvId: 'a', displayName: 'Charlie'),
        GuideChannel(xmltvId: 'b', displayName: 'Alpha'),
      ];
      expect(_labels(_rank('', unrelated)), ['Alpha', 'bravo', 'Charlie']);
    });

    test('then the id', () {
      const guide = [
        GuideChannel(xmltvId: 'bbcnews.uk', displayName: 'BBC News'),
        GuideChannel(xmltvId: 'bbcnews.com', displayName: 'BBC News'),
        GuideChannel(xmltvId: 'BBCNews.uk', displayName: 'BBC News'),
      ];
      for (final order in _orders(guide)) {
        expect(_ids(_rank('BBC News', order)), [
          'BBCNews.uk',
          'bbcnews.com',
          'bbcnews.uk',
        ]);
      }
    });

    test('fully deterministic, whatever order the guide lists them in', () {
      final guide = [
        for (final name in [
          'Sky Sports F1',
          'Sky Sports F1',
          'Sky Sports News',
          'SKY SPORTS NEWS',
          'Sky Sports Racing',
          'Sky Sports Golf',
          'Sky Sports Arena',
          'Sky Cinema Action',
          'Sky Atlantic',
          'Sky One',
        ])
          for (final country in ['uk', 'ie', 'de'])
            GuideChannel(
              xmltvId: '${name.replaceAll(' ', '')}.$country',
              displayName: name,
            ),
        const GuideChannel(
          xmltvId: 'SkySportsF1.uk',
          iconUrl: 'http://a/1.png',
        ),
        const GuideChannel(xmltvId: 'SkySportsF1.uk'),
        const GuideChannel(xmltvId: 'SkySportsF1.uk', displayName: ''),
      ];
      final random = Random(7);
      for (final query in ['', 'sports', 'sky']) {
        final expected = _rank('IE: Sky Sports F1', guide, query: query);
        for (var round = 0; round < 20; round++) {
          final shuffled = [...guide]..shuffle(random);
          expect(
            _rank('IE: Sky Sports F1', shuffled, query: query),
            expected,
            reason: 'query "$query"',
          );
        }
      }
    });
  });

  group('with no query', () {
    const guide = [
      GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
      GuideChannel(xmltvId: 'bbctwo.uk', displayName: 'BBC Two'),
      GuideChannel(xmltvId: 'itv1.uk', displayName: 'ITV 1'),
      GuideChannel(xmltvId: 'dave.uk', displayName: 'Dave'),
    ];

    test('every guide channel is a candidate, zero scores included', () {
      final ranked = _rank('UK: BBC One HD', guide);
      expect(_ids(ranked), ['bbcone.uk', 'bbctwo.uk', 'dave.uk', 'itv1.uk']);
      expect(ranked.first.score, 1.0);
      expect(_score(ranked, 'dave.uk'), 0);
      expect(_score(ranked, 'itv1.uk'), 0);

      // Nothing close: the whole guide, never an empty list.
      expect(_rank('Kanal Zwölf', guide), hasLength(4));
    });

    test('blank and whitespace queries are no query', () {
      for (final query in ['', ' ', '\t \n']) {
        expect(
          _rank('UK: BBC One HD', guide, query: query),
          _rank('UK: BBC One HD', guide),
          reason: '"$query"',
        );
      }
    });

    test('takes the best limit', () {
      expect(_ids(_rank('BBC One', guide, limit: 2)), [
        'bbcone.uk',
        'bbctwo.uk',
      ]);
      expect(_rank('BBC One', guide, limit: 1000), hasLength(4));
      // The default limit is 50.
      final big = [
        for (var i = 0; i < 80; i++)
          GuideChannel(xmltvId: 'ch$i', displayName: 'Channel $i'),
      ];
      final ranked = _rank('Channel 7', big);
      expect(ranked, hasLength(50));
      expect(ranked.first.channel.xmltvId, 'ch7');
    });

    test('a limit of 0 or less is an empty list', () {
      expect(_rank('BBC One', guide, limit: 0), isEmpty);
      expect(_rank('BBC One', guide, limit: -1), isEmpty);
      expect(_rank('BBC One', guide, query: 'bbc', limit: 0), isEmpty);
    });

    test('an empty guide is an empty list', () {
      expect(_rank('BBC One', const []), isEmpty);
      expect(_rank('BBC One', const [], query: 'bbc'), isEmpty);
    });
  });

  group('with a query', () {
    const sports = [
      GuideChannel(xmltvId: 'eurosport1.fr', displayName: 'Eurosport 1'),
      GuideChannel(xmltvId: 'arenasport1.rs', displayName: 'Arena Sport 1'),
      GuideChannel(xmltvId: 'sportitalia.it', displayName: 'Sportitalia'),
      GuideChannel(xmltvId: 'sport.it', displayName: 'SPORT'),
      GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
    ];

    test('orders by fit first: equal, starts with, a word starts with, '
        'contains', () {
      for (final order in _orders(sports)) {
        // The channel itself fits the query worst, and still comes last.
        final ranked = _rank('FR: Eurosport 1 HD', order, query: 'Sport');
        expect(_ids(ranked), [
          'sport.it',
          'sportitalia.it',
          'arenasport1.rs',
          'eurosport1.fr',
        ]);
      }
    });

    test("an id starting with the query fits like a name's start", () {
      final ranked = _rank('Sportklub 1', const [
        GuideChannel(xmltvId: 'arenasport1.rs', displayName: 'Arena Sport 1'),
        GuideChannel(xmltvId: 'sportklub1.hr'),
      ], query: 'sport');
      expect(_ids(ranked), ['sportklub1.hr', 'arenasport1.rs']);
    });

    test('within a fit, by similarity to the channel, then the ties', () {
      const sky = [
        GuideChannel(xmltvId: 'skyatlantic.uk', displayName: 'Sky Atlantic'),
        GuideChannel(xmltvId: 'skyf1.uk', displayName: 'Sky Sports F1 HD'),
        GuideChannel(xmltvId: 'ssn.uk', displayName: 'Sky Sports News'),
        GuideChannel(xmltvId: 'skyf1.de', displayName: 'Sky Sports F1'),
        GuideChannel(xmltvId: 'wsky.us', displayName: 'Whisky TV'),
      ];
      final ranked = _rank('UK: Sky Sports F1 ᴴᴰ', sky, query: 'sky');
      expect(_ids(ranked), [
        // Starts with `sky`, the two feeds of the same name first: the
        // UK one before the German.
        'skyf1.uk',
        'skyf1.de',
        // Then more of the name shared before less of it.
        'ssn.uk',
        'skyatlantic.uk',
        // `sky` inside a word.
        'wsky.us',
      ]);
      expect(_score(ranked, 'skyf1.uk'), 1.0);
      expect(
        _score(ranked, 'ssn.uk'),
        greaterThan(_score(ranked, 'skyatlantic.uk')),
      );
    });

    test('the query is normalized like a name', () {
      final plain = _rank('Sky Sports F1', _sky, query: 'sky sports');
      expect(plain, isNotEmpty);
      for (final query in [
        'SKY SPORTS',
        'UK: Sky Sports',
        '  sky   sports ',
        'Sky Sports HD',
        'Sky_Sports',
      ]) {
        expect(
          _rank('Sky Sports F1', _sky, query: query),
          plain,
          reason: query,
        );
      }
      // Folded like a name: accents, entities.
      final quebec = _rank('Tele Quebec', const [
        GuideChannel(xmltvId: 'telequebec.ca', displayName: 'Télé-Québec'),
        GuideChannel(xmltvId: 'tva.ca', displayName: 'TVA'),
      ], query: 'télé');
      expect(_ids(quebec), ['telequebec.ca']);
      final ae = _rank('A&E', const [
        GuideChannel(xmltvId: 'ae.us', displayName: 'A&E'),
        GuideChannel(xmltvId: 'amc.us', displayName: 'AMC'),
      ], query: 'a &amp; e');
      expect(_ids(ae), ['ae.us']);
    });

    test('a query that normalizes to nothing is read as typed', () {
      const guide = [
        GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One HD'),
        GuideChannel(xmltvId: 'hdtvhits.us', displayName: 'HDTV Hits'),
        GuideChannel(xmltvId: 'bbctwo.uk', displayName: 'BBC Two'),
        GuideChannel(xmltvId: 'canalplus.fr', displayName: 'Canal+'),
        GuideChannel(xmltvId: 'canalplussport.fr', displayName: 'Canal+ Sport'),
        GuideChannel(xmltvId: 'tf1.fr', displayName: 'TF1'),
      ];
      // `hd` is a quality tag, so it normalizes to nothing.
      expect(_ids(_rank('BBC One', guide, query: 'HD')), [
        'hdtvhits.us',
        'bbcone.uk',
      ]);
      expect(_ids(_rank('Canal+', guide, query: '+')), [
        'canalplus.fr',
        'canalplussport.fr',
      ]);
      expect(_rank('BBC One', guide, query: '*'), isEmpty);
    });

    test('keeps a channel whose name or id contains the query, spaces or '
        'not', () {
      const guide = [
        GuideChannel(xmltvId: 'skysportsnews.uk'),
        GuideChannel(xmltvId: 'ssmain.uk', displayName: 'Sky Sports Main'),
        GuideChannel(xmltvId: 'skyone.uk', displayName: 'Sky One'),
        GuideChannel(xmltvId: 'sports.it', displayName: 'Sport Italia'),
      ];
      expect(
        _ids(_rank('Sky Sports News', guide, query: 'sky sports')).toSet(),
        {'skysportsnews.uk', 'ssmain.uk'},
      );
      expect(
        _ids(_rank('Sky Sports News', guide, query: 'skysports')).toSet(),
        {'skysportsnews.uk', 'ssmain.uk'},
      );
      expect(_ids(_rank('Sky Sports News', guide, query: 'sports news')), [
        'skysportsnews.uk',
      ]);
    });

    test('keeps a channel whose raw label or id contains the raw query', () {
      const guide = [
        GuideChannel(xmltvId: 'cnn.us', displayName: 'CNN'),
        GuideChannel(xmltvId: 'cnn.uk', displayName: 'CNN'),
        GuideChannel(xmltvId: 'e4.uk', displayName: 'E4 (Channel 4)'),
      ];
      expect(_ids(_rank('CNN', guide, query: 'cnn.us')), ['cnn.us']);
      expect(_ids(_rank('CNN', guide, query: 'CNN.US')), ['cnn.us']);
      expect(_ids(_rank('E4', guide, query: '(channel')), ['e4.uk']);
    });

    test('drops everything else', () {
      expect(_rank('BBC One', sports, query: 'itv'), isEmpty);
      expect(_ids(_rank('BBC One', sports, query: 'one')), ['bbcone.uk']);
    });

    test('the score is the similarity to the channel, whatever the query', () {
      final all = {
        for (final c in _rank('UK: Sky Sports F1', _sky, limit: 100))
          c.channel.xmltvId: c.score,
      };
      for (final query in ['sky', 'f1', 'sports', 'news', 'skysports']) {
        final ranked = _rank('UK: Sky Sports F1', _sky, query: query);
        expect(ranked, isNotEmpty, reason: query);
        for (final c in ranked) {
          expect(c.score, all[c.channel.xmltvId], reason: '$query: $c');
        }
      }
      expect(
        _score(_rank('UK: Sky Sports F1', _sky, query: 'f1'), 'skyf1.uk'),
        1.0,
      );
    });

    test('takes the best limit', () {
      final ranked = _rank('FR: Eurosport 1', sports, query: 'sport', limit: 2);
      expect(_ids(ranked), ['sport.it', 'sportitalia.it']);
    });

    test('the id-only guide: ids read as names', () {
      const guide = [
        GuideChannel(xmltvId: 'cnn.us'),
        GuideChannel(xmltvId: 'cnninternational.us'),
        GuideChannel(xmltvId: 'foxnews.us'),
      ];
      final ranked = _rank('US: CNN', guide, query: 'cnn');
      expect(_ids(ranked), ['cnn.us', 'cnninternational.us']);
      expect(ranked.first.score, 1.0);
    });
  });

  group('never throws', () {
    final long = 'Sky Sports ' * 1000;
    final guide = prepareGuideChannels([
      const GuideChannel(xmltvId: ''),
      const GuideChannel(xmltvId: '   ', displayName: '   '),
      const GuideChannel(xmltvId: '📺.uk', displayName: '📺🔥 ⚽'),
      const GuideChannel(xmltvId: 'aljazeera.qa', displayName: 'قناة الجزيرة'),
      const GuideChannel(xmltvId: 'ch1.ru', displayName: 'Первый канал'),
      const GuideChannel(xmltvId: 'ert1.gr', displayName: 'ΕΡΤ1'),
      const GuideChannel(xmltvId: 'nhk.jp', displayName: 'ＮＨＫ総合'),
      const GuideChannel(xmltvId: 'bad', displayName: '\ufffd\ufeff\u200b'),
      GuideChannel(xmltvId: 'long.uk', displayName: long),
      GuideChannel(xmltvId: '${'x' * 10000}.uk'),
      const GuideChannel(xmltvId: 'num', displayName: '12345678901234567890'),
      const GuideChannel(xmltvId: 'bbcone.uk', displayName: 'BBC One'),
    ]);

    test('on empty, emoji, RTL, odd characters and 10k-character names', () {
      final names = [
        '',
        ' ',
        '📺',
        '🇬🇧 UK: 📺 BBC One',
        'AR: قناة الجزيرة HD',
        '\u202eBBC One',
        '\ufffd',
        'ＮＨＫ総合',
        long,
        'z' * 10000,
        '9' * 10000,
        '1 2 3 4 5 6 7 8 9 10 ' * 500,
      ];
      for (final name in names) {
        for (final query in [...names, 'a', '.', '%', r'\', '[', '(']) {
          final ranked = rankGuideChannels(
            guide,
            channelName: name,
            query: query,
          );
          for (final c in ranked) {
            expect(c.score, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('and still ranks them', () {
      final arabic = rankGuideChannels(
        guide,
        channelName: 'AR: قناة الجزيرة HD',
      );
      expect(arabic.first.channel.xmltvId, 'aljazeera.qa');
      expect(arabic.first.score, 1.0);
      expect(
        _ids(rankGuideChannels(guide, channelName: '', query: 'الجزيرة')),
        ['aljazeera.qa'],
      );
      expect(_ids(rankGuideChannels(guide, channelName: '', query: '🔥')), [
        '📺.uk',
      ]);
      final longest = rankGuideChannels(guide, channelName: long);
      expect(longest.first.channel.xmltvId, 'long.uk');
      expect(longest.first.score, 1.0);
      expect(
        rankGuideChannels(guide, channelName: 'BBC One').first.channel.xmltvId,
        'bbcone.uk',
      );
    });
  });

  test('5,000 guide channels: each finds itself first', () {
    final guide = [
      for (var i = 0; i < 5000; i++)
        GuideChannel(
          xmltvId: '${_slug(i)}.${_countries[i % _countries.length]}',
          displayName: _name(i),
        ),
    ];
    final prepared = prepareGuideChannels(guide);
    for (var i = 0; i < 5000; i += 97) {
      final country = _countries[i % _countries.length];
      final ranked = rankGuideChannels(
        prepared,
        channelName: '${country.toUpperCase()}: ${_name(i)} HD',
      );
      expect(ranked, hasLength(50));
      expect(ranked.first.channel, guide[i], reason: _name(i));
      expect(ranked.first.score, 1.0);
      for (var j = 1; j < ranked.length; j++) {
        expect(ranked[j].score, lessThanOrEqualTo(ranked[j - 1].score));
        expect(ranked[j].score, lessThan(1.0));
      }
      expect(ranked.map((c) => c.channel.xmltvId).toSet(), hasLength(50));
    }
    final brand = rankGuideChannels(
      prepared,
      channelName: _name(0),
      query: _brands[3],
      limit: 1000,
    );
    // Every name of that brand, and nothing else.
    expect(brand, hasLength(500));
    expect(
      brand.map((c) => c.channel.displayName),
      everyElement(startsWith(_brands[3])),
    );
  });

  // The spec's budget: preparing a 50,000-channel guide and ranking it
  // once within 400 ms in a debug (JIT) run; measured ~270 ms (prepare
  // ~220, rank ~50), most of the prepare being `normalizeChannelName`.
  // Skipped unless asked for:
  //
  //     flutter test --tags benchmark --run-skipped \
  //       test/features/guide/domain/guide_channel_ranking_test.dart
  test('benchmark: 50,000 guide channels, prepared and ranked', () {
    final random = Random(42);
    final guide = [for (var i = 0; i < 50000; i++) _randomChannel(random, i)];
    final named = guide.where((c) => c.displayName != null).toList();
    final name = named[123].displayName!;
    final clock = Stopwatch()..start();
    final prepared = prepareGuideChannels(guide);
    final prepareMs = clock.elapsedMilliseconds;
    clock.reset();
    final ranked = rankGuideChannels(prepared, channelName: 'UK: $name HD');
    final rankMs = clock.elapsedMilliseconds;
    clock.reset();
    final queried = rankGuideChannels(
      prepared,
      channelName: 'UK: $name HD',
      query: name.split(' ').first.substring(0, 3),
    );
    final queryMs = clock.elapsedMilliseconds;
    clock.reset();
    rankGuideChannels(prepared, channelName: 'US: ${named[4567].displayName}');
    final warmMs = clock.elapsedMilliseconds;

    // The benchmark's output is its result, read by whoever runs it.
    // ignore: avoid_print
    print(
      '50,000 guide channels: prepare $prepareMs ms, first rank $rankMs '
      'ms (total ${prepareMs + rankMs} ms), a query $queryMs ms, another '
      'rank $warmMs ms',
    );
    expect(ranked.first.channel.displayName, name);
    expect(ranked.first.score, 1.0);
    expect(queried, isNotEmpty);
    expect(prepareMs + rankMs, lessThan(400));
  }, tags: ['benchmark']);
}

RankableGuideChannel _of(String id, [String? displayName]) =>
    RankableGuideChannel.of(
      GuideChannel(xmltvId: id, displayName: displayName),
    );

List<GuideChannelCandidate> _rank(
  String channelName,
  List<GuideChannel> guide, {
  String query = '',
  int limit = 50,
}) => rankGuideChannels(
  prepareGuideChannels(guide),
  channelName: channelName,
  query: query,
  limit: limit,
);

/// For each channel name, the score of the guide channel it names.
Map<String, double> _scores(
  List<GuideChannel> guide,
  Map<String, String> expected,
) => {
  for (final MapEntry(key: name, value: id) in expected.entries)
    name: _score(_rank(name, guide), id),
};

double _score(List<GuideChannelCandidate> ranked, String id) =>
    ranked.singleWhere((c) => c.channel.xmltvId == id).score;

List<String> _ids(List<GuideChannelCandidate> ranked) => [
  for (final c in ranked) c.channel.xmltvId,
];

List<String> _labels(List<GuideChannelCandidate> ranked) => [
  for (final c in ranked) c.channel.label,
];

/// The list as given, reversed, and a few shuffles.
List<List<T>> _orders<T>(List<T> list) {
  final random = Random(1);
  return [
    list,
    list.reversed.toList(),
    for (var i = 0; i < 4; i++) [...list]..shuffle(random),
  ];
}

const _sky = [
  GuideChannel(xmltvId: 'skyf1.uk', displayName: 'Sky Sports F1'),
  GuideChannel(xmltvId: 'skyf1.de', displayName: 'Sky Sport F1'),
  GuideChannel(xmltvId: 'ssn.uk', displayName: 'Sky Sports News'),
  GuideChannel(xmltvId: 'ssme.uk', displayName: 'Sky Sports Main Event'),
  GuideChannel(xmltvId: 'skyatlantic.uk', displayName: 'Sky Atlantic'),
  GuideChannel(xmltvId: 'skynews.uk', displayName: 'Sky News'),
  GuideChannel(xmltvId: 'bbcnews.uk', displayName: 'BBC News'),
  GuideChannel(xmltvId: 'f1tv.com', displayName: 'F1 TV'),
];

const _brands = [
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

const _topics = [
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

const _countries = ['uk', 'us', 'de', 'fr', 'it'];

/// 5,000 distinct names: 10 brands × 10 topics × 50 numbers.
String _name(int i) =>
    '${_brands[i % 10]} ${_topics[i ~/ 10 % 10]} ${i ~/ 100 + 1}';

String _slug(int i) => _name(i).replaceAll(' ', '').toLowerCase();

const _syllables = [
  'ka',
  'ro',
  'mi',
  'tel',
  'sa',
  'vi',
  'on',
  'du',
  'ne',
  'bra',
  'lo',
  'zu',
  'pe',
  'ta',
  'gri',
  'mo',
  'lin',
  'ex',
  'sto',
  'ra',
  'ce',
  'fa',
  'qui',
  'vor',
];

const _tails = [
  'TV',
  'HD',
  'News',
  'Sport',
  'Sports',
  'Kids',
  '+1',
  'Cinema',
  'Music',
  'FHD',
  'Plus',
  'Max',
  '1',
  '2',
  '3',
  '24',
  'International',
  'Premium',
];

/// A made-up but name-shaped guide channel: one or two invented words
/// (tens of thousands of distinct ones), then a tail most guides share.
GuideChannel _randomChannel(Random random, int i) {
  String word() {
    final parts = 2 + random.nextInt(2);
    final text = [
      for (var p = 0; p < parts; p++)
        _syllables[random.nextInt(_syllables.length)],
    ].join();
    return text[0].toUpperCase() + text.substring(1);
  }

  final words = [
    word(),
    if (random.nextBool()) word(),
    _tails[random.nextInt(_tails.length)],
    if (random.nextInt(3) == 0) '${random.nextInt(12) + 1}',
  ];
  final name = words.join(' ');
  final country = _countries[i % _countries.length];
  return GuideChannel(
    xmltvId: '${name.replaceAll(' ', '').toLowerCase()}$i.$country',
    displayName: random.nextInt(10) == 0 ? null : name,
    iconUrl: 'https://logos.example/$i.png',
  );
}
