enum AdminImportKind {
  market,
  pattern,
  encyclopedia,
  communityPost,
  yarnBrand,
  needleBrand,
}

extension AdminImportKindX on AdminImportKind {
  String get key => switch (this) {
        AdminImportKind.market => 'market',
        AdminImportKind.pattern => 'pattern',
        AdminImportKind.encyclopedia => 'encyclopedia',
        AdminImportKind.communityPost => 'community_post',
        AdminImportKind.yarnBrand => 'yarn_brands',
        AdminImportKind.needleBrand => 'needle_brands',
      };

  String label(bool isKorean) => switch (this) {
        AdminImportKind.market => isKorean ? '상품' : 'Market items',
        AdminImportKind.pattern => isKorean ? '도안' : 'Patterns',
        AdminImportKind.encyclopedia => isKorean ? '뜨개백과' : 'Encyclopedia',
        AdminImportKind.communityPost => isKorean ? '커뮤니티 글' : 'Community posts',
        AdminImportKind.yarnBrand => isKorean ? '실 목록' : 'Yarn brands',
        AdminImportKind.needleBrand => isKorean ? '바늘 목록' : 'Needle brands',
      };

  String fileBaseName() => 'moriknit_$key';

  List<String> get headers => switch (this) {
        AdminImportKind.market => const [
            'seller_uid',
            'seller_name',
            'title',
            'description',
            'price',
            'category_key',
            'accent_hex',
            'image_type',
            'is_official',
            'is_sold_out',
            'status',
            'image_url',
            'pdf_url',
          ],
        AdminImportKind.pattern => const [
            'seller_uid',
            'seller_name',
            'title',
            'description',
            'price',
            'accent_hex',
            'image_type',
            'is_official',
            'is_sold_out',
            'status',
            'image_url',
            'pdf_url',
          ],
        AdminImportKind.encyclopedia => const [
            'term_key',
            'term_ko',
            'term_en',
            'term_ja',
            'abbreviation',
            'category_key',
            'description_ko',
            'description_en',
            'description_ja',
            'aliases',
            'symbol_key',
            'reference_url',
            'video_url',
            'order',
            'status',
          ],
        AdminImportKind.communityPost => const [
            'uid',
            'author_name',
            'category_key',
            'title',
            'content',
            'image_urls',
            'attachment_urls',
            'attachment_names',
            'like_count',
            'comment_count',
            'liked_by',
          ],
        AdminImportKind.yarnBrand => const [
            'brand_id',
            'name',
            'country',
            'website',
            'notes',
            'is_active',
            'sort_order',
          ],
        AdminImportKind.needleBrand => const [
            'brand_id',
            'name',
            'country',
            'website',
            'notes',
            'is_active',
            'sort_order',
          ],
      };

  List<String> get requiredHeaders => switch (this) {
        AdminImportKind.market => const ['title', 'price', 'category_key'],
        AdminImportKind.pattern => const ['title', 'price'],
        AdminImportKind.encyclopedia => const [
            'term_key',
            'term_ko',
            'category_key',
            'description_ko',
          ],
        AdminImportKind.communityPost => const [
            'author_name',
            'category_key',
            'title',
            'content',
          ],
        AdminImportKind.yarnBrand => const ['name'],
        AdminImportKind.needleBrand => const ['name'],
      };

  List<String> requirementRow(bool isKorean) {
    return headers
        .map((header) => requiredHeaders.contains(header)
            ? (isKorean ? '필수' : 'required')
            : (isKorean ? '선택' : 'optional'))
        .toList();
  }

  String buildTemplateCsv(bool isKorean) {
    final rows = <String>[
      headers.join(','),
      requirementRow(isKorean).join(','),
      ..._sampleRows,
    ];
    return rows.join('\n');
  }

  List<String> get _sampleRows => switch (this) {
        AdminImportKind.market => const [
            'official,moriknit,메리노 소프트 100g,부드러운 메리노 실입니다,15000,yarn,#F472B6,yarn,true,false,approved,https://example.com/yarn.jpg,',
            'official,moriknit,코바늘 세트 9종,초보자용 코바늘 세트입니다,28000,tool,#60A5FA,tool,true,false,approved,https://example.com/hook.jpg,',
          ],
        AdminImportKind.pattern => const [
            'official,moriknit,기본 목도리 도안,기본 목도리 PDF 도안입니다,3500,#C084FC,pattern,true,false,approved,https://example.com/pattern.jpg,https://example.com/pattern.pdf',
            'official,moriknit,케이블 비니 도안,케이블 무늬 비니 도안입니다,4500,#60A5FA,pattern,true,false,approved,https://example.com/beanie.jpg,https://example.com/beanie.pdf',
          ],
        AdminImportKind.encyclopedia => const [
            'knit,겉뜨기,Knit,表目,K,technique,기본적인 겉뜨기 기법입니다,The basic knit stitch,基本の表目,plain knit|stockinette,k,,https://youtube.com/example-knit,1,approved',
            'purl,안뜨기,Purl,裏目,P,technique,기본적인 안뜨기 기법입니다,The basic purl stitch,基本の裏目,purled stitch|reverse,p,,https://youtube.com/example-purl,2,approved',
          ],
        AdminImportKind.communityPost => const [
            'official,moriknit,showcase,첫 완성작 자랑하기,처음 완성한 작품을 자유롭게 소개해보세요,https://example.com/post1.jpg,,,0,0,',
            'official,moriknit,questions,바늘 호수 선택 질문,이 실에는 어떤 바늘 호수가 잘 맞을까요?,,,,,0,0,',
          ],
        AdminImportKind.yarnBrand => const [
            'sandnes_garn,Sandnes Garn,Norway,https://www.sandnes-garn.com,Core yarn brand,true,10',
            ',Malabrigo,Uruguay,https://malabrigoyarn.com,Hand dyed yarn,true,20',
          ],
        AdminImportKind.needleBrand => const [
            'chiagoo,ChiaoGoo,China,https://www.chiaogoo.com,Red Lace and interchangeable needles,true,10',
            ',Seeknit,Japan,https://www.seeknit.com,Bamboo needle brand,true,20',
          ],
      };
}

class AdminImportPreview {
  final AdminImportKind kind;
  final String fileName;
  final List<String> headers;
  final List<Map<String, String>> validRows;
  final List<String> errors;

  const AdminImportPreview({
    required this.kind,
    required this.fileName,
    required this.headers,
    required this.validRows,
    required this.errors,
  });

  int get validCount => validRows.length;
  int get invalidCount => errors.length;
}

class AdminImportResult {
  final int createdCount;
  final int skippedCount;

  const AdminImportResult({
    required this.createdCount,
    required this.skippedCount,
  });
}
