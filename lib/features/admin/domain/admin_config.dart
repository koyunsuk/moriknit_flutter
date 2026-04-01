class AdminConfig {
  final String homeGreetingKo;
  final String homeGreetingEn;
  final String myPageSubtitleKo;
  final String myPageSubtitleEn;

  const AdminConfig({
    this.homeGreetingKo = '',
    this.homeGreetingEn = '',
    this.myPageSubtitleKo = '',
    this.myPageSubtitleEn = '',
  });

  factory AdminConfig.fromMap(Map<String, dynamic> map) => AdminConfig(
    homeGreetingKo: map['homeGreetingKo'] as String? ?? '',
    homeGreetingEn: map['homeGreetingEn'] as String? ?? '',
    myPageSubtitleKo: map['myPageSubtitleKo'] as String? ?? '',
    myPageSubtitleEn: map['myPageSubtitleEn'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'homeGreetingKo': homeGreetingKo,
    'homeGreetingEn': homeGreetingEn,
    'myPageSubtitleKo': myPageSubtitleKo,
    'myPageSubtitleEn': myPageSubtitleEn,
  };

  AdminConfig copyWith({
    String? homeGreetingKo,
    String? homeGreetingEn,
    String? myPageSubtitleKo,
    String? myPageSubtitleEn,
  }) => AdminConfig(
    homeGreetingKo: homeGreetingKo ?? this.homeGreetingKo,
    homeGreetingEn: homeGreetingEn ?? this.homeGreetingEn,
    myPageSubtitleKo: myPageSubtitleKo ?? this.myPageSubtitleKo,
    myPageSubtitleEn: myPageSubtitleEn ?? this.myPageSubtitleEn,
  );
}
