class CommunityChannelLink {
  final String title;
  final String handle;
  final String url;
  final String summary;
  final String cta;

  const CommunityChannelLink({
    required this.title,
    required this.handle,
    required this.url,
    required this.summary,
    required this.cta,
  });
}

class CommunityContentItem {
  final String section;
  final String title;
  final String caption;
  final String badge;
  final String actionLabel;
  final String url;

  const CommunityContentItem({
    required this.section,
    required this.title,
    required this.caption,
    required this.badge,
    required this.actionLabel,
    required this.url,
  });
}

class CommunityChannelRepository {
  static List<CommunityChannelLink> channels(bool isKorean) {
    if (isKorean) {
      return const [
        CommunityChannelLink(
          title: 'MoriKnit Instagram',
          handle: '@moriknit',
          url: 'https://www.instagram.com/moriknit/',
          summary: '릴스, 완성작 사진, 뜨개 무드보드처럼 짧고 빠르게 보는 콘텐츠 채널',
          cta: '인스타그램 열기',
        ),
        CommunityChannelLink(
          title: 'MoriKnit YouTube',
          handle: '@moriknit',
          url: 'https://www.youtube.com/@moriknit',
          summary: '튜토리얼, 브이로그, 도안 설명처럼 길게 체험하는 영상 채널',
          cta: '유튜브 열기',
        ),
        CommunityChannelLink(
          title: 'MoriKnit Blog',
          handle: 'moriknit.com/blog',
          url: 'https://moriknit.com/blog',
          summary: '정리된 팁, 프로젝트 기록, 추천 도구를 읽기 좋은 포맷으로 보는 채널',
          cta: '블로그 열기',
        ),
      ];
    }

    return const [
      CommunityChannelLink(
        title: 'MoriKnit Instagram',
        handle: '@moriknit',
        url: 'https://www.instagram.com/moriknit/',
        summary: 'Quick reels, finished pieces, and visual knitting moodboards.',
        cta: 'Open Instagram',
      ),
      CommunityChannelLink(
        title: 'MoriKnit YouTube',
        handle: '@moriknit',
        url: 'https://www.youtube.com/@moriknit',
        summary: 'Long-form tutorials, vlogs, and pattern walkthrough videos.',
        cta: 'Open YouTube',
      ),
      CommunityChannelLink(
        title: 'MoriKnit Blog',
        handle: 'moriknit.com/blog',
        url: 'https://moriknit.com/blog',
        summary: 'Readable tips, project notes, and curated knitting tools.',
        cta: 'Open Blog',
      ),
    ];
  }

  static List<CommunityContentItem> highlights(bool isKorean) {
    if (isKorean) {
      return const [
        CommunityContentItem(
          section: 'Instagram Reel',
          title: '스와치 기록 전후 비교 릴스',
          caption: '짧은 영상으로 스와치 저장 흐름과 결과를 빠르게 체험해볼 수 있어요.',
          badge: 'Quick',
          actionLabel: '릴스 보러가기',
          url: 'https://www.instagram.com/moriknit/',
        ),
        CommunityContentItem(
          section: 'YouTube Video',
          title: 'MoriKnit 프로젝트 기록 튜토리얼',
          caption: '프로젝트, 카운터, 스와치를 실제 작업 흐름으로 길게 따라가볼 수 있어요.',
          badge: 'Deep Dive',
          actionLabel: '영상 보기',
          url: 'https://www.youtube.com/@moriknit',
        ),
        CommunityContentItem(
          section: 'Blog Article',
          title: '뜨개 기록을 남겨야 하는 이유',
          caption: '게이지와 프로젝트 메모를 어떻게 남기면 다음 작업이 쉬워지는지 읽어볼 수 있어요.',
          badge: 'Read',
          actionLabel: '아티클 보기',
          url: 'https://moriknit.com/blog',
        ),
      ];
    }

    return const [
      CommunityContentItem(
        section: 'Instagram Reel',
        title: 'Before and after swatch reel',
        caption: 'A quick look at how swatches are saved and compared in practice.',
        badge: 'Quick',
        actionLabel: 'Watch reel',
        url: 'https://www.instagram.com/moriknit/',
      ),
      CommunityContentItem(
        section: 'YouTube Video',
        title: 'MoriKnit project workflow tutorial',
        caption: 'Follow a full flow across projects, counters, and swatches.',
        badge: 'Deep Dive',
        actionLabel: 'Watch video',
        url: 'https://www.youtube.com/@moriknit',
      ),
      CommunityContentItem(
        section: 'Blog Article',
        title: 'Why knitting records matter',
        caption: 'See how gauge notes and project memos make the next project easier.',
        badge: 'Read',
        actionLabel: 'Read article',
        url: 'https://moriknit.com/blog',
      ),
    ];
  }
}
