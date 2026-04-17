enum SymbolCategory { basic, decrease, increase, cable, special, lace }

class KnitSymbol {
  final String id;
  final String unicode;
  final String name;
  final String abbr;
  final String description;
  final SymbolCategory category;
  /// 서술형 도안 변환용 동사 (한국어)
  final String verbKo;
  /// 서술형 도안 변환용 동사 (영어)
  final String verbEn;

  const KnitSymbol({
    required this.id,
    required this.unicode,
    required this.name,
    required this.abbr,
    required this.description,
    required this.category,
    String? verbKo,
    String? verbEn,
  })  : verbKo = verbKo ?? name,
        verbEn = verbEn ?? abbr;
}

class KnitSymbolLibrary {
  static const List<KnitSymbol> all = [
    // basic (12)
    KnitSymbol(id: 'k',       unicode: '□', name: 'Knit',            abbr: 'K',    description: 'Knit stitch',                      category: SymbolCategory.basic,    verbKo: '겉뜨기',             verbEn: 'knit'),
    KnitSymbol(id: 'p',       unicode: '■', name: 'Purl',            abbr: 'P',    description: 'Purl stitch',                      category: SymbolCategory.basic,    verbKo: '안뜨기',             verbEn: 'purl'),
    KnitSymbol(id: 'empty',   unicode: '–', name: 'Empty',           abbr: '-',    description: 'No stitch placeholder',            category: SymbolCategory.basic,    verbKo: '빈칸',               verbEn: 'empty'),
    KnitSymbol(id: 'yo',      unicode: '○', name: 'Yarn Over',       abbr: 'YO',   description: 'Yarn over',                        category: SymbolCategory.basic,    verbKo: '바늘비우기',          verbEn: 'yo'),
    KnitSymbol(id: 'sl_k',    unicode: 'V', name: 'Slip knitwise',   abbr: 'Sl k', description: 'Slip stitch knitwise',             category: SymbolCategory.basic,    verbKo: '겉뜨기미끄러뜨리기',   verbEn: 'sl k'),
    KnitSymbol(id: 'sl_p',    unicode: 'Ʌ', name: 'Slip purlwise',   abbr: 'Sl p', description: 'Slip stitch purlwise',             category: SymbolCategory.basic,    verbKo: '안뜨기미끄러뜨리기',   verbEn: 'sl p'),
    KnitSymbol(id: 'k_tbl',   unicode: '⊠', name: 'Knit tbl',        abbr: 'K tbl',description: 'Knit through back loop',          category: SymbolCategory.basic,    verbKo: '뒤걸어겉뜨기',        verbEn: 'k tbl'),
    KnitSymbol(id: 'p_tbl',   unicode: '⊡', name: 'Purl tbl',        abbr: 'P tbl',description: 'Purl through back loop',          category: SymbolCategory.basic,    verbKo: '뒤걸어안뜨기',        verbEn: 'p tbl'),
    KnitSymbol(id: 'k_thru',  unicode: '↑', name: 'Knit through',    abbr: 'Kth',  description: 'Knit through stitch below',        category: SymbolCategory.basic,    verbKo: '아래코겉뜨기',        verbEn: 'k thru'),
    KnitSymbol(id: 'dyo',     unicode: '◎', name: 'Double YO',       abbr: 'DYO',  description: 'Double yarn over',                 category: SymbolCategory.basic,    verbKo: '이중바늘비우기',       verbEn: 'dyo'),
    KnitSymbol(id: 'no_st',   unicode: '▪', name: 'No Stitch',       abbr: 'NS',   description: 'No stitch (chart filler)',         category: SymbolCategory.basic,    verbKo: '없는코',             verbEn: 'no st'),
    KnitSymbol(id: 'edge',    unicode: '|', name: 'Edge',             abbr: 'E',    description: 'Edge stitch',                      category: SymbolCategory.basic,    verbKo: '가장자리',            verbEn: 'edge'),

    // decrease (12)
    KnitSymbol(id: 'k2tog',       unicode: '╲',  name: 'K2tog',           abbr: 'K2tog',      description: 'Knit 2 together',                  category: SymbolCategory.decrease, verbKo: '2코모아겉뜨기',      verbEn: 'k2tog'),
    KnitSymbol(id: 'ssk',         unicode: '╱',  name: 'SSK',             abbr: 'SSK',        description: 'Slip slip knit',                   category: SymbolCategory.decrease, verbKo: '2코왼모아겉뜨기',    verbEn: 'ssk'),
    KnitSymbol(id: 'cdd',         unicode: '∧',  name: 'CDD',             abbr: 'CDD',        description: 'Central double decrease',          category: SymbolCategory.decrease, verbKo: '중심3코모아뜨기',    verbEn: 'cdd'),
    KnitSymbol(id: 'k3tog',       unicode: '⟍',  name: 'K3tog',           abbr: 'K3tog',      description: 'Knit 3 together',                  category: SymbolCategory.decrease, verbKo: '3코모아겉뜨기',      verbEn: 'k3tog'),
    KnitSymbol(id: 'sssk',        unicode: '⟋',  name: 'SSSK',            abbr: 'SSSK',       description: 'Slip slip slip knit',              category: SymbolCategory.decrease, verbKo: '3코왼모아겉뜨기',    verbEn: 'sssk'),
    KnitSymbol(id: 'skp',         unicode: '↗',  name: 'SKP',             abbr: 'SKP',        description: 'Slip knit pass slipped stitch over', category: SymbolCategory.decrease, verbKo: '미끄러뜨려덮어씌우기', verbEn: 'skp'),
    KnitSymbol(id: 'sl1k2togpsso',unicode: '⋀',  name: 'sl1-k2tog-psso',  abbr: 'CDD2',       description: 'Sl1, k2tog, pass slipped st over', category: SymbolCategory.decrease, verbKo: '중심3코감소',        verbEn: 'sl1-k2tog-psso'),
    KnitSymbol(id: 'k2tog_tbl',   unicode: '╲̲',  name: 'K2tog tbl',       abbr: 'K2tbl',      description: 'Knit 2 together through back loop', category: SymbolCategory.decrease, verbKo: '뒤걸어2코모아겉뜨기', verbEn: 'k2tog tbl'),
    KnitSymbol(id: 'p2tog',       unicode: '⊵',  name: 'P2tog',           abbr: 'P2tog',      description: 'Purl 2 together',                  category: SymbolCategory.decrease, verbKo: '2코모아안뜨기',      verbEn: 'p2tog'),
    KnitSymbol(id: 'p2tog_tbl',   unicode: '⊴',  name: 'P2tog tbl',       abbr: 'P2tbl',      description: 'Purl 2 together through back loop', category: SymbolCategory.decrease, verbKo: '뒤걸어2코모아안뜨기', verbEn: 'p2tog tbl'),
    KnitSymbol(id: 'p3tog',       unicode: '⋙',  name: 'P3tog',           abbr: 'P3tog',      description: 'Purl 3 together',                  category: SymbolCategory.decrease, verbKo: '3코모아안뜨기',      verbEn: 'p3tog'),
    KnitSymbol(id: 'cdd_p',       unicode: '⋁',  name: 'CDD purl',        abbr: 'CDDp',       description: 'Central double decrease purl side', category: SymbolCategory.decrease, verbKo: '안면중심3코모아뜨기', verbEn: 'cdd purl'),

    // increase (12)
    KnitSymbol(id: 'm1l',      unicode: '↖', name: 'M1L',          abbr: 'M1L',   description: 'Make 1 left',                      category: SymbolCategory.increase, verbKo: '왼쪽늘리기',   verbEn: 'm1l'),
    KnitSymbol(id: 'm1r',      unicode: '↗', name: 'M1R',          abbr: 'M1R',   description: 'Make 1 right',                     category: SymbolCategory.increase, verbKo: '오른쪽늘리기', verbEn: 'm1r'),
    KnitSymbol(id: 'kfb',      unicode: '⊤', name: 'KFB',          abbr: 'KFB',   description: 'Knit front and back',              category: SymbolCategory.increase, verbKo: '앞뒤겉뜨기',   verbEn: 'kfb'),
    KnitSymbol(id: 'pfb',      unicode: '⊥', name: 'PFB',          abbr: 'PFB',   description: 'Purl front and back',              category: SymbolCategory.increase, verbKo: '앞뒤안뜨기',   verbEn: 'pfb'),
    KnitSymbol(id: 'k1yo k1',  unicode: '⊎', name: 'K1-YO-K1',     abbr: 'KYK',   description: 'Knit 1, yarn over, knit 1 in same st', category: SymbolCategory.increase, verbKo: 'K-YO-K늘리기', verbEn: 'k1-yo-k1'),
    KnitSymbol(id: 'm1p',      unicode: '⇖', name: 'M1 purl',      abbr: 'M1P',   description: 'Make 1 purl',                      category: SymbolCategory.increase, verbKo: '안뜨기늘리기', verbEn: 'm1 purl'),
    KnitSymbol(id: 'kfbf',     unicode: '⫠', name: 'Kfbf',         abbr: 'Kfbf',  description: 'Knit front, back, front in same st', category: SymbolCategory.increase, verbKo: '앞뒤앞겉뜨기', verbEn: 'kfbf'),
    KnitSymbol(id: 'cast_on',  unicode: '◡', name: 'Cast on',      abbr: 'CO',    description: 'Cast on stitch',                   category: SymbolCategory.increase, verbKo: '만들기',       verbEn: 'cast on'),
    KnitSymbol(id: 'lift_l',   unicode: '⇑', name: 'Lifted inc L',  abbr: 'LIL',   description: 'Left lifted increase',             category: SymbolCategory.increase, verbKo: '왼들어올리기', verbEn: 'lift l'),
    KnitSymbol(id: 'lift_r',   unicode: '⇒', name: 'Lifted inc R',  abbr: 'LIR',   description: 'Right lifted increase',            category: SymbolCategory.increase, verbKo: '오른들어올리기', verbEn: 'lift r'),
    KnitSymbol(id: 'm1',       unicode: 'M', name: 'Make 1',       abbr: 'M1',    description: 'Make 1 stitch',                    category: SymbolCategory.increase, verbKo: '만들기',       verbEn: 'm1'),
    KnitSymbol(id: 'dbl_inc',  unicode: '⊻', name: 'Double inc',   abbr: 'DI',    description: 'Double increase',                  category: SymbolCategory.increase, verbKo: '이중늘리기',   verbEn: 'dbl inc'),

    // cable (12)
    KnitSymbol(id: 'c2f',  unicode: '⌒',  name: 'C2F',  abbr: 'C2F',  description: '2-st cable front',           category: SymbolCategory.cable,    verbKo: '2코앞케이블',  verbEn: 'c2f'),
    KnitSymbol(id: 'c2b',  unicode: '⌣',  name: 'C2B',  abbr: 'C2B',  description: '2-st cable back',            category: SymbolCategory.cable,    verbKo: '2코뒤케이블',  verbEn: 'c2b'),
    KnitSymbol(id: 't2f',  unicode: '⌓',  name: 'T2F',  abbr: 'T2F',  description: '2-st twist front (purl)',    category: SymbolCategory.cable,    verbKo: '2코앞트위스트', verbEn: 't2f'),
    KnitSymbol(id: 't2b',  unicode: '⌔',  name: 'T2B',  abbr: 'T2B',  description: '2-st twist back (purl)',     category: SymbolCategory.cable,    verbKo: '2코뒤트위스트', verbEn: 't2b'),
    KnitSymbol(id: 'c3f',  unicode: '⌰',  name: 'C3F',  abbr: 'C3F',  description: '3-st cable front',           category: SymbolCategory.cable,    verbKo: '3코앞케이블',  verbEn: 'c3f'),
    KnitSymbol(id: 'c3b',  unicode: '⌱',  name: 'C3B',  abbr: 'C3B',  description: '3-st cable back',            category: SymbolCategory.cable,    verbKo: '3코뒤케이블',  verbEn: 'c3b'),
    KnitSymbol(id: 'c4f',  unicode: '⍉',  name: 'C4F',  abbr: 'C4F',  description: '4-st cable front',           category: SymbolCategory.cable,    verbKo: '4코앞케이블',  verbEn: 'c4f'),
    KnitSymbol(id: 'c4b',  unicode: '⍊',  name: 'C4B',  abbr: 'C4B',  description: '4-st cable back',            category: SymbolCategory.cable,    verbKo: '4코뒤케이블',  verbEn: 'c4b'),
    KnitSymbol(id: 'c6f',  unicode: '⍋',  name: 'C6F',  abbr: 'C6F',  description: '6-st cable front',           category: SymbolCategory.cable,    verbKo: '6코앞케이블',  verbEn: 'c6f'),
    KnitSymbol(id: 'c6b',  unicode: '⍌',  name: 'C6B',  abbr: 'C6B',  description: '6-st cable back',            category: SymbolCategory.cable,    verbKo: '6코뒤케이블',  verbEn: 'c6b'),
    KnitSymbol(id: 't3f',  unicode: '⍮',  name: 'T3F',  abbr: 'T3F',  description: '3-st twist front',           category: SymbolCategory.cable,    verbKo: '3코앞트위스트', verbEn: 't3f'),
    KnitSymbol(id: 't3b',  unicode: '⍯',  name: 'T3B',  abbr: 'T3B',  description: '3-st twist back',            category: SymbolCategory.cable,    verbKo: '3코뒤트위스트', verbEn: 't3b'),

    // special (12)
    KnitSymbol(id: 'bobble',     unicode: '✿', name: 'Bobble',      abbr: 'Bob',  description: 'Bobble stitch',              category: SymbolCategory.special,  verbKo: '방울뜨기',   verbEn: 'bobble'),
    KnitSymbol(id: 'nupp',       unicode: '✾', name: 'Nupp',        abbr: 'Nup',  description: 'Nupp stitch',                category: SymbolCategory.special,  verbKo: '너프뜨기',   verbEn: 'nupp'),
    KnitSymbol(id: 'popcorn',    unicode: '✦', name: 'Popcorn',     abbr: 'Pop',  description: 'Popcorn stitch',             category: SymbolCategory.special,  verbKo: '팝콘뜨기',   verbEn: 'popcorn'),
    KnitSymbol(id: 'bullion',    unicode: '⊕', name: 'Bullion',     abbr: 'Bul',  description: 'Bullion stitch',             category: SymbolCategory.special,  verbKo: '블리언뜨기', verbEn: 'bullion'),
    KnitSymbol(id: 'smocking',   unicode: '∞', name: 'Smocking',    abbr: 'Smo',  description: 'Smocking stitch',            category: SymbolCategory.special,  verbKo: '스모킹뜨기', verbEn: 'smocking'),
    KnitSymbol(id: 'bead',       unicode: '●', name: 'Bead',        abbr: 'Bea',  description: 'Bead placement',             category: SymbolCategory.special,  verbKo: '비드',       verbEn: 'bead'),
    KnitSymbol(id: 'drop',       unicode: '↓', name: 'Drop stitch', abbr: 'Drp',  description: 'Drop stitch',                category: SymbolCategory.special,  verbKo: '떨어뜨리기', verbEn: 'drop'),
    KnitSymbol(id: 'elongated',  unicode: '↕', name: 'Elongated',   abbr: 'Elo',  description: 'Elongated stitch',           category: SymbolCategory.special,  verbKo: '늘림코',     verbEn: 'elongated'),
    KnitSymbol(id: 'gathered',   unicode: '≡', name: 'Gathered',    abbr: 'Gat',  description: 'Gathered stitch',            category: SymbolCategory.special,  verbKo: '모음코',     verbEn: 'gathered'),
    KnitSymbol(id: 'wrapped',    unicode: '⊗', name: 'Wrapped',     abbr: 'Wrp',  description: 'Wrapped stitch',             category: SymbolCategory.special,  verbKo: '감기코',     verbEn: 'wrapped'),
    KnitSymbol(id: 'twisted',    unicode: '✕', name: 'Twisted',     abbr: 'Twi',  description: 'Twisted stitch',             category: SymbolCategory.special,  verbKo: '꼰코',       verbEn: 'twisted'),
    KnitSymbol(id: 'embroidery', unicode: '✶', name: 'Embroidery',  abbr: 'Emb',  description: 'Embroidery stitch',          category: SymbolCategory.special,  verbKo: '자수',       verbEn: 'embroidery'),

    // lace (12)
    KnitSymbol(id: 'yo2',       unicode: '⊙', name: 'YO2',          abbr: 'YO2',  description: 'Double yarn over lace',      category: SymbolCategory.lace,     verbKo: '이중바늘비우기',   verbEn: 'yo2'),
    KnitSymbol(id: 'yo3',       unicode: '⊚', name: 'YO3',          abbr: 'YO3',  description: 'Triple yarn over lace',      category: SymbolCategory.lace,     verbKo: '삼중바늘비우기',   verbEn: 'yo3'),
    KnitSymbol(id: 'cyof',      unicode: '↺', name: 'CYOF',         abbr: 'CYOF', description: 'Circular yarn over front',   category: SymbolCategory.lace,     verbKo: '원형바늘비우기앞', verbEn: 'cyof'),
    KnitSymbol(id: 'cyob',      unicode: '↻', name: 'CYOB',         abbr: 'CYOB', description: 'Circular yarn over back',    category: SymbolCategory.lace,     verbKo: '원형바늘비우기뒤', verbEn: 'cyob'),
    KnitSymbol(id: 'dyo_dec',   unicode: '⊛', name: 'Double YO dec',abbr: 'DYD',  description: 'Double yarn over decrease',  category: SymbolCategory.lace,     verbKo: '이중바늘비우기감소', verbEn: 'dyo dec'),
    KnitSymbol(id: 'chain_yo',  unicode: '⋈', name: 'Chain YO',     abbr: 'CYO',  description: 'Chained yarn over',          category: SymbolCategory.lace,     verbKo: '연결바늘비우기',   verbEn: 'chain yo'),
    KnitSymbol(id: 'lace_hole', unicode: '⋇', name: 'Lace hole',    abbr: 'LH',   description: 'Lace hole (double)',         category: SymbolCategory.lace,     verbKo: '레이스구멍',       verbEn: 'lace hole'),
    KnitSymbol(id: 'fan',       unicode: '❋', name: 'Fan',          abbr: 'Fan',  description: 'Fan stitch',                 category: SymbolCategory.lace,     verbKo: '부채뜨기',         verbEn: 'fan'),
    KnitSymbol(id: 'shell',     unicode: '⌘', name: 'Shell',        abbr: 'Shl',  description: 'Shell stitch',               category: SymbolCategory.lace,     verbKo: '조개뜨기',         verbEn: 'shell'),
    KnitSymbol(id: 'picot',     unicode: '◠', name: 'Picot',        abbr: 'Pic',  description: 'Picot stitch',               category: SymbolCategory.lace,     verbKo: '피코뜨기',         verbEn: 'picot'),
    KnitSymbol(id: 'butterfly', unicode: '❆', name: 'Butterfly',    abbr: 'But',  description: 'Butterfly stitch',           category: SymbolCategory.lace,     verbKo: '나비뜨기',         verbEn: 'butterfly'),
    KnitSymbol(id: 'lace_edge', unicode: '≈', name: 'Lace edge',    abbr: 'LE',   description: 'Lace edge stitch',           category: SymbolCategory.lace,     verbKo: '레이스가장자리',   verbEn: 'lace edge'),
  ];

  static List<KnitSymbol> byCategory(SymbolCategory cat) =>
      all.where((s) => s.category == cat).toList();

  static KnitSymbol? byId(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
