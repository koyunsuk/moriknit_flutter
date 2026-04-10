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
    pk: Color(0xFF9061F9), pkD: Color(0xFF6D28D9), pkL: Color(0x249061F9),
    lv: Color(0xFFA78BFA), lvD: Color(0xFF7C3AED), lvL: Color(0x24A78BFA),
    lm: Color(0xFFDDD6FE), lmD: Color(0xFFC4B5FD), lmG: Color(0x57DDD6FE),
    og: Color(0xFFEC4899),
    tx: Color(0xFF1E1B4B), tx2: Color(0xFF5B4E8A), mu: Color(0xFF9575CD),
    bg: Color(0xFFFCFAFF), gx: Color(0xD9FAF8FF), bd: Color(0xE8E0D5F5), bd2: Color(0x309061F9),
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

  static const moyangi = AppThemeColors(
    pk: Color(0xFFFF8C69), pkD: Color(0xFFE25C35), pkL: Color(0x24FF8C69),
    lv: Color(0xFFFFB39A), lvD: Color(0xFFFF7043), lvL: Color(0x24FFB39A),
    lm: Color(0xFFFFD9C8), lmD: Color(0xFFFFAA8A), lmG: Color(0x57FFD9C8),
    og: Color(0xFFFF6B35),
    tx: Color(0xFF3D1505), tx2: Color(0xFF7A3020), mu: Color(0xFFBB8070),
    bg: Color(0xFFFFF5F0), gx: Color(0xD9FFF8F5), bd: Color(0xE8FFDDD0), bd2: Color(0x30FF8C69),
  );

  static const jwiChuni = AppThemeColors(
    pk: Color(0xFF4A6FA5), pkD: Color(0xFF2D4E7E), pkL: Color(0x204A6FA5),
    lv: Color(0xFF6A8EBF), lvD: Color(0xFF3D5E88), lvL: Color(0x206A8EBF),
    lm: Color(0xFFB0C4DE), lmD: Color(0xFF708BA8), lmG: Color(0x57B0C4DE),
    og: Color(0xFFE07B52),
    tx: Color(0xFF1A2030), tx2: Color(0xFF4A5870), mu: Color(0xFF8A9BB0),
    bg: Color(0xFFF0F3F7), gx: Color(0xD9F5F7FB), bd: Color(0xE8CDD6E8), bd2: Color(0x304A6FA5),
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

  static const chocoNyangi = AppThemeColors(
    pk: Color(0xFF7B4A2F),
    pkD: Color(0xFF4A2919),
    pkL: Color(0x247B4A2F),
    lv: Color(0xFF9B6B52),
    lvD: Color(0xFF7B4A2F),
    lvL: Color(0x209B6B52),
    lm: Color(0xFFF6EEDF),
    lmD: Color(0xFFD9C3A3),
    lmG: Color(0x57F6EEDF),
    og: Color(0xFF3D1508),
    tx: Color(0xFF2C1A13),
    tx2: Color(0xFF6E5A52),
    mu: Color(0xFFA4938B),
    bg: Color(0xFFFFFBF4),
    gx: Color(0xD9FFFDF9),
    bd: Color(0xE8E8DBCC),
    bd2: Color(0x407B4A2F),
  );

  static const moriYellow = AppThemeColors(
    pk: Color(0xFFF59E0B), pkD: Color(0xFFB45309), pkL: Color(0x20F59E0B),
    lv: Color(0xFFFBBF24), lvD: Color(0xFFD97706), lvL: Color(0x20FBBF24),
    lm: Color(0xFFFDE68A), lmD: Color(0xFFFCD34D), lmG: Color(0x57FDE68A),
    og: Color(0xFFD97706),
    tx: Color(0xFF1C1917), tx2: Color(0xFF44403C), mu: Color(0xFF78716C),
    bg: Color(0xFFFFFBEB), gx: Color(0xD9FFFDF5), bd: Color(0xE8FDE68A), bd2: Color(0x30F59E0B),
  );

  static const moriNavy = AppThemeColors(
    pk: Color(0xFF1E40AF), pkD: Color(0xFF1E3A8A), pkL: Color(0x201E40AF),
    lv: Color(0xFF2563EB), lvD: Color(0xFF1D4ED8), lvL: Color(0x202563EB),
    lm: Color(0xFFBFDBFE), lmD: Color(0xFF93C5FD), lmG: Color(0x57BFDBFE),
    og: Color(0xFF0369A1),
    tx: Color(0xFF0F172A), tx2: Color(0xFF1E3A8A), mu: Color(0xFF60A5FA),
    bg: Color(0xFFF0F6FF), gx: Color(0xD9F5F9FF), bd: Color(0xE8BFDBFE), bd2: Color(0x301E40AF),
  );

  static const moriMono = AppThemeColors(
    pk: Color(0xFF374151), pkD: Color(0xFF1F2937), pkL: Color(0x20374151),
    lv: Color(0xFF6B7280), lvD: Color(0xFF4B5563), lvL: Color(0x206B7280),
    lm: Color(0xFFD1D5DB), lmD: Color(0xFF9CA3AF), lmG: Color(0x57D1D5DB),
    og: Color(0xFF4B5563),
    tx: Color(0xFF111827), tx2: Color(0xFF374151), mu: Color(0xFF9CA3AF),
    bg: Color(0xFFFFFFFF), gx: Color(0xFFFFFFFF), bd: Color(0xFFE5E7EB), bd2: Color(0xFFD1D5DB),
  );

  static AppThemeColors of(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.lavender:    return lavender;
      case AppThemeMode.earthy:      return earthy;
      case AppThemeMode.moyangi:     return moyangi;
      case AppThemeMode.jwiChuni:    return jwiChuni;
      case AppThemeMode.todori:      return todori;
      case AppThemeMode.pinkRabbit:  return pinkRabbit;
      case AppThemeMode.chocoNyangi: return chocoNyangi;
      case AppThemeMode.moriRed:     return moriRed;
      case AppThemeMode.moriGreen:   return moriGreen;
      case AppThemeMode.moriYellow:  return moriYellow;
      case AppThemeMode.moriNavy:    return moriNavy;
      case AppThemeMode.moriMono:    return moriMono;
    }
  }

  static const moriRed = AppThemeColors(
    pk: Color(0xFFDC2626), pkD: Color(0xFF991B1B), pkL: Color(0x20DC2626),
    lv: Color(0xFFEF4444), lvD: Color(0xFFB91C1C), lvL: Color(0x20EF4444),
    lm: Color(0xFFFEE2E2), lmD: Color(0xFFFCA5A5), lmG: Color(0x57FEE2E2),
    og: Color(0xFFB45309),
    tx: Color(0xFF111111), tx2: Color(0xFF555555), mu: Color(0xFF999999),
    bg: Color(0xFFFFF8E8), gx: Color(0xFFFFFCF5), bd: Color(0xFFEDE0CC), bd2: Color(0x30DC2626),
  );

  static const moriGreen = AppThemeColors(
    pk: Color(0xFF16A34A), pkD: Color(0xFF14532D), pkL: Color(0x2416A34A),
    lv: Color(0xFF4ADE80), lvD: Color(0xFF15803D), lvL: Color(0x244ADE80),
    lm: Color(0xFFBBF7D0), lmD: Color(0xFF86EFAC), lmG: Color(0x57BBF7D0),
    og: Color(0xFF65A30D),
    tx: Color(0xFF052E16), tx2: Color(0xFF166534), mu: Color(0xFF6EBF8A),
    bg: Color(0xFFF0FDF4), gx: Color(0xD9F0FFF4), bd: Color(0xE8BBF7D0), bd2: Color(0x3016A34A),
  );
}
