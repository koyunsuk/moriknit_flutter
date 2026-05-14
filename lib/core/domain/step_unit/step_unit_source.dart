/// 이슈 #687 — 공통 StepUnit 모델: 단계 출처 enum.
/// 단계로그·섹션·AI단계·템플릿 4개 개념을 통합하는 4번째 축.
enum StepUnitSource {
  editor, // 도안에디터 직접 작성
  ai, // AI 변환 결과
  template, // 빌트인·사용자 템플릿
  manual, // 프로젝트 직접 추가
  import_; // Ravelry / .mori 임포트 (예약어 회피 underscore)

  /// 직렬화용 이름. `import_` 는 `'import'` 로 매핑한다.
  String get name => this == StepUnitSource.import_
      ? 'import'
      : toString().split('.').last;

  static StepUnitSource fromName(String? n) {
    if (n == null) return StepUnitSource.manual;
    if (n == 'import') return StepUnitSource.import_;
    return StepUnitSource.values.firstWhere(
      (e) => e.name == n,
      orElse: () => StepUnitSource.manual,
    );
  }
}
