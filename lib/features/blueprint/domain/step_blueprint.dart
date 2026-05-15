// lib/features/blueprint/domain/step_blueprint.dart
//
// 이슈 #687 (Phase G) — 신규 청사진(Blueprint) 도메인.
//
// StepUnit(개별 단계)·StepGroupMeta(섹션 메타)와 함께 도안·튜토리얼·템플릿을
// 통합 표현하는 청사진. 마켓플레이스·Fork·협업·라이선스 메타까지 포함한다.
//
// 인스턴스(사용자 진행 상태)는 별도 컬렉션(`step_runs`)에서 보유 — 본 모델은
// 청사진 메타만 책임진다.

// Firestore 직렬화 값과 enum 이름을 일치시키기 위해 의도적으로 snake_case 사용.
// ignore_for_file: constant_identifier_names

import 'step_unit_groupmeta.dart';

// ── enums ────────────────────────────────────────────────────────────────────

/// 청사진 종류.
enum BlueprintKind {
  pattern, // 도안 (가장 일반적)
  technique_guide, // 기법 가이드 (예: 매직링)
  design_tutorial, // 디자인 튜토리얼 (예: 라글란 설계)
  editor_tutorial, // 도안에디터 튜토리얼
  template; // 빌트인·사용자 템플릿

  String get name {
    switch (this) {
      case BlueprintKind.technique_guide:
        return 'technique_guide';
      case BlueprintKind.design_tutorial:
        return 'design_tutorial';
      case BlueprintKind.editor_tutorial:
        return 'editor_tutorial';
      default:
        return toString().split('.').last;
    }
  }

  static BlueprintKind fromName(String? n) {
    if (n == null) return BlueprintKind.pattern;
    return BlueprintKind.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintKind.pattern,
    );
  }
}

/// 청사진 공개 범위.
/// 마켓·커뮤니티·친구·팀별 단계적 노출 제어용.
enum BlueprintVisibility {
  draft, // 비공개 초안 (소유자만)
  private, // 비공개 (소유자만)
  team, // 팀(members) 멤버만
  friends, // 친구 (후속)
  unlisted, // 링크 보유자만
  public, // 누구나 읽기
  marketplace, // 마켓플레이스 노출 (유료)
  community_showcase; // 커뮤니티 쇼케이스

  String get name {
    switch (this) {
      case BlueprintVisibility.community_showcase:
        return 'community_showcase';
      default:
        return toString().split('.').last;
    }
  }

  static BlueprintVisibility fromName(String? n) {
    if (n == null) return BlueprintVisibility.draft;
    return BlueprintVisibility.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintVisibility.draft,
    );
  }
}

/// 청사진 제공 주체.
enum BlueprintProvider {
  official, // 모리니트 공식
  user; // 일반 사용자

  String get name => toString().split('.').last;

  static BlueprintProvider fromName(String? n) {
    if (n == null) return BlueprintProvider.user;
    return BlueprintProvider.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintProvider.user,
    );
  }
}

/// 청사진 난이도.
enum BlueprintDifficulty {
  beginner,
  intermediate,
  advanced;

  String get name => toString().split('.').last;

  static BlueprintDifficulty? fromName(String? n) {
    if (n == null) return null;
    return BlueprintDifficulty.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintDifficulty.beginner,
    );
  }
}

/// 협업 멤버 역할.
enum BlueprintMemberRole {
  admin, // 청사진 메타 관리
  editor, // 본문 편집
  tester, // 테스트(StepRun.role=tester) 진행
  commenter, // 코멘트 작성
  viewer; // 읽기만

  String get name => toString().split('.').last;

  static BlueprintMemberRole fromName(String? n) {
    if (n == null) return BlueprintMemberRole.viewer;
    return BlueprintMemberRole.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintMemberRole.viewer,
    );
  }
}

/// 검색·노출 정책.
enum BlueprintDiscoverability {
  hidden, // 검색 결과 노출 안함
  searchable, // 일반 검색 노출
  curated_only; // 큐레이션 페이지에만 노출

  String get name {
    switch (this) {
      case BlueprintDiscoverability.curated_only:
        return 'curated_only';
      default:
        return toString().split('.').last;
    }
  }

  static BlueprintDiscoverability fromName(String? n) {
    if (n == null) return BlueprintDiscoverability.searchable;
    return BlueprintDiscoverability.values.firstWhere(
      (e) => e.name == n,
      orElse: () => BlueprintDiscoverability.searchable,
    );
  }
}

/// 라이선스 종류.
enum LicenseType {
  reserved, // 모든 권리 보유
  cc0,
  cc_by,
  cc_by_nc,
  cc_by_sa,
  moriknit_official, // 모리니트 공식 라이선스
  custom; // 사용자 정의

  String get name {
    switch (this) {
      case LicenseType.cc_by:
        return 'cc_by';
      case LicenseType.cc_by_nc:
        return 'cc_by_nc';
      case LicenseType.cc_by_sa:
        return 'cc_by_sa';
      case LicenseType.moriknit_official:
        return 'moriknit_official';
      default:
        return toString().split('.').last;
    }
  }

  static LicenseType fromName(String? n) {
    if (n == null) return LicenseType.reserved;
    return LicenseType.values.firstWhere(
      (e) => e.name == n,
      orElse: () => LicenseType.reserved,
    );
  }
}

/// 가격 타입.
enum PriceType {
  free,
  paid;

  String get name => toString().split('.').last;

  static PriceType fromName(String? n) {
    if (n == null) return PriceType.free;
    return PriceType.values.firstWhere(
      (e) => e.name == n,
      orElse: () => PriceType.free,
    );
  }
}

// ── value objects ────────────────────────────────────────────────────────────

/// 라이선스 메타.
class BlueprintLicense {
  final LicenseType type;
  final bool allowModify;
  final bool allowRedistribute;
  final bool allowCommercial;
  final bool attributionRequired;
  final int? revenueSharePercent; // 0~100
  final String? customTerms;

  const BlueprintLicense({
    this.type = LicenseType.reserved,
    this.allowModify = false,
    this.allowRedistribute = false,
    this.allowCommercial = false,
    this.attributionRequired = true,
    this.revenueSharePercent,
    this.customTerms,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'allowModify': allowModify,
        'allowRedistribute': allowRedistribute,
        'allowCommercial': allowCommercial,
        'attributionRequired': attributionRequired,
        if (revenueSharePercent != null)
          'revenueSharePercent': revenueSharePercent,
        if (customTerms != null) 'customTerms': customTerms,
      };

  factory BlueprintLicense.fromMap(Map<String, dynamic> m) => BlueprintLicense(
        type: LicenseType.fromName(m['type'] as String?),
        allowModify: m['allowModify'] as bool? ?? false,
        allowRedistribute: m['allowRedistribute'] as bool? ?? false,
        allowCommercial: m['allowCommercial'] as bool? ?? false,
        attributionRequired: m['attributionRequired'] as bool? ?? true,
        revenueSharePercent: m['revenueSharePercent'] as int?,
        customTerms: m['customTerms'] as String?,
      );

  BlueprintLicense copyWith({
    LicenseType? type,
    bool? allowModify,
    bool? allowRedistribute,
    bool? allowCommercial,
    bool? attributionRequired,
    int? revenueSharePercent,
    String? customTerms,
  }) =>
      BlueprintLicense(
        type: type ?? this.type,
        allowModify: allowModify ?? this.allowModify,
        allowRedistribute: allowRedistribute ?? this.allowRedistribute,
        allowCommercial: allowCommercial ?? this.allowCommercial,
        attributionRequired: attributionRequired ?? this.attributionRequired,
        revenueSharePercent: revenueSharePercent ?? this.revenueSharePercent,
        customTerms: customTerms ?? this.customTerms,
      );
}

/// 가격 메타.
class BlueprintPrice {
  final PriceType type;
  final int? amountCents; // 1000 = 10.00
  final String? currency; // 'KRW', 'USD' ...

  const BlueprintPrice({
    this.type = PriceType.free,
    this.amountCents,
    this.currency,
  });

  bool get isFree => type == PriceType.free;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        if (amountCents != null) 'amountCents': amountCents,
        if (currency != null) 'currency': currency,
      };

  factory BlueprintPrice.fromMap(Map<String, dynamic> m) => BlueprintPrice(
        type: PriceType.fromName(m['type'] as String?),
        amountCents: m['amountCents'] as int?,
        currency: m['currency'] as String?,
      );

  BlueprintPrice copyWith({
    PriceType? type,
    int? amountCents,
    String? currency,
  }) =>
      BlueprintPrice(
        type: type ?? this.type,
        amountCents: amountCents ?? this.amountCents,
        currency: currency ?? this.currency,
      );
}

/// 발행 버전 메타.
class BlueprintPublishedVersion {
  final String version; // 'major.minor.patch'
  final DateTime publishedAt;
  final String? changelog;

  const BlueprintPublishedVersion({
    required this.version,
    required this.publishedAt,
    this.changelog,
  });

  Map<String, dynamic> toMap() => {
        'version': version,
        'publishedAt': publishedAt.toIso8601String(),
        if (changelog != null) 'changelog': changelog,
      };

  factory BlueprintPublishedVersion.fromMap(Map<String, dynamic> m) =>
      BlueprintPublishedVersion(
        version: m['version'] as String? ?? '1.0.0',
        publishedAt:
            DateTime.tryParse(m['publishedAt'] as String? ?? '') ??
                DateTime.now(),
        changelog: m['changelog'] as String?,
      );
}

// ── main entity ──────────────────────────────────────────────────────────────

/// 청사진 메인 엔티티.
///
/// 컬렉션 경로: `step_blueprints/{id}` (전역, ownerUid 필드로 소유자 식별)
class StepBlueprint {
  final String id;
  final String ownerUid;

  final String title;
  final String? titleKo;
  final String? titleEn;

  final BlueprintKind kind;
  final BlueprintVisibility visibility;
  final BlueprintLicense license;
  final BlueprintPrice? price;

  final BlueprintProvider provider;
  final BlueprintDifficulty? difficulty;

  /// (선택) 본 청사진을 만든 원본 PatternChart.id
  final String? sourcePatternChartId;

  /// (선택) 차트 자산 참조 — PatternChart 문서 id.
  /// 청사진은 단계 메타·라이선스만, 차트(grid 등)는 기존 PatternChart에 둔다.
  final String? chartAssetId;

  /// Fork 원본 (있으면 forked).
  final String? fromBlueprintId;
  final String? fromAttribution; // 'by @koyunsuk'

  /// 학습 선행 청사진 (technique_guide 등).
  final List<String> prerequisiteBlueprintIds;

  /// nested 그룹(섹션) 메타. 실제 단위는 subcollection `units`.
  final List<StepGroupMeta> groups;

  /// SemVer-style 버전.
  final String version; // '1.0.0'

  /// 과거 발행 이력.
  final List<BlueprintPublishedVersion> publishedVersions;

  /// 소유자가 본인 진행 데이터를 청사진 미리보기에 자동 반영할지.
  final bool autoSyncOwnerRuns;

  /// 협업 멤버 — uid → role.
  final Map<String, BlueprintMemberRole> members;

  final BlueprintDiscoverability discoverability;

  final bool isFeatured;
  final bool isCurated;
  final bool moriknitVerified;

  final List<String> tags;

  /// 보조 자료. 단계 외부에 첨부되는 PDF/이미지(예: 라이센스 PDF, 도식).
  final List<String>? attachedPdfUrls;
  final List<String>? attachedImageUrls;

  // ── #687 Phase A — 1:1 이식 보강 필드 ─────────────────────────────────────

  /// PatternChart.ravelryPatternId — Ravelry 임포트 추적용.
  final int? ravelryPatternId;

  /// PatternChart.forkCount — Fork 카운트.
  final int forkCount;

  /// BuiltinTemplate.descKo/descEn — 카드 부제목/설명.
  final String? description;

  /// BuiltinTemplate.iconName — 카드 아이콘.
  final String? iconName;

  /// BuiltinTemplate.colorHex — 카드 색상.
  final String? colorHex;

  /// BuiltinTemplate.measurementData — 인형 치수 등 측정 데이터.
  final Map<String, dynamic>? measurementData;

  /// BuiltinTemplate.order — 빌트인 템플릿 정렬 순서.
  final int order;

  /// PatternChart.type — 'chart' | 'image' | 'pdf'.
  final String? assetType;

  /// PatternChart.gauge.toJson() — 게이지 정보 (의존 회피용 JSON).
  final Map<String, dynamic>? gaugeJson;

  /// PatternChart.repeatRegions — 반복 구간 (JSON 리스트).
  final List<Map<String, dynamic>> repeatRegionsJson;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const StepBlueprint({
    required this.id,
    required this.ownerUid,
    required this.title,
    this.titleKo,
    this.titleEn,
    this.kind = BlueprintKind.pattern,
    this.visibility = BlueprintVisibility.draft,
    this.license = const BlueprintLicense(),
    this.price,
    this.provider = BlueprintProvider.user,
    this.difficulty,
    this.sourcePatternChartId,
    this.chartAssetId,
    this.fromBlueprintId,
    this.fromAttribution,
    this.prerequisiteBlueprintIds = const [],
    this.groups = const [],
    this.version = '1.0.0',
    this.publishedVersions = const [],
    this.autoSyncOwnerRuns = false,
    this.members = const {},
    this.discoverability = BlueprintDiscoverability.searchable,
    this.isFeatured = false,
    this.isCurated = false,
    this.moriknitVerified = false,
    this.tags = const [],
    this.attachedPdfUrls,
    this.attachedImageUrls,
    this.ravelryPatternId,
    this.forkCount = 0,
    this.description,
    this.iconName,
    this.colorHex,
    this.measurementData,
    this.order = 0,
    this.assetType,
    this.gaugeJson,
    this.repeatRegionsJson = const [],
    required this.createdAt,
    this.updatedAt,
  });

  String localizedTitle(bool ko) =>
      ko ? (titleKo ?? title) : (titleEn ?? title);

  /// 마켓 노출 자격 — 게이트.
  bool get canBeListedOnMarketplace =>
      visibility == BlueprintVisibility.marketplace &&
      price != null &&
      price!.type == PriceType.paid;

  /// 커뮤니티 쇼케이스 자격 — 게이트.
  bool get canBeShowcased =>
      visibility == BlueprintVisibility.community_showcase ||
      visibility == BlueprintVisibility.public;

  /// 발행 가능 여부 (draft 아님 + 그룹 ≥ 1).
  bool get isPublishable =>
      visibility != BlueprintVisibility.draft && groups.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerUid': ownerUid,
        'title': title,
        if (titleKo != null) 'titleKo': titleKo,
        if (titleEn != null) 'titleEn': titleEn,
        'kind': kind.name,
        'visibility': visibility.name,
        'license': license.toMap(),
        if (price != null) 'price': price!.toMap(),
        'provider': provider.name,
        if (difficulty != null) 'difficulty': difficulty!.name,
        if (sourcePatternChartId != null)
          'sourcePatternChartId': sourcePatternChartId,
        if (chartAssetId != null) 'chartAssetId': chartAssetId,
        if (fromBlueprintId != null) 'fromBlueprintId': fromBlueprintId,
        if (fromAttribution != null) 'fromAttribution': fromAttribution,
        'prerequisiteBlueprintIds': prerequisiteBlueprintIds,
        'groups': groups.map((g) => g.toMap()).toList(),
        'version': version,
        'publishedVersions':
            publishedVersions.map((v) => v.toMap()).toList(),
        'autoSyncOwnerRuns': autoSyncOwnerRuns,
        'members': members.map((k, v) => MapEntry(k, v.name)),
        'discoverability': discoverability.name,
        'isFeatured': isFeatured,
        'isCurated': isCurated,
        'moriknitVerified': moriknitVerified,
        'tags': tags,
        if (attachedPdfUrls != null) 'attachedPdfUrls': attachedPdfUrls,
        if (attachedImageUrls != null) 'attachedImageUrls': attachedImageUrls,
        if (ravelryPatternId != null) 'ravelryPatternId': ravelryPatternId,
        'forkCount': forkCount,
        if (description != null) 'description': description,
        if (iconName != null) 'iconName': iconName,
        if (colorHex != null) 'colorHex': colorHex,
        if (measurementData != null) 'measurementData': measurementData,
        'order': order,
        if (assetType != null) 'assetType': assetType,
        if (gaugeJson != null) 'gaugeJson': gaugeJson,
        if (repeatRegionsJson.isNotEmpty)
          'repeatRegionsJson': repeatRegionsJson,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory StepBlueprint.fromMap(Map<String, dynamic> m) => StepBlueprint(
        id: m['id'] as String? ?? '',
        ownerUid: m['ownerUid'] as String? ?? '',
        title: m['title'] as String? ?? '',
        titleKo: m['titleKo'] as String?,
        titleEn: m['titleEn'] as String?,
        kind: BlueprintKind.fromName(m['kind'] as String?),
        visibility:
            BlueprintVisibility.fromName(m['visibility'] as String?),
        license: m['license'] == null
            ? const BlueprintLicense()
            : BlueprintLicense.fromMap(
                Map<String, dynamic>.from(m['license'] as Map),
              ),
        price: m['price'] == null
            ? null
            : BlueprintPrice.fromMap(
                Map<String, dynamic>.from(m['price'] as Map),
              ),
        provider: BlueprintProvider.fromName(m['provider'] as String?),
        difficulty:
            BlueprintDifficulty.fromName(m['difficulty'] as String?),
        sourcePatternChartId: m['sourcePatternChartId'] as String?,
        chartAssetId: m['chartAssetId'] as String?,
        fromBlueprintId: m['fromBlueprintId'] as String?,
        fromAttribution: m['fromAttribution'] as String?,
        prerequisiteBlueprintIds:
            ((m['prerequisiteBlueprintIds'] as List?) ?? [])
                .map((e) => e as String)
                .toList(),
        groups: ((m['groups'] as List?) ?? [])
            .map(
              (g) => StepGroupMeta.fromMap(Map<String, dynamic>.from(g as Map)),
            )
            .toList(),
        version: m['version'] as String? ?? '1.0.0',
        publishedVersions: ((m['publishedVersions'] as List?) ?? [])
            .map(
              (v) => BlueprintPublishedVersion.fromMap(
                Map<String, dynamic>.from(v as Map),
              ),
            )
            .toList(),
        autoSyncOwnerRuns: m['autoSyncOwnerRuns'] as bool? ?? false,
        members: ((m['members'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(
            k as String,
            BlueprintMemberRole.fromName(v as String?),
          ),
        ),
        discoverability: BlueprintDiscoverability.fromName(
          m['discoverability'] as String?,
        ),
        isFeatured: m['isFeatured'] as bool? ?? false,
        isCurated: m['isCurated'] as bool? ?? false,
        moriknitVerified: m['moriknitVerified'] as bool? ?? false,
        tags: ((m['tags'] as List?) ?? []).map((e) => e as String).toList(),
        attachedPdfUrls: m['attachedPdfUrls'] == null
            ? null
            : ((m['attachedPdfUrls'] as List).map((e) => e as String).toList()),
        attachedImageUrls: m['attachedImageUrls'] == null
            ? null
            : ((m['attachedImageUrls'] as List)
                .map((e) => e as String)
                .toList()),
        ravelryPatternId: m['ravelryPatternId'] is int
            ? m['ravelryPatternId'] as int
            : (m['ravelryPatternId'] is num
                ? (m['ravelryPatternId'] as num).toInt()
                : null),
        forkCount: (m['forkCount'] as num?)?.toInt() ?? 0,
        description: m['description'] as String?,
        iconName: m['iconName'] as String?,
        colorHex: m['colorHex'] as String?,
        measurementData: m['measurementData'] == null
            ? null
            : Map<String, dynamic>.from(m['measurementData'] as Map),
        order: (m['order'] as num?)?.toInt() ?? 0,
        assetType: m['assetType'] as String?,
        gaugeJson: m['gaugeJson'] == null
            ? null
            : Map<String, dynamic>.from(m['gaugeJson'] as Map),
        repeatRegionsJson: ((m['repeatRegionsJson'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: m['updatedAt'] == null
            ? null
            : DateTime.tryParse(m['updatedAt'] as String),
      );

  StepBlueprint copyWith({
    String? id,
    String? ownerUid,
    String? title,
    String? titleKo,
    String? titleEn,
    BlueprintKind? kind,
    BlueprintVisibility? visibility,
    BlueprintLicense? license,
    BlueprintPrice? price,
    BlueprintProvider? provider,
    BlueprintDifficulty? difficulty,
    String? sourcePatternChartId,
    String? chartAssetId,
    String? fromBlueprintId,
    String? fromAttribution,
    List<String>? prerequisiteBlueprintIds,
    List<StepGroupMeta>? groups,
    String? version,
    List<BlueprintPublishedVersion>? publishedVersions,
    bool? autoSyncOwnerRuns,
    Map<String, BlueprintMemberRole>? members,
    BlueprintDiscoverability? discoverability,
    bool? isFeatured,
    bool? isCurated,
    bool? moriknitVerified,
    List<String>? tags,
    List<String>? attachedPdfUrls,
    List<String>? attachedImageUrls,
    int? ravelryPatternId,
    int? forkCount,
    String? description,
    String? iconName,
    String? colorHex,
    Map<String, dynamic>? measurementData,
    int? order,
    String? assetType,
    Map<String, dynamic>? gaugeJson,
    List<Map<String, dynamic>>? repeatRegionsJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      StepBlueprint(
        id: id ?? this.id,
        ownerUid: ownerUid ?? this.ownerUid,
        title: title ?? this.title,
        titleKo: titleKo ?? this.titleKo,
        titleEn: titleEn ?? this.titleEn,
        kind: kind ?? this.kind,
        visibility: visibility ?? this.visibility,
        license: license ?? this.license,
        price: price ?? this.price,
        provider: provider ?? this.provider,
        difficulty: difficulty ?? this.difficulty,
        sourcePatternChartId:
            sourcePatternChartId ?? this.sourcePatternChartId,
        chartAssetId: chartAssetId ?? this.chartAssetId,
        fromBlueprintId: fromBlueprintId ?? this.fromBlueprintId,
        fromAttribution: fromAttribution ?? this.fromAttribution,
        prerequisiteBlueprintIds:
            prerequisiteBlueprintIds ?? this.prerequisiteBlueprintIds,
        groups: groups ?? this.groups,
        version: version ?? this.version,
        publishedVersions: publishedVersions ?? this.publishedVersions,
        autoSyncOwnerRuns: autoSyncOwnerRuns ?? this.autoSyncOwnerRuns,
        members: members ?? this.members,
        discoverability: discoverability ?? this.discoverability,
        isFeatured: isFeatured ?? this.isFeatured,
        isCurated: isCurated ?? this.isCurated,
        moriknitVerified: moriknitVerified ?? this.moriknitVerified,
        tags: tags ?? this.tags,
        attachedPdfUrls: attachedPdfUrls ?? this.attachedPdfUrls,
        attachedImageUrls: attachedImageUrls ?? this.attachedImageUrls,
        ravelryPatternId: ravelryPatternId ?? this.ravelryPatternId,
        forkCount: forkCount ?? this.forkCount,
        description: description ?? this.description,
        iconName: iconName ?? this.iconName,
        colorHex: colorHex ?? this.colorHex,
        measurementData: measurementData ?? this.measurementData,
        order: order ?? this.order,
        assetType: assetType ?? this.assetType,
        gaugeJson: gaugeJson ?? this.gaugeJson,
        repeatRegionsJson: repeatRegionsJson ?? this.repeatRegionsJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
