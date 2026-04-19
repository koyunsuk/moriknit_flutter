/// 나의 사진 앨범 도메인 모델
/// sourceType: 'project' | 'swatch' | 'accessory'
class PhotoAlbumItem {
  final String imageUrl;
  final String sourceType; // 'project' | 'swatch' | 'accessory'
  final String sourceName;
  final String sourceId; // Firestore doc id
  final DateTime createdAt;

  const PhotoAlbumItem({
    required this.imageUrl,
    required this.sourceType,
    required this.sourceName,
    required this.sourceId,
    required this.createdAt,
  });
}
