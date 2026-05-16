/// 이슈 #748 — 유튜브 링크 자동 임베드 헬퍼.
///
/// 지원 URL 패턴:
/// - https://www.youtube.com/watch?v=VIDEO_ID
/// - https://youtube.com/watch?v=VIDEO_ID
/// - https://m.youtube.com/watch?v=VIDEO_ID
/// - https://youtu.be/VIDEO_ID
/// - https://www.youtube.com/shorts/VIDEO_ID
/// - https://www.youtube.com/embed/VIDEO_ID
library;

/// 입력된 URL 또는 문자열에서 유튜브 video id를 추출합니다.
/// 유효한 id 형식(영문/숫자/언더스코어/대시, 길이 11)만 반환.
String? extractYoutubeVideoId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // youtu.be/<id>
  final shortMatch = RegExp(
    r'youtu\.be/([A-Za-z0-9_-]{11})',
  ).firstMatch(trimmed);
  if (shortMatch != null) return shortMatch.group(1);

  // youtube.com/watch?v=<id>
  final watchMatch = RegExp(
    r'[?&]v=([A-Za-z0-9_-]{11})',
  ).firstMatch(trimmed);
  if (watchMatch != null) return watchMatch.group(1);

  // youtube.com/shorts/<id>
  final shortsMatch = RegExp(
    r'youtube\.com/shorts/([A-Za-z0-9_-]{11})',
  ).firstMatch(trimmed);
  if (shortsMatch != null) return shortsMatch.group(1);

  // youtube.com/embed/<id>
  final embedMatch = RegExp(
    r'youtube\.com/embed/([A-Za-z0-9_-]{11})',
  ).firstMatch(trimmed);
  if (embedMatch != null) return embedMatch.group(1);

  return null;
}

/// 유튜브 video id의 hqdefault 썸네일 URL.
String youtubeThumbnailUrl(String videoId) =>
    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

/// 유튜브 표준 시청 URL.
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';
