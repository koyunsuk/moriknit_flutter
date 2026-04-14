import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/firestore_json.dart';

part 'accessory_model.freezed.dart';
part 'accessory_model.g.dart';

/// 니팅 악세사리 종류
enum AccessoryType {
  rowCounter,      // 단수 카운터
  stitchMarker,    // 코 표시자
  tapeMeasure,     // 줄자
  scissors,        // 가위
  yarnNeedle,      // 돗바늘
  cablNeedle,      // 케이블 바늘
  bobbin,          // 보빈
  knitBlocker,     // 니트 블로커
  swiftYarnWinder, // 실 와인더/스위프트
  projectBag,      // 프로젝트 백
  needleCase,      // 바늘 케이스
  yarnCutter,      // 실 커터
  knitGauge,       // 게이지
  pompomMaker,     // 폼폼 메이커
  other,           // 기타
}

extension AccessoryTypeExt on AccessoryType {
  String get label => labelKo;

  String get labelKo {
    switch (this) {
      case AccessoryType.rowCounter:     return '단수 카운터';
      case AccessoryType.stitchMarker:   return '코 표시자';
      case AccessoryType.tapeMeasure:    return '줄자';
      case AccessoryType.scissors:       return '가위';
      case AccessoryType.yarnNeedle:     return '돗바늘';
      case AccessoryType.cablNeedle:     return '케이블 바늘';
      case AccessoryType.bobbin:         return '보빈';
      case AccessoryType.knitBlocker:    return '니트 블로커';
      case AccessoryType.swiftYarnWinder: return '실 와인더/스위프트';
      case AccessoryType.projectBag:     return '프로젝트 백';
      case AccessoryType.needleCase:     return '바늘 케이스';
      case AccessoryType.yarnCutter:     return '실 커터';
      case AccessoryType.knitGauge:      return '게이지';
      case AccessoryType.pompomMaker:    return '폼폼 메이커';
      case AccessoryType.other:          return '기타';
    }
  }

  String get labelEn {
    switch (this) {
      case AccessoryType.rowCounter:     return 'Row Counter';
      case AccessoryType.stitchMarker:   return 'Stitch Marker';
      case AccessoryType.tapeMeasure:    return 'Tape Measure';
      case AccessoryType.scissors:       return 'Scissors';
      case AccessoryType.yarnNeedle:     return 'Yarn Needle';
      case AccessoryType.cablNeedle:     return 'Cable Needle';
      case AccessoryType.bobbin:         return 'Bobbin';
      case AccessoryType.knitBlocker:    return 'Knit Blocker';
      case AccessoryType.swiftYarnWinder: return 'Yarn Winder/Swift';
      case AccessoryType.projectBag:     return 'Project Bag';
      case AccessoryType.needleCase:     return 'Needle Case';
      case AccessoryType.yarnCutter:     return 'Yarn Cutter';
      case AccessoryType.knitGauge:      return 'Knit Gauge';
      case AccessoryType.pompomMaker:    return 'Pom-pom Maker';
      case AccessoryType.other:          return 'Other';
    }
  }

  String localizedLabel(bool isKorean) => isKorean ? labelKo : labelEn;
}

@freezed
class AccessoryModel with _$AccessoryModel {
  const factory AccessoryModel({
    required String id,
    required String uid,
    @Default('other') String type,
    @Default('') String brandName,
    @Default('') String name,
    @Default(1) int quantity,
    @Default(0) int price,
    @Default('') String purchasePlace,
    @Default('') String memo,
    @Default('') String photoUrl,
    DateTime? purchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isDirty,
  }) = _AccessoryModel;

  factory AccessoryModel.fromJson(Map<String, dynamic> json) => _$AccessoryModelFromJson(json);

  factory AccessoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessoryModel.fromJson(normalizeFirestoreMap({...data, 'id': doc.id}));
  }

  factory AccessoryModel.empty({required String uid}) {
    return AccessoryModel(
      id: '',
      uid: uid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

extension AccessoryModelExt on AccessoryModel {
  AccessoryType get typeEnum {
    try {
      return AccessoryType.values.firstWhere((e) => e.name == type);
    } catch (_) {
      return AccessoryType.other;
    }
  }

  String localizedTypeLabel(bool isKorean) => typeEnum.localizedLabel(isKorean);
}
