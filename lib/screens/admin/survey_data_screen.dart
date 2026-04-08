import 'package:flutter/material.dart';
import '../../models/feedback_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/ui_helper.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyDataScreen extends StatefulWidget {
  const SurveyDataScreen({super.key});

  @override
  State<SurveyDataScreen> createState() => _SurveyDataScreenState();
}

class _SurveyDataScreenState extends State<SurveyDataScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  String _searchQuery = '';
  bool _sortByNewest = true;
  bool _isSuperAdmin = false;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkSuperAdmin();
  }

  Future<void> _checkSuperAdmin() async {
    try {
      final isSuper = await _authService.isSuperAdmin();
      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuper;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _deleteFeedback(FeedbackModel feedback) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus Respon?',
      message: 'Apakah Anda yakin ingin menghapus respon survei ini secara permanen?',
      confirmText: 'HAPUS',
      cancelText: 'BATAL',
      isDangerous: true,
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('user_feedbacks')
            .doc(feedback.id)
            .delete();
            
        if (mounted) {
          UIHelper.showSuccessSnackBar(context, 'Respon berhasil dihapus.');
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showErrorSnackBar(context, 'Gagal menghapus respon: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          'Data Respon Survei',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHeaderTools(),
          Expanded(
            child: StreamBuilder<List<FeedbackModel>>(
              stream: _firestoreService.getRecentFeedbacks(limit: 100),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Gagal memuat data: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_dissatisfied_rounded,
                            size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada data survei masuk.',
                          style: TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }

                // Filtering and Sorting
                var feedbacks = snapshot.data!.where((f) {
                  return f.comment.toLowerCase().contains(_searchQuery) ||
                      f.category.toLowerCase().contains(_searchQuery) ||
                      f.deviceInfo.toLowerCase().contains(_searchQuery);
                }).toList();

                feedbacks.sort((a, b) => _sortByNewest
                    ? b.createdAt.compareTo(a.createdAt)
                    : a.createdAt.compareTo(b.createdAt));

                if (feedbacks.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Text('Hasil pencarian "$_searchQuery" tidak ditemukan.',
                        style: const TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: feedbacks.length,
                  itemBuilder: (context, index) {
                    final feedback = feedbacks[index];
                    return _buildFeedbackCard(feedback);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTools() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Cari komentar, kategori, device...',
                      hintStyle:
                          TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: Colors.indigo),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => setState(() => _sortByNewest = !_sortByNewest),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Icon(
                    _sortByNewest
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.sort_rounded, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                _sortByNewest ? 'Urutan Terbaru' : 'Urutan Terlama',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(FeedbackModel feedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRatingColor(feedback.rating).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: _getRatingColor(feedback.rating), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        feedback.rating.toStringAsFixed(1),
                        style: TextStyle(
                          color: _getRatingColor(feedback.rating),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Map<String, dynamic>?>(
                        future: _firestoreService.getUserInfo(feedback.userId),
                        builder: (context, userSnapshot) {
                          final name = userSnapshot.data?['displayName'] ??
                              'User ${feedback.userId.substring(0, 5)}...';
                          final email =
                              userSnapshot.data?['email'] ?? 'Memuat...';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('dd MMM yy').format(feedback.createdAt),
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    if (_isSuperAdmin) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _deleteFeedback(feedback),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feedback.category.toUpperCase(),
                        style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w900, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'v${feedback.appVersion}',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  feedback.comment.isEmpty ? "(Tidak ada komentar)" : feedback.comment,
                  style: TextStyle(
                    color: feedback.comment.isEmpty ? Colors.grey : Colors.black87,
                    fontStyle: feedback.comment.isEmpty ? FontStyle.italic : FontStyle.normal,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.03),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              'Device: ${feedback.deviceInfo}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.0) return Colors.orange;
    return Colors.red;
  }
}
