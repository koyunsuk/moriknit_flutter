/// 나의 사진 앨범 도메인 모델
/// sourceType: 'project' | 'swatch'
class PhotoAlbumItem {
  final String imageUrl;
  final String sourceType; // 'project' | 'swatch'
  final String sourceName;
  final DateTime createdAt;

  const PhotoAlbumItem({
    required this.imageUrl,
    required this.sourceType,
    required this.sourceName,
    required this.createdAt,
  });
}
