import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/project_model.dart';
import '../../domain/project_step.dart';

class ProjectShareCard extends StatelessWidget {
  final ProjectModel project;
  final List<ProjectStep> steps;
  final GlobalKey repaintKey;

  const ProjectShareCard({
    super.key,
    required this.project,
    required this.steps,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = steps.where((s) => s.isDone).length;
    final totalCount = steps.length;
    final progressPct = totalCount > 0 ? (doneCount * 100 ~/ totalCount) : 100;
    final dateFormat = DateFormat('yyyy.MM.dd');
    final finishDate =
        project.finishDate != null ? dateFormat.format(project.finishDate!) : '';

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 360,
        height: 360,
        color: Colors.white,
        child: Stack(
          children: [
            // 배경 그라디언트
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF3F8),
                    Color(0xFFF0EAFF),
                    Color(0xFFEDFFF5),
                  ],
                ),
              ),
            ),
            // 커버 이미지 (상단 절반)
            if (project.coverPhotoUrl.isNotEmpty)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: Image.network(
                  project.coverPhotoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 180,
                    color: const Color(0xFFEDE9FF),
                    child: const Icon(
                      Icons.image_outlined,
                      size: 48,
                      color: Color(0xFFB39DDB),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 180,
                child: Container(
                  color: const Color(0xFFEDE9FF),
                  child: const Center(
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 56,
                      color: Color(0xFFB39DDB),
                    ),
                  ),
                ),
              ),
            // 상단 이미지 위 그라디언트 (아래→위 페이드)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.white, Colors.transparent],
                  ),
                ),
              ),
            ),
            // 하단 콘텐츠
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 200,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      project.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 메타 정보 행
                    Row(
                      children: [
                        if (finishDate.isNotEmpty) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 12,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            finishDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (project.yarnName.isNotEmpty || project.yarnBrandName.isNotEmpty) ...[
                          const Icon(
                            Icons.layers_rounded,
                            size: 12,
                            color: Color(0xFF9C8FC0),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                if (project.yarnBrandName.isNotEmpty) project.yarnBrandName,
                                if (project.yarnName.isNotEmpty) project.yarnName,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9C8FC0),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 진행률 바
                    if (totalCount > 0) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progressPct / 100,
                                backgroundColor: const Color(0xFFEDE9FF),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7C5CBF),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$progressPct%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C5CBF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    // 태그
                    Row(
                      children: [
                        if (project.yarnWeight.isNotEmpty)
                          _tag(
                            project.yarnWeight,
                            const Color(0xFFEDE9FF),
                            const Color(0xFF7C5CBF),
                          ),
                        if (project.needleSize > 0) ...[
                          const SizedBox(width: 6),
                          _tag(
                            '${project.needleSize.toStringAsFixed(2)}mm',
                            const Color(0xFFE8F5E9),
                            const Color(0xFF388E3C),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    // 하단 MoriKnit 로고
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6BA8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Text(
                              'M',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'MoriKnit',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFE0438A),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'www.moriknit.com',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 카드를 이미지로 캡처 후 공유
Future<void> shareProjectCard(
  BuildContext context,
  GlobalKey repaintKey,
  String title,
) async {
  try {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'moriknit_$title.png',
          ),
        ],
        text: 'MoriKnit으로 완성한 작품을 공유해요! 🧶',
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 실패: $e')),
      );
    }
  }
}
