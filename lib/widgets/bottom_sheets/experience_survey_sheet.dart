import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/feedback_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';

class ExperienceSurveySheet extends StatefulWidget {
  const ExperienceSurveySheet({super.key});

  @override
  State<ExperienceSurveySheet> createState() => _ExperienceSurveySheetState();
}

class _ExperienceSurveySheetState extends State<ExperienceSurveySheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _commentController = TextEditingController();
  
  double _rating = 0;
  List<String> _selectedCategories = [];
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Fitur AI / Sentiment',
    'Catat Transaksi',
    'Goal Budget Tracker',
    'Tampilan (UI)',
    'Kecepatan (Performa)',
    'Laporan Chart',
    'Fitur OCR Struk',
    'Bug / Eror',
    'Lainnya'
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_rating == 0) {
      UIHelper.showErrorSnackBar(context, 'Kasih rating bintang dulu yuk! ⭐');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final feedback = FeedbackModel(
        userId: user?.uid ?? 'anonymous',
        rating: _rating,
        category: _selectedCategories.isNotEmpty ? _selectedCategories.join(', ') : 'Lainnya',
        comment: _commentController.text,
        appVersion: '1.0.0+1', // Bisa dinamis pake package_info_plus nanti
        deviceInfo: 'Flutter Generic Device', // Bisa dinamis pake device_info_plus nanti
        createdAt: DateTime.now(),
      );

      await _firestoreService.submitFeedback(feedback);

      if (!mounted) return;
      Navigator.pop(context);
      UIHelper.showSuccessSnackBar(context, 'Terima kasih atas feedback-nya! Archen sangat menghargainya. ✨');
    } catch (e) {
      if (!mounted) return;
      UIHelper.showErrorSnackBar(context, 'Waduh, gagal kirim feedback: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.5)),
              ),
              child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bagaimana Pengalamanmu?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bantu Archen bikin MyDuitGweh makin sakti buat kamu!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Star Rating
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              _rating > index ? Icons.star_rounded : Icons.star_border_rounded,
                              color: _rating > index ? Colors.amber : Colors.grey[400],
                              size: 48,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _getRatingText(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _getRatingColor(),
                        fontSize: 15,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Bagian apa yang paling berkesan?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedCategories.remove(cat);
                            } else {
                              _selectedCategories.add(cat);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ] : [],
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Ceritakan lebih detail (Opsional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Saran, keluhan, atau pujian buat Archen...',
                      hintStyle: const TextStyle(fontSize: 14),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primary.withOpacity(0.5),
                      ),
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'KIRIM FEEDBACK SEKARANG',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating.toInt()) {
      case 1: return 'Waduh, sedih banget Archen... 😢';
      case 2: return 'Masih kurang oke ya? Kasih tau Archen! 😕';
      case 3: return 'Lumayanlah, tapi ada yang bisa lebih baik! 🙂';
      case 4: return 'Mantap! MyDuitGweh sudah membantu! ✨';
      case 5: return 'LUAR BIASA! User paling keren sedunia! 🔥';
      default: return 'Pilih Bintang-mu!';
    }
  }

  Color _getRatingColor() {
    if (_rating == 0) return AppColors.textHint;
    if (_rating <= 2) return AppColors.expense;
    if (_rating >= 4) return AppColors.primary;
    return Colors.amber[800]!;
  }
}
