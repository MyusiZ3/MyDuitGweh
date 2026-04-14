import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'survey_data_screen.dart';
import '../../utils/currency_formatter.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import 'ai_trend_analysis_screen.dart';
import '../../utils/ui_helper.dart';
import '../../utils/app_theme.dart';

import '../../models/survey_config_model.dart';
import '../../services/ai_service.dart';
import 'app_config_screen.dart';

class GlobalInsightsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const GlobalInsightsScreen({super.key, this.isSuperAdmin = false});

  @override
  State<GlobalInsightsScreen> createState() => _GlobalInsightsScreenState();
}

class _GlobalInsightsScreenState extends State<GlobalInsightsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Period filter: 0=All Time, 1=7d, 2=30d, 3=6m
  int _selectedPeriod = 2; // Default to 30d
  final List<String> _periodLabels = [
    'All time',
    '7 Hari',
    '30 Hari',
    '6 Bulan'
  ];

  // Data states
  List<TransactionModel> _transactions = [];
  bool _isLoadingTx = true;
  String? _txError;
  Duration? _lastLoadDuration;

  // Growth Chart
  List<Map<String, dynamic>> _userGrowthData = [];
  bool _isLoadingGrowth = true;

  // Survey & AI Feedback
  StateSetter? _txSetState;

  // Streams
  late final Stream<QuerySnapshot> _walletsStream;
  late final Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _walletsStream = _firestore.collectionGroup('wallets').snapshots();
    _usersStream = _firestore.collection('users').snapshots();
    _loadTransactions();
    _loadUserGrowth();
  }

  Future<void> _loadUserGrowth() async {
    try {
      // 8 weeks = 56 days
      final growth = await _firestoreService.getUserRegistrations(daysBack: 56);
      if (mounted) {
        setState(() {
          _userGrowthData = growth;
          _isLoadingGrowth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGrowth = false;
        });
      }
    }
  }

  DateTime get _startDate {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // All Time
        return DateTime(2000); // Very old date to fetch everything
      case 1: // 7d
        return now.subtract(const Duration(days: 7));
      case 3: // 6m
        return DateTime(now.year, now.month - 6, now.day);
      default: // 30d (case 2)
        return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadTransactions() async {
    final stopwatch = Stopwatch()..start();
    // Only show shimmer on first load
    if (_transactions.isEmpty) {
      if (_txSetState != null) {
        _txSetState!(() {
          _isLoadingTx = true;
          _txError = null;
        });
      } else {
        setState(() {
          _isLoadingTx = true;
          _txError = null;
        });
      }
    }

    try {
      final txns = await _firestoreService.getGlobalTransactions(
        startDate: _startDate,
        endDate: DateTime.now(),
      );
      if (mounted) {
        if (_txSetState != null) {
          _txSetState!(() {
            _transactions = txns;
            _isLoadingTx = false;
            _txError = null;
            _lastLoadDuration = stopwatch.elapsed;
          });
        } else {
          setState(() {
            _transactions = txns;
            _isLoadingTx = false;
            _txError = null;
            _lastLoadDuration = stopwatch.elapsed;
          });
        }
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        if (_txSetState != null) {
          _txSetState!(() {
            _txError = e.toString();
            _isLoadingTx = false;
            _lastLoadDuration = stopwatch.elapsed;
          });
        } else {
          setState(() {
            _txError = e.toString();
            _isLoadingTx = false;
            _lastLoadDuration = stopwatch.elapsed;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                children: [
                  // ═══ STATS: Realtime Liquidity ═══
                  StreamBuilder<QuerySnapshot>(
                    stream: _walletsStream,
                    builder: (context, snapshot) {
                      double totalBalance = 0;
                      if (snapshot.hasData) {
                        for (var w in snapshot.data!.docs) {
                          totalBalance +=
                              (w.data() as Map<String, dynamic>)['balance'] ??
                                  0;
                        }
                      }
                      return _buildMainMetric(
                        context,
                        title: 'LIKUIDITAS SISTEM',
                        value: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? '...'
                            : CurrencyFormatter.formatCurrency(totalBalance),
                        subtitle: 'Total dana beredar di seluruh dompet user',
                        icon: Icons.account_balance_rounded,
                        color: isDark ? const Color(0xFF312E81) : Colors.indigo,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: _walletsStream,
                    builder: (context, snapshot) {
                      double totalBalance = 0;
                      int walletCount = 0;
                      if (snapshot.hasData) {
                        walletCount = snapshot.data!.docs.length;
                        for (var w in snapshot.data!.docs) {
                          totalBalance +=
                              (w.data() as Map<String, dynamic>)['balance'] ??
                                  0;
                        }
                      }
                      double avgBalance =
                          walletCount == 0 ? 0 : totalBalance / walletCount;
                      return Row(
                        children: [
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Rata-rata Dompet',
                              value: snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : CurrencyFormatter.formatCurrency(
                                      avgBalance),
                              icon: Icons.analytics_rounded,
                              color: isDark ? const Color(0xFF60A5FA) : Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Dompet Aktif',
                              value: snapshot.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : '$walletCount',
                              icon: Icons.wallet_rounded,
                              color: isDark ? const Color(0xFF2DD4BF) : Colors.teal,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // ═══ STATS: Realtime Users & Growth ═══
                  StreamBuilder<QuerySnapshot>(
                    stream: _usersStream,
                    builder: (context, userSnap) {
                      final now = DateTime.now();
                      final sevenDaysAgo =
                          now.subtract(const Duration(days: 7));
                      final allUsers = userSnap.data?.docs ?? [];
                      final userCount = allUsers.length;

                      int newUsersCount = 0;
                      for (var doc in allUsers) {
                        final data = doc.data() as Map<String, dynamic>;
                        final createdAt =
                            (data['createdAt'] as Timestamp?)?.toDate();
                        if (createdAt != null &&
                            createdAt.isAfter(sevenDaysAgo)) {
                          newUsersCount++;
                        }
                      }

                      final existingUsers = userCount - newUsersCount;
                      final growth = existingUsers == 0
                          ? (newUsersCount > 0 ? 100.0 : 0.0)
                          : (newUsersCount / existingUsers) * 100;

                      return Row(
                        children: [
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Total Pengguna',
                              value: userSnap.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : '$userCount User',
                              icon: Icons.people_alt_rounded,
                              color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Pertumbuhan',
                              value: userSnap.connectionState ==
                                      ConnectionState.waiting
                                  ? '...'
                                  : '+${growth.toStringAsFixed(1)}%',
                              icon: Icons.trending_up_rounded,
                              color: isDark ? const Color(0xFF4ADE80) : Colors.green,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ═══ ALL TX-DEPENDENT WIDGETS ═══
                  StatefulBuilder(
                    builder: (context, setTxState) {
                      _txSetState = setTxState;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isSuperAdmin) ...[
                            _buildSectionTitle('AI Macros Analysis',
                                Icons.auto_awesome_rounded),
                            const SizedBox(height: 16),
                            _buildAiAnalysisButton(context),
                            const SizedBox(height: 32),

                            _buildSectionTitle(
                                'Leaderboard', Icons.emoji_events_rounded),
                            const SizedBox(height: 16),
                            _buildLeaderboard(),
                            const SizedBox(height: 32),
                          ],

                          _buildPeriodFilter(),
                          const SizedBox(height: 24),

                          _buildSectionTitle(
                              'Tren Keuangan Global', Icons.show_chart_rounded),
                          const SizedBox(height: 16),
                          _buildCashFlowChart(),
                          const SizedBox(height: 32),

                          _buildSectionTitle(
                              'Distribusi Platform', Icons.pie_chart_rounded),
                          const SizedBox(height: 16),
                          _buildCategoryPieChart(),
                          const SizedBox(height: 32),

                          _buildSectionTitle(
                              'Aktivitas User', Icons.calendar_month_rounded),
                          const SizedBox(height: 16),
                          _buildUserActivityHeatmap(),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),

                  if (widget.isSuperAdmin) ...[
                    _buildSectionTitle(
                        'User Voice & AI Insights', Icons.psychology_rounded),
                    const SizedBox(height: 16),
                    _buildSurveyControlPanel(),
                    const SizedBox(height: 16),
                    const _AiSentimentAnalysisCard(),
                    const SizedBox(height: 32),
                  ] else ...[
                    _buildLockedSection(
                      title: '💰 Leaderboard & AI',
                      reason:
                          'Data finansial mendalam bersifat rahasia. Hanya SuperAdmin/Owner yang dapat mengakses.',
                      icon: Icons.lock_rounded,
                    ),
                    const SizedBox(height: 32),
                  ],

                  _buildSectionTitle(
                      'Pertumbuhan User Baru', Icons.group_add_rounded),
                  const SizedBox(height: 16),
                  _buildUserGrowthChart(),

                  const SizedBox(height: 32),
                  Text('Economy Health Index',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: theme.textTheme.titleLarge?.color)),
                  const SizedBox(height: 16),
                  Builder(builder: (context) {
                    final now = DateTime.now();
                    final last24h = now.subtract(const Duration(hours: 24));
                    final vol24h = _transactions
                        .where((tx) => tx.date.isAfter(last24h))
                        .fold(0.0, (acc, tx) => acc + tx.amount);

                    String circulationStatus = 'Quiet';
                    Color circulationColor = Colors.grey;
                    if (vol24h > 10000000) {
                      circulationStatus = 'Hyper Active';
                      circulationColor = Colors.orange;
                    } else if (vol24h > 1000000) {
                      circulationStatus = 'Active Flow';
                      circulationColor = Colors.amber;
                    }

                    final latency = _lastLoadDuration?.inMilliseconds ?? 0;
                    String latencyStatus =
                        latency == 0 ? 'Excellent' : '${latency}ms';
                    Color latencyColor = Colors.green;
                    if (latency > 500) {
                      latencyStatus += ' (Slow)';
                      latencyColor = Colors.redAccent;
                    } else if (latency > 200) {
                      latencyStatus += ' (Good)';
                      latencyColor = Colors.blue;
                    } else {
                      latencyStatus += ' (Fast)';
                      latencyColor = Colors.purple;
                    }

                    return Column(
                      children: [
                        _buildIndicatorTile(
                            'Cash Circulation',
                            vol24h == 0
                                ? 'No recent activity'
                                : '$circulationStatus (${CurrencyFormatter.formatCurrency(vol24h)})',
                            Icons.bolt_rounded,
                            circulationColor),
                        _buildIndicatorTile(
                            'System Integrity',
                            _txError != null
                                ? 'Issues detected'
                                : 'Syncing & Encrypted (SSL)',
                            Icons.verified_user_rounded,
                            _txError != null ? Colors.red : Colors.green),
                        _buildIndicatorTile('Query Latency', latencyStatus,
                            Icons.speed_rounded, latencyColor),
                      ],
                    );
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // NEW WIDGETS: EAGLE EYE
  // ══════════════════════════════════════════════════

  Widget _buildPeriodFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_periodLabels.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _periodLabels[index],
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700]),
                ),
              ),
              selected: isSelected,
              selectedColor: isDark ? AppColors.primary : Colors.black,
              backgroundColor: isDark ? theme.cardColor : Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              showCheckmark: false,
              onSelected: (selected) {
                if (selected && _selectedPeriod != index) {
                  if (_txSetState != null) {
                    _txSetState!(() => _selectedPeriod = index);
                  } else {
                    setState(() => _selectedPeriod = index);
                  }
                  _loadTransactions();
                }
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.iconTheme.color?.withOpacity(0.8)),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: theme.textTheme.titleLarge?.color,
                letterSpacing: -0.5)),
      ],
    );
  }

  // ── FITUR #1: Cash Flow Line Chart ──
  Widget _buildCashFlowChart() {
    if (_isLoadingTx) {
      return _buildShimmerChart();
    }
    if (_txError != null) {
      return _buildChartError(_txError!);
    }
    if (_transactions.isEmpty) {
      return _buildChartEmpty('Belum ada data transaksi di periode ini.');
    }

    // Group by date
    final Map<String, double> incomeByDay = {};
    final Map<String, double> expenseByDay = {};
    final dateFormat = DateFormat('MM/dd');

    for (var tx in _transactions) {
      final key = dateFormat.format(tx.date);
      if (tx.isIncome) {
        incomeByDay[key] = (incomeByDay[key] ?? 0) + tx.amount;
      } else {
        expenseByDay[key] = (expenseByDay[key] ?? 0) + tx.amount;
      }
    }

    // Merge all date keys and sort
    final allKeys = {...incomeByDay.keys, ...expenseByDay.keys}.toList()
      ..sort();
    if (allKeys.isEmpty) {
      return _buildChartEmpty('Tidak ada transaksi ditemukan.');
    }

    // Limit to latest 15 data points for readability
    final displayKeys =
        allKeys.length > 15 ? allKeys.sublist(allKeys.length - 15) : allKeys;

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < displayKeys.length; i++) {
      final key = displayKeys[i];
      final inc = incomeByDay[key] ?? 0;
      final exp = expenseByDay[key] ?? 0;
      incomeSpots.add(FlSpot(i.toDouble(), inc));
      expenseSpots.add(FlSpot(i.toDouble(), exp));
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }

    maxY = maxY * 1.15; // padding top
    if (maxY == 0) maxY = 100;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return SizedBox(
      height: 280,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoadingTx
            ? _buildShimmerChart(height: 280)
            : _txError != null
                ? _buildChartError(_txError!)
                : Container(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor.withOpacity(0.1),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              interval: maxY > 0 ? maxY / 4 : 1,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return Text(
                                  _formatCompact(value),
                                  style: TextStyle(
                                      fontSize: 9, color: theme.hintColor),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: (displayKeys.length / 5)
                                  .ceilToDouble()
                                  .clamp(1, 10),
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= displayKeys.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(displayKeys[idx],
                                      style: TextStyle(
                                          fontSize: 9,
                                          color: theme.hintColor)),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (displayKeys.length - 1).toDouble(),
                        minY: 0,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: isDark ? const Color(0xFF1E293B) : Colors.black87,
                            tooltipRoundedRadius: 12,
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final isIncome = spot.barIndex == 0;
                                return LineTooltipItem(
                                  '${isIncome ? '📈 Income' : '📉 Expense'}\n'
                                  '${CurrencyFormatter.formatCurrency(spot.y)}',
                                  TextStyle(
                                    color: isIncome
                                        ? const Color(0xFF4ADE80)
                                        : const Color(0xFFF87171),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: incomeSpots,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: const Color(0xFF4ADE80),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF4ADE80).withOpacity(0.08),
                            ),
                          ),
                          LineChartBarData(
                            spots: expenseSpots,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: const Color(0xFFF87171),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFFF87171).withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ── FITUR #2: Category Pie Chart ──
  Widget _buildCategoryPieChart() {
    final theme = Theme.of(context);

    return Container(
      height: 480,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoadingTx
            ? _buildShimmerChart(height: 480)
            : _txError != null
                ? _buildChartError(_txError!)
                : (() {
                    final expenses =
                        _transactions.where((tx) => tx.isExpense).toList();
                    if (expenses.isEmpty) {
                      return _buildChartEmpty('Belum ada data pengeluaran.');
                    }

                    // Group by category
                    final Map<String, double> categoryMap = {};
                    double totalExpense = 0;
                    for (var tx in expenses) {
                      categoryMap[tx.category] =
                          (categoryMap[tx.category] ?? 0) + tx.amount;
                      totalExpense += tx.amount;
                    }

                    final sorted = categoryMap.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    final top5 = sorted.take(5).toList();
                    if (sorted.length > 5) {
                      double othersTotal = 0;
                      for (int i = 5; i < sorted.length; i++) {
                        othersTotal += sorted[i].value;
                      }
                      if (othersTotal > 0) {
                        top5.add(MapEntry('Lainnya', othersTotal));
                      }
                    }

                    final pieColors = [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFF59E0B),
                      const Color(0xFFEF4444),
                      const Color(0xFF14B8A6),
                      Colors.grey[400]!,
                    ];

                    int localTouchedPieIndex = -1;
                    return StatefulBuilder(builder: (context, setStatePie) {
                      return Column(
                        key: ValueKey('pie_content_$_selectedPeriod'),
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection ==
                                            null) {
                                      if (localTouchedPieIndex != -1) {
                                        setStatePie(
                                            () => localTouchedPieIndex = -1);
                                      }
                                      return;
                                    }
                                    final idx = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
                                    if (localTouchedPieIndex != idx) {
                                      setStatePie(
                                          () => localTouchedPieIndex = idx);
                                    }
                                  },
                                ),
                                sectionsSpace: 3,
                                centerSpaceRadius: 50,
                                sections: List.generate(top5.length, (i) {
                                  final isTouched = i == localTouchedPieIndex;
                                  final entry = top5[i];
                                  final pct =
                                      (entry.value / totalExpense * 100);
                                  return PieChartSectionData(
                                    value: entry.value,
                                    color: pieColors[i % pieColors.length],
                                    radius: isTouched ? 55 : 45,
                                    title: '${pct.toStringAsFixed(0)}%',
                                    titleStyle: TextStyle(
                                      fontSize: isTouched ? 14 : 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                    titlePositionPercentageOffset: 0.55,
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ...List.generate(top5.length, (i) {
                            final entry = top5[i];
                            final pct = (entry.value / totalExpense * 100);
                            final isSelected = i == localTouchedPieIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? pieColors[i % pieColors.length]
                                        .withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: pieColors[i % pieColors.length],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    TransactionCategory.getIconForCategory(
                                        entry.key),
                                    size: 16,
                                    color: isSelected
                                        ? pieColors[i % pieColors.length]
                                        : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 13,
                                            color: isSelected
                                                ? theme.textTheme.titleMedium?.color
                                                : theme.textTheme.bodyMedium?.color)),
                                  ),
                                  Text('${pct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: theme.hintColor)),
                                  const SizedBox(width: 12),
                                  Text(
                                      CurrencyFormatter.formatCurrency(
                                          entry.value),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: isSelected
                                              ? theme.textTheme.titleMedium?.color
                                              : theme.textTheme.bodyMedium?.color)),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    });
                  })(),
      ),
    );
  }

  // ── FITUR #5: User Activity Heatmap ──
  Widget _buildUserActivityHeatmap() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (_isLoadingTx) return _buildShimmerChart(height: 250);
    if (_transactions.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        ),
        child: Center(child: Text("Belum ada data transaksi", style: TextStyle(color: theme.hintColor))),
      );
    }

    // 7 rows (Sen-Min) x 4 cols (Pagi, Siang, Sore, Malam)
    List<List<int>> counts = List.generate(7, (_) => List.filled(4, 0));
    int maxCount = 0;

    final dayNamesFull = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    final slotNames = [
      'Pagi (06-12)',
      'Siang (12-17)',
      'Sore (17-21)',
      'Malam (21-06)'
    ];

    for (var tx in _transactions) {
      final date = tx.date;
      int day = date.weekday - 1; // 0=Monday..6=Sunday
      int h = date.hour;
      int col = 0;
      if (h >= 6 && h < 12) {
        col = 0; // Pagi: 06-11
      } else if (h >= 12 && h < 17) {
        col = 1; // Siang: 12-16
      } else if (h >= 17 && h < 21) {
        col = 2; // Sore: 17-20
      } else {
        col = 3; // Malam: 21-05
      }

      counts[day][col]++;
      if (counts[day][col] > maxCount) maxCount = counts[day][col];
    }

    // Temukan peak activity untuk header
    String peakText = 'Peak Activity: Menghitung...';
    if (maxCount > 0) {
      int peakDay = 0;
      int peakSlot = 0;
      for (int i = 0; i < 7; i++) {
        for (int j = 0; j < 4; j++) {
          if (counts[i][j] == maxCount) {
            peakDay = i;
            peakSlot = j;
          }
        }
      }
      peakText = 'Peak: ${dayNamesFull[peakDay]} ${slotNames[peakSlot]}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                peakText,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(width: 32),
              ...slotNames.map((t) => Expanded(
                    child: Center(
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400]))),
                  ))
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(7, (r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'][r],
                        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  ...List.generate(4, (c) {
                    final val = counts[r][c];
                    final intensity = maxCount == 0 ? 0.0 : val / maxCount;
                    Color color;
                    if (intensity == 0) {
                      color = isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]!;
                    } else if (intensity < 0.25) {
                      color = isDark ? Colors.amber[900]!.withOpacity(0.4) : Colors.amber[200]!;
                    } else if (intensity < 0.6) {
                      color = isDark ? Colors.amber[600]! : Colors.amber[500]!;
                    } else {
                      color = isDark ? Colors.orangeAccent : Colors.deepOrange;
                    }

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendNode(isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100]!, 'Kosong'),
              const SizedBox(width: 12),
              _buildLegendNode(isDark ? Colors.amber[900]!.withOpacity(0.4) : Colors.amber[200]!, 'Rendah'),
              const SizedBox(width: 12),
              _buildLegendNode(isDark ? Colors.amber[600]! : Colors.amber[500]!, 'Sedang'),
              const SizedBox(width: 12),
              _buildLegendNode(isDark ? Colors.orangeAccent : Colors.deepOrange, 'Tinggi'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendNode(Color color, String label) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
      ],
    );
  }

  // ── FITUR #6: New User Growth Chart ──
  Widget _buildUserGrowthChart() {
    if (_isLoadingGrowth) return _buildShimmerChart(height: 250);

    final now = DateTime.now();
    List<int> weeklyCounts = List.filled(8, 0);
    int totalNewUsersIn8Weeks = 0;

    for (var user in _userGrowthData) {
      final createdAtRaw = user['createdAt'];
      if (createdAtRaw == null) continue;
      final createdAt = (createdAtRaw as Timestamp).toDate();

      final difference = now.difference(createdAt).inDays;
      if (difference < 56) {
        int weekIndex =
            7 - (difference ~/ 7);
        if (weekIndex >= 0 && weekIndex < 8) {
          weeklyCounts[weekIndex]++;
          totalNewUsersIn8Weeks++;
        }
      }
    }

    double maxY =
        weeklyCounts.isEmpty ? 5 : weeklyCounts.reduce(max).toDouble() * 1.2;
    if (maxY == 0) maxY = 5;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total User Baru (8 Minggu)',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalNewUsersIn8Weeks User',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? const Color(0xFF818CF8) : Colors.indigo),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF818CF8) : Colors.indigo).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.trending_up_rounded,
                    color: isDark ? const Color(0xFF818CF8) : Colors.indigo, size: 24),
              )
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: isDark ? const Color(0xFF334155) : Colors.indigo,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        'Minggu ${(groupIndex + 1)}\n',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()} user baru',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'W${value.toInt() + 1}',
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white54 : Colors.grey[500],
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style:
                              TextStyle(color: isDark ? Colors.white38 : Colors.grey[400], fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      maxY / 5 > 0 ? (maxY / 5).ceilToDouble() : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                barGroups: List.generate(8, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: weeklyCounts[index].toDouble(),
                        color: isDark ? const Color(0xFF818CF8) : Colors.indigo,
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                        ),
                      )
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FITUR #4: AI Trend Analysis Button (SuperAdmin Only) ──
  Widget _buildAiAnalysisButton(BuildContext context) {
    if (_isLoadingTx) {
      return _buildShimmerChart(height: 80);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(isDark ? 0.1 : 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );

            try {
              final userSnap = await _firestore.collection('users').get();
              final walletSnap =
                  await _firestore.collectionGroup('wallets').get();
              double totalLiq = 0;
              for (var doc in walletSnap.docs) {
                final data = doc.data();
                totalLiq += data['balance'] ?? 0;
              }

              if (context.mounted) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiTrendAnalysisScreen(
                      transactions: _transactions,
                      dateRange:
                          DateTimeRange(start: _startDate, end: DateTime.now()),
                      totalUsers: userSnap.docs.length,
                      totalWallets: walletSnap.docs.length,
                      totalLiquidity: totalLiq,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                UIHelper.showErrorSnackBar(
                    context, 'Error preparing AI data: $e');
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate AI Trend Analysis',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Analisis data performa keuangan global platform dengan Gemini/Groq.',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── FITUR #3: Leaderboard (SuperAdmin Only) ──
  Widget _buildLeaderboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final Map<String, double> spenderMap = {};
    final Map<String, double> earnerMap = {};
    final Map<String, String> userNames = {};

    for (var tx in _transactions) {
      userNames[tx.createdBy] = tx.createdByName;
      if (tx.isExpense) {
        spenderMap[tx.createdBy] = (spenderMap[tx.createdBy] ?? 0) + tx.amount;
      } else {
        earnerMap[tx.createdBy] = (earnerMap[tx.createdBy] ?? 0) + tx.amount;
      }
    }

    final topSpenders = spenderMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEarners = earnerMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              decoration: BoxDecoration(
                color: isDark ? theme.scaffoldBackgroundColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: theme.textTheme.bodySmall?.color,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                indicator: BoxDecoration(
                  color: isDark ? AppColors.primary.withOpacity(0.2) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: AppColors.primary.withOpacity(0.5)) : null,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '🔥 Big Spenders'),
                  Tab(text: '💰 Top Earners'),
                ],
              ),
            ),
            SizedBox(
              height:
                  (max(topSpenders.take(5).length, topEarners.take(5).length)
                              .clamp(1, 5) *
                          56.0) +
                      16,
              child: TabBarView(
                children: [
                  _buildLeaderList(topSpenders.take(5).toList(), userNames,
                      isExpense: true),
                  _buildLeaderList(topEarners.take(5).toList(), userNames,
                      isExpense: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderList(
      List<MapEntry<String, double>> entries, Map<String, String> names,
      {required bool isExpense}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Belum ada data.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13)),
        ),
      );
    }
    final medals = ['🥇', '🥈', '🥉'];
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final name = names[entry.key] ?? 'Unknown';
        final initials = name.isNotEmpty
            ? name
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0] : '')
                .take(2)
                .join()
            : '?';
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                index < 3 ? Colors.amber.withOpacity(isDark ? 0.1 : 0.05) : null,
            borderRadius: BorderRadius.circular(12),
            border: index < 3 && isDark ? Border.all(color: Colors.amber.withOpacity(0.2)) : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  index < 3 ? medals[index] : '${index + 1}.',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors
                    .primaries[entry.key.hashCode % Colors.primaries.length]
                    .withOpacity(0.15),
                child: Text(initials.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.primaries[
                          entry.key.hashCode % Colors.primaries.length],
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                CurrencyFormatter.formatCurrency(entry.value),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: isExpense
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Locked Section (for non-SuperAdmin) ──
  Widget _buildLockedSection({
    required String title,
    required String reason,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 28, color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: theme.textTheme.bodyMedium?.color)),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, color: theme.hintColor, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🔒 SuperAdmin Only',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: Colors.amber)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──
  String _formatCompact(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  Widget _buildShimmerChart({double height = 220}) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 12),
            Text('Memuat data...',
                style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartError(String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withOpacity(isDark ? 0.3 : 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: isDark ? Colors.red[300] : Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Gagal memuat: $error',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.red[200] : Colors.red[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildChartEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 40, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // EXISTING WIDGETS (preserved)
  // ══════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIVE INSIGHTS',
                style: TextStyle(
                    color: theme.textTheme.titleLarge?.color,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    fontSize: 24)),
            Text(
                widget.isSuperAdmin
                    ? 'ARCHEN EYE — FULL ACCESS'
                    : 'REAL-TIME SYSTEM MONITOR',
                style: TextStyle(
                    color: widget.isSuperAdmin
                        ? Colors.amber[700]
                        : theme.hintColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 10)),
          ],
        ),
        background: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    color:
                        widget.isSuperAdmin ? Colors.amber.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMetric(BuildContext context,
      {required String title,
      required String value,
      required String subtitle,
      required IconData icon,
      required Color color}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
                right: -20,
                top: -20,
                child: Icon(icon,
                    size: 120, color: Colors.white.withOpacity(0.1))),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 24),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                  ),
                  const SizedBox(height: 12),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetric(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.textTheme.titleLarge?.color)),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: color, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // -- User Voice & AI Insights Widgets --

  Widget _buildSurveyControlPanel() {
    return StreamBuilder<SurveyConfigModel>(
      stream: _firestoreService.getSurveyConfigStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final config = snapshot.data;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final theme = Theme.of(context);
        final isAvailable = config?.isAvailable ?? false;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAvailable
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isAvailable ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAvailable
                              ? 'Survei Sedang Aktif'
                              : 'Survei Nonaktif',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          isAvailable
                              ? 'User dapat mengisi survei kepuasan.'
                              : 'Fitur survei ditutup untuk sementara.',
                          style:
                              TextStyle(color: theme.hintColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (config != null) ...[
                _buildStatusRow(
                    'Min. Transaksi', '${config.minTransactions} Transaksi'),
                const SizedBox(height: 12),
                _buildStatusRow(
                    'Min. Umur Akun', '${config.minAccountAgeDays} Hari'),
                const Divider(height: 32),
                const Text(
                  'Stats Partisipasi',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: _usersStream,
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(
                          child: LinearProgressIndicator(minHeight: 2));
                    }
                    final users = userSnapshot.data!.docs;
                    final totalUsers = users.length;
                    final doneCount = users
                        .where((doc) =>
                            (doc.data() as Map<String, dynamic>)['surveyDone'] ==
                            true)
                        .length;
                    final pendingCount = totalUsers - doneCount;

                    return Column(
                      children: [
                        _buildStatusRow('Sudah Isi Survey',
                            '${CurrencyFormatter.formatNumber(doneCount)} Orang'),
                        const SizedBox(height: 12),
                        _buildStatusRow('Belum Isi Survey',
                            '${CurrencyFormatter.formatNumber(pendingCount)} Orang'),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SurveyDataScreen()),
                          );
                        },
                        icon: const Icon(Icons.analytics_rounded, size: 18),
                        label: const Text('LIHAT DATA & ISI SURVEI USER',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.tealAccent : Colors.teal,
                          backgroundColor: (isDark ? Colors.tealAccent : Colors.teal).withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AppConfigScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                        label: const Text('UBAH KONFIGURASI DI APP SETTINGS',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.indigo,
                          backgroundColor: Colors.indigo.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).hintColor, fontWeight: FontWeight.w600)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodyMedium?.color)),
      ],
    );
  }
}

class _AiSentimentAnalysisCard extends StatefulWidget {
  const _AiSentimentAnalysisCard();

  @override
  State<_AiSentimentAnalysisCard> createState() => _AiSentimentAnalysisCardState();
}

class _AiSentimentAnalysisCardState extends State<_AiSentimentAnalysisCard> {
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isAnalyzingFeedback = false;
  Map<String, dynamic>? _aiSentimentResult;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_alt_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Sentiment Analysis',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                    Text('Ringkasan suara user oleh Archen AI',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isAnalyzingFeedback ? null : _runAiFeedbackAnalysis,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: _isAnalyzingFeedback ? Colors.white24 : Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isAnalyzingFeedback)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Archen sedang membaca pikiran user...',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            )
          else if (_aiSentimentResult == null)
            const Center(
              child: Text(
                  'Klik "Refresh" untuk memulai analisis sentimen terbaru',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            _buildAiResultContent(),
        ],
      ),
    );
  }

  Widget _buildAiResultContent() {
    final sentiment = _aiSentimentResult!['sentiment_score'] ?? 'N/A';
    final summary = _aiSentimentResult!['summary'] ?? '';
    final requests = (_aiSentimentResult!['top_feature_requests'] as List? ?? [])
        .where((r) => r.toString().trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildSentimentBadge(sentiment),
                Text(
                    'BERDASARKAN ${CurrencyFormatter.formatNumber(_aiSentimentResult!['sample_size'] ?? 0)} FEEDBACK',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(summary,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.5)),
        const SizedBox(height: 20),
        if (requests.isNotEmpty) ...[
          const Text('PRIORITAS FITUR:',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...requests.map(
            (r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(r.toString(),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12))),
                  ],
                )),
          ),
        ],
      ],
    );
  }

  Widget _buildSentimentBadge(String score) {
    Color color;
    IconData icon;
    if (score.contains('Positif')) {
      color = Colors.greenAccent;
      icon = Icons.sentiment_very_satisfied_rounded;
    } else if (score.contains('Negatif')) {
      color = Colors.redAccent;
      icon = Icons.sentiment_very_dissatisfied_rounded;
    } else {
      color = Colors.amberAccent;
      icon = Icons.sentiment_neutral_rounded;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(score,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _runAiFeedbackAnalysis() async {
    setState(() => _isAnalyzingFeedback = true);
    try {
      final feedbacks =
          await _firestoreService.getRecentFeedbacks(limit: 50).first;

      if (feedbacks.isEmpty) {
        throw 'Belum ada feedback yang masuk untuk dianalisis.';
      }

      final result = await _aiService.analyzeFeedbackSentiment(feedbacks);

      String cleanResult =
          result.replaceAll('```json', '').replaceAll('```', '').trim();

      final startIdx = cleanResult.indexOf('{');
      final endIdx = cleanResult.lastIndexOf('}');

      if (startIdx == -1 || endIdx == -1 || endIdx <= startIdx) {
        throw 'AI mengembalikan format yang tidak valid. Coba lagi.';
      }

      cleanResult = cleanResult.substring(startIdx, endIdx + 1);
      cleanResult = cleanResult.replaceAll(RegExp(r',\s*]'), ']');
      cleanResult = cleanResult.replaceAll(RegExp(r',\s*}'), '}');

      Map<String, dynamic>? parsedResult;
      try {
        parsedResult = jsonDecode(cleanResult) as Map<String, dynamic>;
      } catch (parseErr) {
        debugPrint('JSON parse failed: $parseErr, raw: $cleanResult');
        parsedResult = {
          'sentiment_score': 'Netral',
          'summary': result.length > 200 ? result.substring(0, 200) : result,
          'top_feature_requests': ['Analisis perlu di-refresh (format error)'],
        };
      }

      if (mounted) {
        setState(() {
          _aiSentimentResult = parsedResult;
          _aiSentimentResult?['sample_size'] = feedbacks.length;
          _isAnalyzingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzingFeedback = false);
        UIHelper.showErrorSnackBar(context, e.toString());
      }
    }
  }
}
