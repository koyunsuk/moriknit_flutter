enum SymbolCategory { basic, decrease, increase, cable, special, lace }

class KnitSymbol {
  final String id;
  final String unicode;
  final String name;
  final String abbr;
  final String description;
  final SymbolCategory category;

  const KnitSymbol({
    required this.id,
    required this.unicode,
    required this.name,
    required this.abbr,
    required this.description,
    required this.category,
  });
}

class KnitSymbolLibrary {
  static const List<KnitSymbol> all = [
    // basic (12)
    KnitSymbol(id: 'k',       unicode: '□', name: 'Knit',            abbr: 'K',    description: 'Knit stitch',                      category: SymbolCategory.basic),
    KnitSymbol(id: 'p',       unicode: '■', name: 'Purl',            abbr: 'P',    description: 'Purl stitch',                      category: SymbolCategory.basic),
    KnitSymbol(id: 'empty',   unicode: '–', name: 'Empty',           abbr: '-',    description: 'No stitch placeholder',            category: SymbolCategory.basic),
    KnitSymbol(id: 'yo',      unicode: '○', name: 'Yarn Over',       abbr: 'YO',   description: 'Yarn over',                        category: SymbolCategory.basic),
    KnitSymbol(id: 'sl_k',    unicode: 'V', name: 'Slip knitwise',   abbr: 'Sl k', description: 'Slip stitch knitwise',             category: SymbolCategory.basic),
    KnitSymbol(id: 'sl_p',    unicode: 'Ʌ', name: 'Slip purlwise',   abbr: 'Sl p', description: 'Slip stitch purlwise',             category: SymbolCategory.basic),
    KnitSymbol(id: 'k_tbl',   unicode: '⊠', name: 'Knit tbl',        abbr: 'K tbl',description: 'Knit through back loop',          category: SymbolCategory.basic),
    KnitSymbol(id: 'p_tbl',   unicode: '⊡', name: 'Purl tbl',        abbr: 'P tbl',description: 'Purl through back loop',          category: SymbolCategory.basic),
    KnitSymbol(id: 'k_thru',  unicode: '↑', name: 'Knit through',    abbr: 'Kth',  description: 'Knit through stitch below',        category: SymbolCategory.basic),
    KnitSymbol(id: 'dyo',     unicode: '◎', name: 'Double YO',       abbr: 'DYO',  description: 'Double yarn over',                 category: SymbolCategory.basic),
    KnitSymbol(id: 'no_st',   unicode: '▪', name: 'No Stitch',       abbr: 'NS',   description: 'No stitch (chart filler)',         category: SymbolCategory.basic),
    KnitSymbol(id: 'edge',    unicode: '|', name: 'Edge',             abbr: 'E',    description: 'Edge stitch',                      category: SymbolCategory.basic),

    // decrease (12)
    KnitSymbol(id: 'k2tog',       unicode: '╲',  name: 'K2tog',           abbr: 'K2tog',      description: 'Knit 2 together',                  category: SymbolCategory.decrease),
    KnitSymbol(id: 'ssk',         unicode: '╱',  name: 'SSK',             abbr: 'SSK',        description: 'Slip slip knit',                   category: SymbolCategory.decrease),
    KnitSymbol(id: 'cdd',         unicode: '∧',  name: 'CDD',             abbr: 'CDD',        description: 'Central double decrease',          category: SymbolCategory.decrease),
    KnitSymbol(id: 'k3tog',       unicode: '⟍',  name: 'K3tog',           abbr: 'K3tog',      description: 'Knit 3 together',                  category: SymbolCategory.decrease),
    KnitSymbol(id: 'sssk',        unicode: '⟋',  name: 'SSSK',            abbr: 'SSSK',       description: 'Slip slip slip knit',              category: SymbolCategory.decrease),
    KnitSymbol(id: 'skp',         unicode: '↗',  name: 'SKP',             abbr: 'SKP',        description: 'Slip knit pass slipped stitch over', category: SymbolCategory.decrease),
    KnitSymbol(id: 'sl1k2togpsso',unicode: '⋀',  name: 'sl1-k2tog-psso',  abbr: 'CDD2',       description: 'Sl1, k2tog, pass slipped st over', category: SymbolCategory.decrease),
    KnitSymbol(id: 'k2tog_tbl',   unicode: '╲̲',  name: 'K2tog tbl',       abbr: 'K2tbl',      description: 'Knit 2 together through back loop', category: SymbolCategory.decrease),
    KnitSymbol(id: 'p2tog',       unicode: '⊵',  name: 'P2tog',           abbr: 'P2tog',      description: 'Purl 2 together',                  category: SymbolCategory.decrease),
    KnitSymbol(id: 'p2tog_tbl',   unicode: '⊴',  name: 'P2tog tbl',       abbr: 'P2tbl',      description: 'Purl 2 together through back loop', category: SymbolCategory.decrease),
    KnitSymbol(id: 'p3tog',       unicode: '⋙',  name: 'P3tog',           abbr: 'P3tog',      description: 'Purl 3 together',                  category: SymbolCategory.decrease),
    KnitSymbol(id: 'cdd_p',       unicode: '⋁',  name: 'CDD purl',        abbr: 'CDDp',       description: 'Central double decrease purl side', category: SymbolCategory.decrease),

    // increase (12)
    KnitSymbol(id: 'm1l',      unicode: '↖', name: 'M1L',          abbr: 'M1L',   description: 'Make 1 left',                      category: SymbolCategory.increase),
    KnitSymbol(id: 'm1r',      unicode: '↗', name: 'M1R',          abbr: 'M1R',   description: 'Make 1 right',                     category: SymbolCategory.increase),
    KnitSymbol(id: 'kfb',      unicode: '⊤', name: 'KFB',          abbr: 'KFB',   description: 'Knit front and back',              category: SymbolCategory.increase),
    KnitSymbol(id: 'pfb',      unicode: '⊥', name: 'PFB',          abbr: 'PFB',   description: 'Purl front and back',              category: SymbolCategory.increase),
    KnitSymbol(id: 'k1yo k1',  unicode: '⊎', name: 'K1-YO-K1',     abbr: 'KYK',   description: 'Knit 1, yarn over, knit 1 in same st', category: SymbolCategory.increase),
    KnitSymbol(id: 'm1p',      unicode: '⇖', name: 'M1 purl',      abbr: 'M1P',   description: 'Make 1 purl',                      category: SymbolCategory.increase),
    KnitSymbol(id: 'kfbf',     unicode: '⫠', name: 'Kfbf',         abbr: 'Kfbf',  description: 'Knit front, back, front in same st', category: SymbolCategory.increase),
    KnitSymbol(id: 'cast_on',  unicode: '◡', name: 'Cast on',      abbr: 'CO',    description: 'Cast on stitch',                   category: SymbolCategory.increase),
    KnitSymbol(id: 'lift_l',   unicode: '⇑', name: 'Lifted inc L',  abbr: 'LIL',   description: 'Left lifted increase',             category: SymbolCategory.increase),
    KnitSymbol(id: 'lift_r',   unicode: '⇒', name: 'Lifted inc R',  abbr: 'LIR',   description: 'Right lifted increase',            category: SymbolCategory.increase),
    KnitSymbol(id: 'm1',       unicode: 'M', name: 'Make 1',       abbr: 'M1',    description: 'Make 1 stitch',                    category: SymbolCategory.increase),
    KnitSymbol(id: 'dbl_inc',  unicode: '⊻', name: 'Double inc',   abbr: 'DI',    description: 'Double increase',                  category: SymbolCategory.increase),

    // cable (12)
    KnitSymbol(id: 'c2f',  unicode: '⌒',  name: 'C2F',  abbr: 'C2F',  description: '2-st cable front',           category: SymbolCategory.cable),
    KnitSymbol(id: 'c2b',  unicode: '⌣',  name: 'C2B',  abbr: 'C2B',  description: '2-st cable back',            category: SymbolCategory.cable),
    KnitSymbol(id: 't2f',  unicode: '⌓',  name: 'T2F',  abbr: 'T2F',  description: '2-st twist front (purl)',    category: SymbolCategory.cable),
    KnitSymbol(id: 't2b',  unicode: '⌔',  name: 'T2B',  abbr: 'T2B',  description: '2-st twist back (purl)',     category: SymbolCategory.cable),
    KnitSymbol(id: 'c3f',  unicode: '⌰',  name: 'C3F',  abbr: 'C3F',  description: '3-st cable front',           category: SymbolCategory.cable),
    KnitSymbol(id: 'c3b',  unicode: '⌱',  name: 'C3B',  abbr: 'C3B',  description: '3-st cable back',            category: SymbolCategory.cable),
    KnitSymbol(id: 'c4f',  unicode: '⍉',  name: 'C4F',  abbr: 'C4F',  description: '4-st cable front',           category: SymbolCategory.cable),
    KnitSymbol(id: 'c4b',  unicode: '⍊',  name: 'C4B',  abbr: 'C4B',  description: '4-st cable back',            category: SymbolCategory.cable),
    KnitSymbol(id: 'c6f',  unicode: '⍋',  name: 'C6F',  abbr: 'C6F',  description: '6-st cable front',           category: SymbolCategory.cable),
    KnitSymbol(id: 'c6b',  unicode: '⍌',  name: 'C6B',  abbr: 'C6B',  description: '6-st cable back',            category: SymbolCategory.cable),
    KnitSymbol(id: 't3f',  unicode: '⍮',  name: 'T3F',  abbr: 'T3F',  description: '3-st twist front',           category: SymbolCategory.cable),
    KnitSymbol(id: 't3b',  unicode: '⍯',  name: 'T3B',  abbr: 'T3B',  description: '3-st twist back',            category: SymbolCategory.cable),

    // special (12)
    KnitSymbol(id: 'bobble',     unicode: '✿', name: 'Bobble',      abbr: 'Bob',  description: 'Bobble stitch',              category: SymbolCategory.special),
    KnitSymbol(id: 'nupp',       unicode: '✾', name: 'Nupp',        abbr: 'Nup',  description: 'Nupp stitch',                category: SymbolCategory.special),
    KnitSymbol(id: 'popcorn',    unicode: '✦', name: 'Popcorn',     abbr: 'Pop',  description: 'Popcorn stitch',             category: SymbolCategory.special),
    KnitSymbol(id: 'bullion',    unicode: '⊕', name: 'Bullion',     abbr: 'Bul',  description: 'Bullion stitch',             category: SymbolCategory.special),
    KnitSymbol(id: 'smocking',   unicode: '∞', name: 'Smocking',    abbr: 'Smo',  description: 'Smocking stitch',            category: SymbolCategory.special),
    KnitSymbol(id: 'bead',       unicode: '●', name: 'Bead',        abbr: 'Bea',  description: 'Bead placement',             category: SymbolCategory.special),
    KnitSymbol(id: 'drop',       unicode: '↓', name: 'Drop stitch', abbr: 'Drp',  description: 'Drop stitch',                category: SymbolCategory.special),
    KnitSymbol(id: 'elongated',  unicode: '↕', name: 'Elongated',   abbr: 'Elo',  description: 'Elongated stitch',           category: SymbolCategory.special),
    KnitSymbol(id: 'gathered',   unicode: '≡', name: 'Gathered',    abbr: 'Gat',  description: 'Gathered stitch',            category: SymbolCategory.special),
    KnitSymbol(id: 'wrapped',    unicode: '⊗', name: 'Wrapped',     abbr: 'Wrp',  description: 'Wrapped stitch',             category: SymbolCategory.special),
    KnitSymbol(id: 'twisted',    unicode: '✕', name: 'Twisted',     abbr: 'Twi',  description: 'Twisted stitch',             category: SymbolCategory.special),
    KnitSymbol(id: 'embroidery', unicode: '✶', name: 'Embroidery',  abbr: 'Emb',  description: 'Embroidery stitch',          category: SymbolCategory.special),

    // lace (12)
    KnitSymbol(id: 'yo2',       unicode: '⊙', name: 'YO2',          abbr: 'YO2',  description: 'Double yarn over lace',      category: SymbolCategory.lace),
    KnitSymbol(id: 'yo3',       unicode: '⊚', name: 'YO3',          abbr: 'YO3',  description: 'Triple yarn over lace',      category: SymbolCategory.lace),
    KnitSymbol(id: 'cyof',      unicode: '↺', name: 'CYOF',         abbr: 'CYOF', description: 'Circular yarn over front',   category: SymbolCategory.lace),
    KnitSymbol(id: 'cyob',      unicode: '↻', name: 'CYOB',         abbr: 'CYOB', description: 'Circular yarn over back',    category: SymbolCategory.lace),
    KnitSymbol(id: 'dyo_dec',   unicode: '⊛', name: 'Double YO dec',abbr: 'DYD',  description: 'Double yarn over decrease',  category: SymbolCategory.lace),
    KnitSymbol(id: 'chain_yo',  unicode: '⋈', name: 'Chain YO',     abbr: 'CYO',  description: 'Chained yarn over',          category: SymbolCategory.lace),
    KnitSymbol(id: 'lace_hole', unicode: '⋇', name: 'Lace hole',    abbr: 'LH',   description: 'Lace hole (double)',         category: SymbolCategory.lace),
    KnitSymbol(id: 'fan',       unicode: '❋', name: 'Fan',          abbr: 'Fan',  description: 'Fan stitch',                 category: SymbolCategory.lace),
    KnitSymbol(id: 'shell',     unicode: '⌘', name: 'Shell',        abbr: 'Shl',  description: 'Shell stitch',               category: SymbolCategory.lace),
    KnitSymbol(id: 'picot',     unicode: '◠', name: 'Picot',        abbr: 'Pic',  description: 'Picot stitch',               category: SymbolCategory.lace),
    KnitSymbol(id: 'butterfly', unicode: '❆', name: 'Butterfly',    abbr: 'But',  description: 'Butterfly stitch',           category: SymbolCategory.lace),
    KnitSymbol(id: 'lace_edge', unicode: '≈', name: 'Lace edge',    abbr: 'LE',   description: 'Lace edge stitch',           category: SymbolCategory.lace),
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
