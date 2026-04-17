/// 뜨개 기호 SVG 데이터 — 72개 인라인 SVG (viewBox 0 0 24 24)
/// MIT 라이선스 심볼 참조 + 독자적 구현 (marnen/knitting_symbols 컨셉)
const Map<String, String> kKnitSymbolSvgData = {
  // ── BASIC ────────────────────────────────────────────────────────────────
  'k': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="2" width="20" height="20" stroke="#1A1A2E" stroke-width="1.5" fill="none" rx="1"/>'
      '</svg>',

  'p': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="2" width="20" height="20" fill="#1A1A2E" rx="1"/>'
      '</svg>',

  'empty': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="6" y1="12" x2="18" y2="12" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '</svg>',

  'yo': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="7" stroke="#1A1A2E" stroke-width="2" fill="none"/>'
      '</svg>',

  'sl_k': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 4 L12 18 L20 4" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'sl_p': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 20 L12 6 L20 20" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'k_tbl': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="2" width="20" height="20" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<line x1="2" y1="2" x2="22" y2="22" stroke="#1A1A2E" stroke-width="1.5"/>'
      '<line x1="22" y1="2" x2="2" y2="22" stroke="#1A1A2E" stroke-width="1.5"/>'
      '</svg>',

  'p_tbl': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="2" width="20" height="20" fill="#3A3A5E" rx="1"/>'
      '<line x1="2" y1="2" x2="22" y2="22" stroke="white" stroke-width="1.5"/>'
      '<line x1="22" y1="2" x2="2" y2="22" stroke="white" stroke-width="1.5"/>'
      '</svg>',

  'k_thru': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="20" x2="12" y2="5" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M7 9 L12 4 L17 9" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'dyo': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="9" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="12" cy="12" r="4.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'no_st': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="5" y="5" width="14" height="14" fill="#9CA3AF" rx="1"/>'
      '</svg>',

  'edge': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="2" x2="12" y2="22" stroke="#1A1A2E" stroke-width="3" stroke-linecap="round"/>'
      '</svg>',

  // ── DECREASE ─────────────────────────────────────────────────────────────
  'k2tog': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '</svg>',

  'ssk': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '</svg>',

  'cdd': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 20 L12 4 L20 20" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'k3tog': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="2" y1="3" x2="18" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="6" y1="3" x2="22" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  'sssk': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="18" y1="3" x2="2" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="22" y1="3" x2="6" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  'skp': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '<circle cx="20" cy="4" r="3" fill="#1A1A2E"/>'
      '</svg>',

  'sl1k2togpsso': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M3 21 L12 3 L21 21" stroke="#1A1A2E" stroke-width="2.5" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '<line x1="12" y1="3" x2="12" y2="13" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '</svg>',

  'k2tog_tbl': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2.5"'
      ' stroke-linecap="round" stroke-dasharray="5 3"/>'
      '</svg>',

  'p2tog': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="12" cy="12" r="2.5" fill="#1A1A2E"/>'
      '</svg>',

  'p2tog_tbl': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2"'
      ' stroke-linecap="round" stroke-dasharray="4 2"/>'
      '<circle cx="12" cy="12" r="2.5" fill="#1A1A2E"/>'
      '</svg>',

  'p3tog': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="2" y1="3" x2="18" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="6" y1="3" x2="22" y2="21" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="12" cy="12" r="2.5" fill="#1A1A2E"/>'
      '</svg>',

  'cdd_p': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 20 L12 4 L20 20" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '<circle cx="12" cy="12" r="2.5" fill="#1A1A2E"/>'
      '</svg>',

  // ── INCREASE ─────────────────────────────────────────────────────────────
  'm1l': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="20" x2="12" y2="4" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M17 9 L12 4 L7 9" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '<line x1="6" y1="12" x2="12" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'm1r': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="20" x2="12" y2="4" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M17 9 L12 4 L7 9" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '<line x1="18" y1="12" x2="12" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'kfb': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="4" x2="12" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="4" y1="12" x2="20" y2="12" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  'pfb': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="2" y="2" width="20" height="20" fill="#3A3A6E" rx="1"/>'
      '<line x1="12" y1="5" x2="12" y2="19" stroke="white" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="5" y1="12" x2="19" y2="12" stroke="white" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  'k1yo k1': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<line x1="2" y1="12" x2="7" y2="12" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="17" y1="12" x2="22" y2="12" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  'm1p': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="20" x2="12" y2="4" stroke="#1A1A2E" stroke-width="2"'
      ' stroke-linecap="round" stroke-dasharray="4 2"/>'
      '<path d="M17 9 L12 4 L7 9" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'kfbf': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="4" x2="12" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="4" y1="9" x2="20" y2="9" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="4" y1="15" x2="20" y2="15" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'cast_on': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 20 Q12 2 20 20" stroke="#1A1A2E" stroke-width="2" fill="none" stroke-linecap="round"/>'
      '</svg>',

  'lift_l': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="18" y1="20" x2="6" y2="6" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M6 6 L11 6 L6 11" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'lift_r': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="6" y1="20" x2="18" y2="6" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M18 6 L13 6 L18 11" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'm1': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="17" text-anchor="middle" font-size="15" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">M</text>'
      '</svg>',

  'dbl_inc': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="8" y1="20" x2="8" y2="4" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="16" y1="20" x2="16" y2="4" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M4 9 L8 4 L12 9" stroke="#1A1A2E" stroke-width="1.5" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '<path d="M12 9 L16 4 L20 9" stroke="#1A1A2E" stroke-width="1.5" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  // ── CABLE ─────────────────────────────────────────────────────────────────
  'c2f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="white" stroke-width="4"/>'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<text x="12" y="15" text-anchor="middle" font-size="7" font-weight="bold"'
      ' fill="#6B21A8" font-family="sans-serif">C2F</text>'
      '</svg>',

  'c2b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="white" stroke-width="4"/>'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<text x="12" y="15" text-anchor="middle" font-size="7" font-weight="bold"'
      ' fill="#6B21A8" font-family="sans-serif">C2B</text>'
      '</svg>',

  't2f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="white" stroke-width="4"/>'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round" stroke-dasharray="3 2"/>'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '</svg>',

  't2b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="white" stroke-width="4"/>'
      '<line x1="4" y1="4" x2="20" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="20" y1="4" x2="4" y2="20" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round" stroke-dasharray="3 2"/>'
      '</svg>',

  'c3f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="10" text-anchor="middle" font-size="8" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C3F</text>'
      '<line x1="4" y1="12" x2="20" y2="12" stroke="#1A1A2E" stroke-width="1" stroke-dasharray="2 2"/>'
      '<path d="M6 22 L12 14 L18 22" stroke="#1A1A2E" stroke-width="1.5" fill="none" stroke-linecap="round"/>'
      '</svg>',

  'c3b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="10" text-anchor="middle" font-size="8" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C3B</text>'
      '<line x1="4" y1="12" x2="20" y2="12" stroke="#1A1A2E" stroke-width="1" stroke-dasharray="2 2"/>'
      '<path d="M6 14 L12 22 L18 14" stroke="#1A1A2E" stroke-width="1.5" fill="none" stroke-linecap="round"/>'
      '</svg>',

  'c4f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="10" text-anchor="middle" font-size="8" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C4F</text>'
      '<line x1="4" y1="12" x2="9" y2="20" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="20" y1="12" x2="15" y2="20" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="4" y1="20" x2="9" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="20" y1="20" x2="15" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'c4b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="10" text-anchor="middle" font-size="8" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C4B</text>'
      '<line x1="4" y1="12" x2="9" y2="20" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="20" y1="12" x2="15" y2="20" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="9" y1="20" x2="20" y2="12" stroke="white" stroke-width="3"/>'
      '<line x1="9" y1="20" x2="20" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'c6f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="16" text-anchor="middle" font-size="9" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C6F</text>'
      '</svg>',

  'c6b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="16" text-anchor="middle" font-size="9" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">C6B</text>'
      '</svg>',

  't3f': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="16" text-anchor="middle" font-size="9" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">T3F</text>'
      '</svg>',

  't3b': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<text x="12" y="16" text-anchor="middle" font-size="9" font-weight="bold"'
      ' fill="#1A1A2E" font-family="sans-serif">T3B</text>'
      '</svg>',

  // ── SPECIAL ───────────────────────────────────────────────────────────────
  'bobble': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="8" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="12" cy="12" r="4" fill="#1A1A2E"/>'
      '</svg>',

  'nupp': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="7" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="12" cy="12" r="2" fill="#1A1A2E"/>'
      '<circle cx="12" cy="6" r="1.5" fill="#1A1A2E"/>'
      '<circle cx="12" cy="18" r="1.5" fill="#1A1A2E"/>'
      '</svg>',

  'popcorn': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 2 L14 9 L22 9 L16 14 L18 22 L12 17 L6 22 L8 14 L2 9 L10 9 Z"'
      ' stroke="#1A1A2E" stroke-width="1.5" fill="none" stroke-linejoin="round"/>'
      '</svg>',

  'bullion': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="8" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<line x1="12" y1="4" x2="12" y2="20" stroke="#1A1A2E" stroke-width="1"/>'
      '<line x1="4" y1="12" x2="20" y2="12" stroke="#1A1A2E" stroke-width="1"/>'
      '<circle cx="12" cy="12" r="2.5" fill="#1A1A2E"/>'
      '</svg>',

  'smocking': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 12 Q8 6 12 12 Q16 18 20 12" stroke="#1A1A2E" stroke-width="2"'
      ' fill="none" stroke-linecap="round"/>'
      '<path d="M4 8 Q8 2 12 8 Q16 14 20 8" stroke="#1A1A2E" stroke-width="1.5"'
      ' fill="none" stroke-linecap="round"/>'
      '</svg>',

  'bead': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="8" fill="#1A1A2E"/>'
      '<circle cx="9" cy="9" r="2" fill="white" opacity="0.4"/>'
      '</svg>',

  'drop': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="2" x2="12" y2="22" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<path d="M7 18 L12 22 L17 18" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'elongated': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="12" y1="2" x2="12" y2="22" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="7" y1="6" x2="17" y2="6" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="7" y1="18" x2="17" y2="18" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'gathered': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="4" y1="8" x2="20" y2="8" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="4" y1="12" x2="20" y2="12" stroke="#1A1A2E" stroke-width="2" stroke-linecap="round"/>'
      '<line x1="4" y1="16" x2="20" y2="16" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  'wrapped': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="8" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<path d="M12 4 Q20 12 12 20 Q4 12 12 4" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'twisted': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<line x1="5" y1="5" x2="19" y2="19" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '<line x1="19" y1="5" x2="5" y2="19" stroke="#1A1A2E" stroke-width="2.5" stroke-linecap="round"/>'
      '</svg>',

  'embroidery': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="4" fill="#1A1A2E"/>'
      '<line x1="12" y1="2" x2="12" y2="8" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="12" y1="16" x2="12" y2="22" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="2" y1="12" x2="8" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="16" y1="12" x2="22" y2="12" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="5" y1="5" x2="9" y2="9" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="15" y1="15" x2="19" y2="19" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="19" y1="5" x2="15" y2="9" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '<line x1="5" y1="19" x2="9" y2="15" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',

  // ── LACE ──────────────────────────────────────────────────────────────────
  'yo2': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="8" cy="12" r="4.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="16" cy="12" r="4.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'yo3': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="5" cy="12" r="3.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="12" cy="12" r="3.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="19" cy="12" r="3.5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'cyof': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="7" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<path d="M12 5 A7 7 0 0 1 19 12" stroke="#1A1A2E" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
      '</svg>',

  'cyob': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="7" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<path d="M12 5 A7 7 0 0 0 5 12" stroke="#1A1A2E" stroke-width="2.5" fill="none" stroke-linecap="round"/>'
      '</svg>',

  'dyo_dec': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="9" r="5" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<path d="M8 16 L12 20 L16 16" stroke="#1A1A2E" stroke-width="2" fill="none"'
      ' stroke-linejoin="round" stroke-linecap="round"/>'
      '</svg>',

  'chain_yo': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="7" cy="12" r="4" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<circle cx="17" cy="12" r="4" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '<line x1="11" y1="12" x2="13" y2="12" stroke="#1A1A2E" stroke-width="1.5"/>'
      '</svg>',

  'lace_hole': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="12" cy="12" r="7" stroke="#1A1A2E" stroke-width="2" fill="none"/>'
      '<circle cx="12" cy="12" r="3" stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'fan': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 20 L4 8 Q12 2 20 8 Z" stroke="#1A1A2E" stroke-width="1.5" fill="none"'
      ' stroke-linejoin="round"/>'
      '<line x1="12" y1="20" x2="12" y2="8" stroke="#1A1A2E" stroke-width="1"/>'
      '<line x1="12" y1="20" x2="6" y2="10" stroke="#1A1A2E" stroke-width="1"/>'
      '<line x1="12" y1="20" x2="18" y2="10" stroke="#1A1A2E" stroke-width="1"/>'
      '</svg>',

  'shell': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 20 Q4 14 4 8 Q12 4 20 8 Q20 14 12 20 Z"'
      ' stroke="#1A1A2E" stroke-width="1.5" fill="none" stroke-linejoin="round"/>'
      '</svg>',

  'picot': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 18 Q8 6 12 18 Q16 6 20 18" stroke="#1A1A2E" stroke-width="2"'
      ' fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
      '</svg>',

  'butterfly': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 12 Q4 4 4 12 Q4 20 12 12 Q20 4 20 12 Q20 20 12 12"'
      ' stroke="#1A1A2E" stroke-width="1.5" fill="none"/>'
      '</svg>',

  'lace_edge': '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M2 18 Q5 10 8 18 Q11 10 14 18 Q17 10 20 18 L22 18" stroke="#1A1A2E"'
      ' stroke-width="2" fill="none" stroke-linecap="round"/>'
      '<line x1="2" y1="8" x2="22" y2="8" stroke="#1A1A2E" stroke-width="1.5" stroke-linecap="round"/>'
      '</svg>',
};
