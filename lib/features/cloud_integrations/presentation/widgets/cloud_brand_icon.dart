// lib/features/cloud_integrations/presentation/widgets/cloud_brand_icon.dart
//
// 클라우드 서비스 브랜드 아이콘 (#707)
// 외부 PNG 의존성 제거 — 각 브랜드 컬러+형태를 Flutter 기본 위젯(CustomPainter)으로 표현.
//
// 사용:
//   CloudBrandIcon.dropbox(size: 26)
//   CloudBrandIcon.googleDrive(size: 26)
//   CloudBrandIcon.iCloud(size: 26)
//   CloudBrandIcon.oneDrive(size: 26)

import 'package:flutter/material.dart';

/// 클라우드 서비스 종류.
enum CloudBrand { dropbox, googleDrive, iCloud, oneDrive }

/// 브랜드 컬러+형태를 표현한 자체 위젯.
/// CustomPainter 기반으로 어떤 크기에도 깔끔하게 스케일됨.
class CloudBrandIcon extends StatelessWidget {
  const CloudBrandIcon({
    super.key,
    required this.brand,
    this.size = 26,
  });

  /// Dropbox: 파란 사각 마름모 (상하 두 다이아몬드) 형태.
  const CloudBrandIcon.dropbox({super.key, this.size = 26}) : brand = CloudBrand.dropbox;

  /// Google Drive: 노랑/녹색/파랑 삼각형 조합.
  const CloudBrandIcon.googleDrive({super.key, this.size = 26}) : brand = CloudBrand.googleDrive;

  /// iCloud: 흰 구름 + 옅은 파랑 그라데이션.
  const CloudBrandIcon.iCloud({super.key, this.size = 26}) : brand = CloudBrand.iCloud;

  /// OneDrive: 파란 구름 형태.
  const CloudBrandIcon.oneDrive({super.key, this.size = 26}) : brand = CloudBrand.oneDrive;

  final CloudBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CloudBrandPainter(brand),
      ),
    );
  }
}

class _CloudBrandPainter extends CustomPainter {
  _CloudBrandPainter(this.brand);
  final CloudBrand brand;

  @override
  void paint(Canvas canvas, Size size) {
    switch (brand) {
      case CloudBrand.dropbox:
        _paintDropbox(canvas, size);
        break;
      case CloudBrand.googleDrive:
        _paintGoogleDrive(canvas, size);
        break;
      case CloudBrand.iCloud:
        _paintICloud(canvas, size);
        break;
      case CloudBrand.oneDrive:
        _paintOneDrive(canvas, size);
        break;
    }
  }

  // Dropbox — 두 줄의 파란 다이아몬드 (위 2개 + 아래 1개 형상).
  void _paintDropbox(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0061FF)
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final qw = w / 4;
    final qh = h / 4;

    // 좌상 다이아몬드
    final p1 = Path()
      ..moveTo(qw, 0)
      ..lineTo(qw * 2, qh)
      ..lineTo(qw, qh * 2)
      ..lineTo(0, qh)
      ..close();
    // 우상 다이아몬드
    final p2 = Path()
      ..moveTo(qw * 3, 0)
      ..lineTo(qw * 4, qh)
      ..lineTo(qw * 3, qh * 2)
      ..lineTo(qw * 2, qh)
      ..close();
    // 좌하 다이아몬드
    final p3 = Path()
      ..moveTo(qw, qh * 2)
      ..lineTo(qw * 2, qh * 3)
      ..lineTo(qw, qh * 4)
      ..lineTo(0, qh * 3)
      ..close();
    // 우하 다이아몬드
    final p4 = Path()
      ..moveTo(qw * 3, qh * 2)
      ..lineTo(qw * 4, qh * 3)
      ..lineTo(qw * 3, qh * 4)
      ..lineTo(qw * 2, qh * 3)
      ..close();

    canvas.drawPath(p1, paint);
    canvas.drawPath(p2, paint);
    canvas.drawPath(p3, paint);
    canvas.drawPath(p4, paint);
  }

  // Google Drive — 노랑/녹색/파랑 삼각형 조합 (정삼각 모양으로 단순화).
  void _paintGoogleDrive(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 좌측 노란 삼각형
    final yellow = Paint()..color = const Color(0xFFFFC107);
    final pYellow = Path()
      ..moveTo(0, h * 0.78)
      ..lineTo(w * 0.27, h * 0.30)
      ..lineTo(w * 0.55, h * 0.78)
      ..close();
    canvas.drawPath(pYellow, yellow);

    // 우측 파란 삼각형
    final blue = Paint()..color = const Color(0xFF1A73E8);
    final pBlue = Path()
      ..moveTo(w * 0.55, h * 0.78)
      ..lineTo(w * 0.73, h * 0.30)
      ..lineTo(w, h * 0.78)
      ..close();
    canvas.drawPath(pBlue, blue);

    // 상단 녹색 삼각형
    final green = Paint()..color = const Color(0xFF34A853);
    final pGreen = Path()
      ..moveTo(w * 0.27, h * 0.30)
      ..lineTo(cx, h * 0.0)
      ..lineTo(w * 0.73, h * 0.30)
      ..close();
    canvas.drawPath(pGreen, green);
  }

  // iCloud — 흰 구름 + 옅은 파랑 그라데이션.
  void _paintICloud(Canvas canvas, Size size) {
    final cloud = _buildCloudPath(size);

    // 옅은 파랑 그라데이션 채움
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFBFE0F7), Color(0xFF7BB6E0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fill = Paint()..shader = shader;
    canvas.drawPath(cloud, fill);

    // 흰색 하이라이트 (상단)
    final highlight = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final hPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.40)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.28,
        size.width * 0.70,
        size.height * 0.40,
      )
      ..lineTo(size.width * 0.65, size.height * 0.48)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.38,
        size.width * 0.35,
        size.height * 0.48,
      )
      ..close();
    canvas.drawPath(hPath, highlight);
  }

  // OneDrive — 파란 구름.
  void _paintOneDrive(Canvas canvas, Size size) {
    final cloud = _buildCloudPath(size);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF50B0E8), Color(0xFF0078D4)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final fill = Paint()..shader = shader;
    canvas.drawPath(cloud, fill);
  }

  /// 표준 구름 실루엣 (3개 원 + 사각형 하단).
  Path _buildCloudPath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // 좌측 작은 원
    final left = Rect.fromCircle(
      center: Offset(w * 0.25, h * 0.62),
      radius: h * 0.22,
    );
    // 가운데 큰 원
    final center = Rect.fromCircle(
      center: Offset(w * 0.50, h * 0.48),
      radius: h * 0.30,
    );
    // 우측 중간 원
    final right = Rect.fromCircle(
      center: Offset(w * 0.78, h * 0.60),
      radius: h * 0.24,
    );
    // 하단 사각형 (다리 부분)
    final base = Rect.fromLTWH(
      w * 0.10,
      h * 0.62,
      w * 0.80,
      h * 0.28,
    );

    path.addOval(left);
    path.addOval(center);
    path.addOval(right);
    path.addRRect(RRect.fromRectAndRadius(base, Radius.circular(h * 0.14)));
    return path;
  }

  @override
  bool shouldRepaint(covariant _CloudBrandPainter oldDelegate) {
    return oldDelegate.brand != brand;
  }
}
