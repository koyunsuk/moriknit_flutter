import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportInquiry {
  final String id;
  final String title;
  final String authorName;
  final String email;
  final String content;
  final String password;
  final String status;
  final String? adminReply;
  final DateTime? adminRepliedAt;
  final DateTime createdAt;

  const SupportInquiry({
    this.id = '',
    required this.title,
    required this.authorName,
    required this.email,
    required this.content,
    required this.password,
    this.status = 'pending',
    this.adminReply,
    this.adminRepliedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'authorName': authorName,
        'email': email,
        'content': content,
        'password': password,
        'status': status,
        'adminReply': adminReply,
        'adminRepliedAt':
            adminRepliedAt != null ? Timestamp.fromDate(adminRepliedAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory SupportInquiry.fromMap(String id, Map<String, dynamic> map) =>
      SupportInquiry(
        id: id,
        title: map['title'] ?? '',
        authorName: map['authorName'] ?? '',
        email: map['email'] ?? '',
        content: map['content'] ?? '',
        password: map['password'] ?? '',
        status: map['status'] ?? 'pending',
        adminReply: map['adminReply'] as String?,
        adminRepliedAt:
            (map['adminRepliedAt'] as Timestamp?)?.toDate(),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class SupportInquiryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createInquiry(SupportInquiry inquiry) async {
    await _db.collection('support_inquiries').add(inquiry.toMap());
  }

  Stream<List<SupportInquiry>> getInquiries() {
    return _db
        .collection('support_inquiries')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SupportInquiry.fromMap(d.id, d.data()))
            .toList());
  }
}

final supportInquiryRepositoryProvider =
    Provider<SupportInquiryRepository>((ref) => SupportInquiryRepository());
