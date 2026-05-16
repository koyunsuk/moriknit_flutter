class Routes {
  static const splash = '/';
  static const landing = '/landing';
  static const login = '/login';
  static const home = '/home';
  static const swatchList = '/swatch';
  static const swatchInput = '/swatch/input';
  // 이슈 #723 — 스와치 그룹
  static const swatchGroups = '/swatch/groups';
  static const projectList = '/project';
  static const projectAllList = '/project/all';
  static const projectInput = '/project/input';
  static const projectPatterns = '/project/patterns';
  static const tools = '/tools';
  static const toolsPatterns = '/tools/patterns';
  static const toolsPattern = '/tools/pattern';
  static const toolsPatternViewer = '/tools/pattern-viewer';
  static const toolsGauge = '/tools/gauge';
  static const toolsCourse = '/tools/course';
  static const toolsEncyclopedia = '/tools/encyclopedia';
  static const toolsMemo = '/tools/memo';
  static const toolsFreeTimer = '/tools/free-timer';
  static const toolsTimeDashboard = '/tools/time-dashboard';
  static const swatchTimer = '/swatch/:id/timer';
  static const community = '/community';
  static const market = '/market';
  // 이슈 #713 — 내 마켓 대시보드 (Shell 내부 경로로 하단 탭바 유지)
  static const marketDashboard = '/market/dashboard';
  static const my = '/my';
  static const needles = '/my/needles';
  static const accessories = '/my/accessories';
  static const books = '/my/books';
  static const photoAlbum = '/my/photo-album';
  static const accessoryDetail = '/accessory-detail/:id';
  static const counterList = '/counters';
  static const counter = '/counter/:id';
  static const admin = '/admin';
  static const messenger = '/messenger';
  static const templateList = '/templates';
  static const templateEditor = '/templates/editor';
  static const templateDetail = '/templates/detail';
  static const dm = '/dm';
  static const dmChat = '/dm/:roomId';
  static const yarnDetail = '/yarn-detail/:id';
  static const needleDetail = '/needle-detail/:id';
  static const ravelry = '/tools/ravelry';
  static const etsy = '/tools/etsy';
  static const dropbox = '/tools/dropbox';
  static const dropboxExplorer = '/tools/dropbox/explorer';
  // 이슈 #703 — 외부 클라우드 확장 (Google Drive·iCloud·OneDrive)
  static const googleDrive = '/tools/google-drive';
  static const iCloud = '/tools/icloud';
  static const oneDrive = '/tools/onedrive';
  // 외부 연결 UI 단계 정리 — 클라우드 통합 허브
  static const cloudHub = '/tools/cloud-hub';
  static const toolsNeedleSize = '/tools/needle-size';
  static const toolsMeasure = '/tools/measure';
  static const toolsPatternConverter = '/tools/pattern-converter';
  static const toolsPatternTranslator = '/tools/pattern-translator';
  static const toolsMyParsedPatterns = '/tools/my-parsed-patterns';
  static const toolsPatternGate = '/tools/pattern-gate';
  // 이슈 #660 Phase 2 — 통합 파일 탐색기 (외부 PDF/이미지 다중 임포트)
  static const toolsFileExplorer = '/tools/file-explorer';
  // 이슈 #664 — 패턴 생성기 (래글런 도안 + SVG 도식 + 출판용 PDF)
  static const toolsPatternGenerator = '/tools/pattern-generator';
  // 이슈 #704 Phase 4 — 동기화 충돌 인박스
  static const conflictInbox = '/sync/conflicts';
  // 이슈 #687 — 단계 청사진(StepBlueprint) 편집 화면
  static const stepBlueprintEditor = '/blueprints/:id/edit';
}
