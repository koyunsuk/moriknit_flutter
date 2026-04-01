import 'package:flutter/material.dart';

import '../../providers/theme_provider.dart';

class AppThemeColors {
  final Color pk, pkD, pkL;
  final Color lv, lvD, lvL;
  final Color lm, lmD, lmG;
  final Color og;
  final Color tx, tx2, mu;
  final Color bg, gx, bd, bd2;

  const AppThemeColors({
    required this.pk,
    required this.pkD,
    required this.pkL,
    required this.lv,
    required this.lvD,
    required this.lvL,
    required this.lm,
    required this.lmD,
    required this.lmG,
    required this.og,
    required this.tx,
    required this.tx2,
    required this.mu,
    required this.bg,
    required this.gx,
    required this.bd,
    required this.bd2,
  });

  static const lavender = AppThemeColors(
    pk: Color(0xFFF472B6),
    pkD: Color(0xFFBE185D),
    pkL: Color(0x21F472B6),
    lv: Color(0xFFC084FC),
    lvD: Color(0xFF7C3AED),
    lvL: Color(0x21C084FC),
    lm: Color(0xFFA3E635),
    lmD: Color(0xFF65A30D),
    lmG: Color(0x57A3E635),
    og: Color(0xFFFB923C),
    tx: Color(0xFF1A1A2E),
    tx2: Color(0xFF6B7280),
    mu: Color(0xFF9CA3AF),
    bg: Color(0xFFFCF0FF),
    gx: Color(0xD9FFFAFF),
    bd: Color(0xE8EDE9F5),
    bd2: Color(0x30C084FC),
  );

  static const earthy = AppThemeColors(
    pk: Color(0xFFC96F4A),
    pkD: Color(0xFF8E4B31),
    pkL: Color(0x21C96F4A),
    lv: Color(0xFF8E9A6E),
    lvD: Color(0xFF5F694B),
    lvL: Color(0x218E9A6E),
    lm: Color(0xFFD7C4A6),
    lmD: Color(0xFF8C7458),
    lmG: Color(0x57D7C4A6),
    og: Color(0xFFB98558),
    tx: Color(0xFF2C241E),
    tx2: Color(0xFF675849),
    mu: Color(0xFF9B8E80),
    bg: Color(0xFFF5EEE4),
    gx: Color(0xD9FFFDFC),
    bd: Color(0xE8F1E8DE),
    bd2: Color(0x30BCA58D),
  );

  static const monochrome = AppThemeColors(
    pk: Color(0xFF111111),
    pkD: Color(0xFF000000),
    pkL: Color(0x21111111),
    lv: Color(0xFF444444),
    lvD: Color(0xFF222222),
    lvL: Color(0x21444444),
    lm: Color(0xFF888888),
    lmD: Color(0xFF555555),
    lmG: Color(0x57888888),
    og: Color(0xFF333333),
    tx: Color(0xFF0A0A0A),
    tx2: Color(0xFF555555),
    mu: Color(0xFF888888),
    bg: Color(0xFFF8F8F8),
    gx: Color(0xD9FFFFFF),
    bd: Color(0xE8E0E0E0),
    bd2: Color(0x30999999),
  );

  static const moyangi = AppThemeColors(
    pk: Color(0xFFFF8FB1),
    pkD: Color(0xFFD94F7D),
    pkL: Color(0x20FF8FB1),
    lv: Color(0xFF8E7BFF),
    lvD: Color(0xFF5E43D6),
    lvL: Color(0x208E7BFF),
    lm: Color(0xFF78DCC3),
    lmD: Color(0xFF2C9B7F),
    lmG: Color(0x5778DCC3),
    og: Color(0xFFFFB36B),
    tx: Color(0xFF25131B),
    tx2: Color(0xFF7B5566),
    mu: Color(0xFFB18A98),
    bg: Color(0xFFFFF1F6),
    gx: Color(0xD9FFF9FC),
    bd: Color(0xE8F3D9E4),
    bd2: Color(0x308E7BFF),
  );

  static const jwiChuni = AppThemeColors(
    pk: Color(0xFF8FA9D8),
    pkD: Color(0xFF536F9F),
    pkL: Color(0x208FA9D8),
    lv: Color(0xFFB9A289),
    lvD: Color(0xFF7C6248),
    lvL: Color(0x20B9A289),
    lm: Color(0xFFD7C2A3),
    lmD: Color(0xFF9F805B),
    lmG: Color(0x57D7C2A3),
    og: Color(0xFFB17C57),
    tx: Color(0xFF221A1A),
    tx2: Color(0xFF685C63),
    mu: Color(0xFFA1979D),
    bg: Color(0xFFF5F3F0),
    gx: Color(0xD9FCFBFA),
    bd: Color(0xE8DDD7D1),
    bd2: Color(0x308FA9D8),
  );

  static const todori = AppThemeColors(
    pk: Color(0xFFF4B942),
    pkD: Color(0xFFC67A12),
    pkL: Color(0x20F4B942),
    lv: Color(0xFFB56A2F),
    lvD: Color(0xFF7D4314),
    lvL: Color(0x24B56A2F),
    lm: Color(0xFFD9A441),
    lmD: Color(0xFF9D6713),
    lmG: Color(0x57D9A441),
    og: Color(0xFF8E4E20),
    tx: Color(0xFF2F1B0E),
    tx2: Color(0xFF7B5736),
    mu: Color(0xFFB18B63),
    bg: Color(0xFFFFF4E2),
    gx: Color(0xD9FFF8EC),
    bd: Color(0xE8EBCB9A),
    bd2: Color(0x30B56A2F),
  );

  static const pinkRabbit = AppThemeColors(
    pk: Color(0xFFFF6FB5),
    pkD: Color(0xFFD81B78),
    pkL: Color(0x24FF6FB5),
    lv: Color(0xFFFFA6D6),
    lvD: Color(0xFFE255A0),
    lvL: Color(0x24FFA6D6),
    lm: Color(0xFFFFC6E5),
    lmD: Color(0xFFFF78BF),
    lmG: Color(0x57FFC6E5),
    og: Color(0xFFFF8CC8),
    tx: Color(0xFF3A1630),
    tx2: Color(0xFF8A5679),
    mu: Color(0xFFB98DAA),
    bg: Color(0xFFFFF1F8),
    gx: Color(0xD9FFF9FC),
    bd: Color(0xE8F8D8EA),
    bd2: Color(0x30FF6FB5),
  );

  static const creamSnail = AppThemeColors(
    pk: Color(0xFF4B6FD6),
    pkD: Color(0xFF2447A8),
    pkL: Color(0x204B6FD6),
    lv: Color(0xFF79B8FF),
    lvD: Color(0xFF2D7FEA),
    lvL: Color(0x2479B8FF),
    lm: Color(0xFFF6EDD9),
    lmD: Color(0xFFD6C29A),
    lmG: Color(0x57F6EDD9),
    og: Color(0xFF8EA7E8),
    tx: Color(0xFF24314F),
    tx2: Color(0xFF6B7691),
    mu: Color(0xFFA3A9B8),
    bg: Color(0xFFFFFCF5),
    gx: Color(0xD9FFFDFC),
    bd: Color(0xE879B8FF),
    bd2: Color(0x5079B8FF),
  );

  static const jimungmungi = AppThemeColors(
    pk: Color(0xFF7B4DFF),
    pkD: Color(0xFF4322A3),
    pkL: Color(0x247B4DFF),
    lv: Color(0xFF1E1E24),
    lvD: Color(0xFF000000),
    lvL: Color(0x1F1E1E24),
    lm: Color(0xFFF4F2FF),
    lmD: Color(0xFFD8D2F0),
    lmG: Color(0x57F4F2FF),
    og: Color(0xFFA987FF),
    tx: Color(0xFF18141F),
    tx2: Color(0xFF5D5670),
    mu: Color(0xFF9B93AE),
    bg: Color(0xFFF7F4FF),
    gx: Color(0xD9FFFEFF),
    bd: Color(0xE8DED7F8),
    bd2: Color(0x407B4DFF),
  );

  static const chocoNyangi = AppThemeColors(
    pk: Color(0xFF7B4A2F),
    pkD: Color(0xFF4A2919),
    pkL: Color(0x247B4A2F),
    lv: Color(0xFF355C9A),
    lvD: Color(0xFF213B66),
    lvL: Color(0x20355C9A),
    lm: Color(0xFFF6EEDF),
    lmD: Color(0xFFD9C3A3),
    lmG: Color(0x57F6EEDF),
    og: Color(0xFF5B2E1A),
    tx: Color(0xFF2C1A13),
    tx2: Color(0xFF6E5A52),
    mu: Color(0xFFA4938B),
    bg: Color(0xFFFFFBF4),
    gx: Color(0xD9FFFDF9),
    bd: Color(0xE8E8DBCC),
    bd2: Color(0x40355C9A),
  );

  static const eunsulNyangi = AppThemeColors(
    pk: Color(0xFFFF9F1C),
    pkD: Color(0xFFC96A00),
    pkL: Color(0x24FF9F1C),
    lv: Color(0xFFA7E635),
    lvD: Color(0xFF6AA300),
    lvL: Color(0x24A7E635),
    lm: Color(0xFF2FAF5B),
    lmD: Color(0xFF1E7A3F),
    lmG: Color(0x572FAF5B),
    og: Color(0xFFFFC35C),
    tx: Color(0xFF21301D),
    tx2: Color(0xFF5F715A),
    mu: Color(0xFF9AAA93),
    bg: Color(0xFFFBFFF5),
    gx: Color(0xD9FEFFF9),
    bd: Color(0xE8D6EDBE),
    bd2: Color(0x40A7E635),
  );

  static AppThemeColors of(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.lavender:    return lavender;
      case AppThemeMode.earthy:      return earthy;
      case AppThemeMode.monochrome:  return monochrome;
      case AppThemeMode.moyangi:     return moyangi;
      case AppThemeMode.jwiChuni:    return jwiChuni;
      case AppThemeMode.todori:      return todori;
      case AppThemeMode.pinkRabbit:  return pinkRabbit;
      case AppThemeMode.creamSnail:  return creamSnail;
      case AppThemeMode.jimungmungi: return jimungmungi;
      case AppThemeMode.chocoNyangi: return chocoNyangi;
      case AppThemeMode.eunsulNyangi: return eunsulNyangi;
    }
  }
}
