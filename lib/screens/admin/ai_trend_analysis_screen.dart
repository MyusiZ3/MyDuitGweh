import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction_model.dart';
import '../../services/ai_service.dart';

class AiTrendAnalysisScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final DateTimeRange dateRange;
  final int totalUsers;
  final int totalWallets;
  final double totalLiquidity;

  const AiTrendAnalysisScreen({
    super.key,
    required this.transactions,
    required this.dateRange,
    required this.totalUsers,
    required this.totalWallets,
    required this.totalLiquidity,
  });

  @override
  State<AiTrendAnalysisScreen> createState() => _AiTrendAnalysisScreenState();
}

class _AiTrendAnalysisScreenState extends State<AiTrendAnalysisScreen> {
  bool _isLoading = true;
  String? _analysisResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCacheOrFetch();
  }

  Future<void> _loadCacheOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_trend_analysis');

    if (cached != null) {
      if (mounted) {
        setState(() {
          _analysisResult = cached;
          _isLoading = false;
        });
      }
    } else {
      _fetchAnalysis();
    }
  }

  Future<void> _fetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await AIService.getEagleEyeAnalysis(
        transactions: widget.transactions,
        dateRange: widget.dateRange,
        walletCount: widget.totalWallets,
        userCount: widget.totalUsers,
        totalLiquidity: widget.totalLiquidity,
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_trend_analysis', result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('AI Trend Analysis',
            style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.titleLarge?.color)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Refresh Analysis',
            onPressed: _isLoading ? null : _fetchAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildResultState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.blueAccent,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Archen Eye AI sedang menganalisis...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mencari pola dari jutaan titik data.',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle,
                size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Gagal Menganalisis',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchAnalysis,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Coba Lagi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: Theme.of(context).brightness == Brightness.dark ? [] : [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.sparkles,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Archen Eye AI Insight',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Analisis Makroekonomi Ekosistem',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MarkdownBody(
              data: _analysisResult ?? 'Tidak ada hasil analisis.',
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    letterSpacing: -0.5,
                    height: 1.5),
                h2: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                    letterSpacing: -0.5,
                    height: 1.5),
                h3: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleSmall?.color,
                    height: 1.5),
                p: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                    height: 1.6,
                    letterSpacing: 0.2),
                listBullet: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.blueAccent[100] : Colors.blueAccent[700]),
                strong: const TextStyle(fontWeight: FontWeight.w900),
                code: TextStyle(
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.blueAccent[100] : Colors.blueAccent[700],
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquoteDecoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? (Colors.blueAccent[100] ?? Colors.blue)
                          : Colors.blue)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                      left: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? (Colors.blueAccent[100] ?? Colors.blueAccent)
                              : Colors.blueAccent,
                          width: 4)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
