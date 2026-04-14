import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/project_model.dart';

class PublicProjectEntry {
  final String id;
  final String uid;
  final String ownerName;
  final String projectId;
  final String title;
  final String coverPhotoUrl;
  final String yarnName;
  final String yarnBrandName;
  final String yarnWeight;
  final double needleSize;
  final DateTime? finishDate;
  final int likeCount;
  final List<String> likedBy;
  final DateTime createdAt;
  final List<String> stepTitles;
  final List<String> photoUrls;
  final String sourcePatternId;

  const PublicProjectEntry({
    required this.id,
    required this.uid,
    required this.ownerName,
    required this.projectId,
    required this.title,
    required this.coverPhotoUrl,
    required this.yarnName,
    required this.yarnBrandName,
    required this.yarnWeight,
    required this.needleSize,
    required this.likeCount,
    required this.likedBy,
    required this.finishDate,
    required this.createdAt,
    this.stepTitles = const [],
    this.photoUrls = const [],
    this.sourcePatternId = '',
  });

  factory PublicProjectEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PublicProjectEntry(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      coverPhotoUrl: data['coverPhotoUrl'] as String? ?? '',
      yarnName: data['yarnName'] as String? ?? '',
      yarnBrandName: data['yarnBrandName'] as String? ?? '',
      yarnWeight: data['yarnWeight'] as String? ?? '',
      needleSize: (data['needleSize'] as num?)?.toDouble() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] as List? ?? []),
      finishDate: data['finishDate'] != null
          ? DateTime.tryParse(data['finishDate'] as String)
          : null,
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      stepTitles: List<String>.from(data['stepTitles'] as List? ?? []),
      photoUrls: List<String>.from(data['photoUrls'] as List? ?? []),
      sourcePatternId: data['sourcePatternId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'ownerName': ownerName,
    'projectId': projectId,
    'title': title,
    'coverPhotoUrl': coverPhotoUrl,
    'yarnName': yarnName,
    'yarnBrandName': yarnBrandName,
    'yarnWeight': yarnWeight,
    'needleSize': needleSize,
    'likeCount': likeCount,
    'likedBy': likedBy,
    'finishDate': finishDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'stepTitles': stepTitles,
    'photoUrls': photoUrls,
    'sourcePatternId': sourcePatternId,
  };
}

class PublicProjectService {
  final _col = FirebaseFirestore.instance.collection('public_projects');

  Stream<List<PublicProjectEntry>> watchPublicProjects() {
    return _col
        .limit(50)
        .snapshots()
        .map((snap) {
          final entries = snap.docs.map(PublicProjectEntry.fromFirestore).toList();
          entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }

  Future<void> publishProject({
    required String uid,
    required String ownerName,
    required ProjectModel project,
    List<String>? stepTitles,
    List<String>? photoUrls,
  }) async {
    final existing =
        await _col
            .where('projectId', isEqualTo: project.id)
            .where('uid', isEqualTo: uid)
            .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'title': project.title,
        'coverPhotoUrl': project.coverPhotoUrl,
        'yarnName': project.yarnName,
        'yarnBrandName': project.yarnBrandName,
        'yarnWeight': project.yarnWeight,
        'needleSize': project.needleSize,
        'finishDate': project.finishDate?.toIso8601String(),
        'stepTitles': stepTitles ?? [],
        'photoUrls': photoUrls ?? [],
      });
      return;
    }
    await _col.add(
      PublicProjectEntry(
        id: '',
        uid: uid,
        ownerName: ownerName,
        projectId: project.id,
        title: project.title,
        coverPhotoUrl: project.coverPhotoUrl,
        yarnName: project.yarnName,
        yarnBrandName: project.yarnBrandName,
        yarnWeight: project.yarnWeight,
        needleSize: project.needleSize,
        likeCount: 0,
        likedBy: [],
        finishDate: project.finishDate,
        createdAt: DateTime.now(),
        stepTitles: stepTitles ?? [],
        photoUrls: photoUrls ?? [],
        sourcePatternId: project.sourcePatternId,
      ).toMap(),
    );
  }

  Future<void> unpublishProject({
    required String uid,
    required String projectId,
  }) async {
    final existing =
        await _col
            .where('projectId', isEqualTo: projectId)
            .where('uid', isEqualTo: uid)
            .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteEntry(String entryId) async {
    await _col.doc(entryId).delete();
  }

  Future<void> updateEntryTitle(String entryId, String newTitle) async {
    await _col.doc(entryId).update({'title': newTitle});
  }

  Future<void> toggleLike({
    required String entryId,
    required String uid,
  }) async {
    final doc = _col.doc(entryId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(doc);
      if (!snap.exists) return;
      final likedBy = List<String>.from(
        snap.data()?['likedBy'] as List? ?? [],
      );
      if (likedBy.contains(uid)) {
        likedBy.remove(uid);
      } else {
        likedBy.add(uid);
      }
      tx.update(doc, {'likedBy': likedBy, 'likeCount': likedBy.length});
    });
  }

  Future<bool> isPublished({
    required String uid,
    required String projectId,
  }) async {
    final result =
        await _col
            .where('projectId', isEqualTo: projectId)
            .where('uid', isEqualTo: uid)
            .get();
    return result.docs.isNotEmpty;
  }
}

final publicProjectServiceProvider = Provider<PublicProjectService>(
  (ref) => PublicProjectService(),
);

final publicProjectsProvider = StreamProvider<List<PublicProjectEntry>>((ref) {
  return ref.watch(publicProjectServiceProvider).watchPublicProjects();
});
