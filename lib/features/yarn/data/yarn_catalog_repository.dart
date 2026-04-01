import 'package:cloud_firestore/cloud_firestore.dart';

class YarnMaterialItem {
  final String id;
  final String nameKo;
  final String nameEn;
  const YarnMaterialItem({required this.id, required this.nameKo, required this.nameEn});
}

class YarnColorItem {
  final String id;
  final String nameKo;
  final String nameEn;
  final String colorCode;
  const YarnColorItem({required this.id, required this.nameKo, required this.nameEn, required this.colorCode});
}

class YarnCatalogRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<YarnMaterialItem>> watchMaterials() {
    return _db.collection('yarnMaterials').orderBy('order').snapshots().map((snap) =>
        snap.docs.map((doc) => YarnMaterialItem(
          id: doc.id,
          nameKo: doc.data()['nameKo'] as String? ?? '',
          nameEn: doc.data()['nameEn'] as String? ?? '',
        )).toList());
  }

  Stream<List<YarnColorItem>> watchColors() {
    return _db.collection('yarnColors').orderBy('order').snapshots().map((snap) =>
        snap.docs.map((doc) => YarnColorItem(
          id: doc.id,
          nameKo: doc.data()['nameKo'] as String? ?? '',
          nameEn: doc.data()['nameEn'] as String? ?? '',
          colorCode: doc.data()['colorCode'] as String? ?? '#CCCCCC',
        )).toList());
  }
}
