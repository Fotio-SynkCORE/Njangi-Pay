import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../theme/app_theme.dart';
import '../services/personal_finance_service.dart';
import '../services/group_service.dart';
import 'upgrade_plan_screen.dart';


/// ==========================================================================
/// PERSONAL FINANCE SCREEN
/// ==========================================================================

class PersonalFinanceScreen extends StatelessWidget {
  const PersonalFinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final groupService = GroupService();

    return StreamBuilder<List<NjangiGroup>>(
      stream: groupService.myGroups(),
      builder: (context, groupSnap) {
        if (groupSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final groups = groupSnap.data ?? [];

        final hasEligibleGroup =
            groups.any((g) => g.planTier != 'free');

        if (!hasEligibleGroup) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Personal finance'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: AppColors.inkMuted,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Standard plan required',
                      style:
                          Theme.of(context).textTheme.titleLarge,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Personal finance tracking unlocks once one of your Njangi groups is on the Standard or Premium plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.inkMuted,
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (groups.isEmpty)
                      const Text(
                        'Create or join a Njangi group first, then upgrade it.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      )
                    else if (groups.length == 1)
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UpgradePlanScreen(
                              groupId: groups.first.id,
                              currentTier:
                                  groups.first.planTier,
                              groupName:
                                  groups.first.name,
                            ),
                          ),
                        ),
                        child: Text(
                          'Upgrade ${groups.first.name}',
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Choose a group to upgrade:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.inkMuted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          ...groups.map(
                            (g) => Card(
                              child: ListTile(
                                title: Text(g.name),
                                subtitle: Text(
                                  g.planTier == 'free'
                                      ? 'Free plan'
                                      : g.planTier,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                ),
                                onTap: () =>
                                    Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        UpgradePlanScreen(
                                      groupId: g.id,
                                      currentTier:
                                          g.planTier,
                                      groupName:
                                          g.name,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        return _PersonalFinanceContent(
          service: PersonalFinanceService(),
        );
      },
    );
  }
}


/// ==========================================================================
/// PERSONAL FINANCE CONTENT
/// ==========================================================================

class _PersonalFinanceContent extends StatelessWidget {
  final PersonalFinanceService service;

  const _PersonalFinanceContent({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: const Text(
          'Personal finance',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(
          context,
          service,
        ),
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add entry',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: StreamBuilder<List<FinanceEntry>>(
        stream: service.entries(),
        builder: (context, snap) {
          if (snap.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Could not load: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final entries = snap.data ?? [];

          int income = 0;
          int expense = 0;

          for (final e in entries) {
            if (e.type == 'income') {
              income += e.amount;
            } else {
              expense += e.amount;
            }
          }

          final balance = income - expense;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              100,
            ),
            children: [
              _BalanceCard(
                balance: balance,
                income: income,
                expense: expense,
              ),

              const SizedBox(height: 18),

              if (entries.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Money overview',
                  subtitle:
                      'Your income and spending over time',
                ),

                const SizedBox(height: 10),

                _FinanceChart(
                  entries: entries,
                ),

                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Recent transactions',
                  subtitle:
                      '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                ),

                const SizedBox(height: 10),

                ...entries.map(
                  (e) => _TransactionCard(
                    entry: e,
                  ),
                ),
              ] else
                const _EmptyFinanceState(),
            ],
          );
        },
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    PersonalFinanceService service,
  ) {
    final amountController =
        TextEditingController();

    final categoryController =
        TextEditingController();

    String type = 'expense';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom:
                  MediaQuery.of(ctx)
                          .viewInsets
                          .bottom +
                      20,
            ),

            decoration: BoxDecoration(
              color: Theme.of(ctx)
                  .scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Add transaction',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Record your income or expense',
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 20),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'income',
                      icon: Icon(
                        Icons.arrow_downward,
                      ),
                      label: Text('Income'),
                    ),
                    ButtonSegment(
                      value: 'expense',
                      icon: Icon(
                        Icons.arrow_upward,
                      ),
                      label: Text('Expense'),
                    ),
                  ],

                  selected: {type},

                  onSelectionChanged: (s) {
                    setSheetState(() {
                      type = s.first;
                    });
                  },
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: amountController,
                  keyboardType:
                      TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    hintText: 'e.g. 50000',
                    prefixIcon:
                        const Icon(
                      Icons.payments_outlined,
                    ),
                    suffixText: 'XAF',
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller:
                      categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    hintText:
                        'e.g. Salary, Transport',
                    prefixIcon:
                        const Icon(
                      Icons.category_outlined,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount =
                          int.tryParse(
                        amountController.text
                            .trim(),
                      );

                      if (amount == null ||
                          amount <= 0) {
                        return;
                      }

                      await service.addEntry(
                        type: type,
                        amount: amount,
                        category:
                            categoryController
                                .text
                                .trim(),
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text(
                      'Save transaction',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


/// ==========================================================================
/// BALANCE CARD
/// ==========================================================================

class _BalanceCard extends StatelessWidget {
  final int balance;
  final int income;
  final int expense;

  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.indigo,
            AppColors.indigo
                .withOpacity(0.75),
          ],
        ),

        borderRadius:
            BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: AppColors.indigo
                .withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.15),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),

                child: const Icon(
                  Icons
                      .account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              const Text(
                'Available balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            '${balance.abs()} XAF',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            positive
                ? 'You are currently in a positive balance'
                : 'Your expenses are higher than your income',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(
                child: _BalanceMiniStat(
                  icon:
                      Icons.arrow_downward_rounded,
                  label: 'Income',
                  amount: income,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _BalanceMiniStat(
                  icon:
                      Icons.arrow_upward_rounded,
                  label: 'Expenses',
                  amount: expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


/// ==========================================================================
/// BALANCE MINI STAT
/// ==========================================================================

class _BalanceMiniStat
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final int amount;

  const _BalanceMiniStat({
    required this.icon,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),

      decoration: BoxDecoration(
        color:
            Colors.white.withOpacity(0.12),
        borderRadius:
            BorderRadius.circular(14),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '$amount XAF',
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// ==========================================================================
/// DAILY FINANCE DATA
/// ==========================================================================

class _DailyFinanceData {
  final DateTime date;

  int income = 0;
  int expense = 0;
  int balance = 0;

  _DailyFinanceData({
    required this.date,
  });
}


/// ==========================================================================
/// FINANCE CHART
/// ==========================================================================

class _FinanceChart extends StatefulWidget {
  final List<FinanceEntry> entries;

  const _FinanceChart({
    required this.entries,
  });

  @override
  State<_FinanceChart> createState() =>
      _FinanceChartState();
}


class _FinanceChartState
    extends State<_FinanceChart> {

  late ScrollController
      _scrollController;

  @override
  void initState() {
    super.initState();

    _scrollController =
        ScrollController();

    /*
     * Automatically move the graph
     * to the newest day.
     *
     * This means when today is Aug 27,
     * the graph opens around Aug 27.
     */
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _scrollToLatest();
    });
  }

  @override
  void didUpdateWidget(
    covariant _FinanceChart oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    /*
     * When a new transaction is added,
     * the StreamBuilder rebuilds the chart.
     *
     * Move back to today's end so the
     * new transaction is immediately visible.
     */
    if (oldWidget.entries.length !=
        widget.entries.length) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        _scrollToLatest();
      });
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController
          .position
          .maxScrollExtent,
      duration:
          const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dailyData =
        _buildDailyFinanceData(
      widget.entries,
    );

    if (dailyData.isEmpty) {
      return const SizedBox.shrink();
    }

    final incomeSpots =
        <FlSpot>[];

    final expenseSpots =
        <FlSpot>[];

    final balanceSpots =
        <FlSpot>[];

    double highestValue = 0;
    double lowestValue = 0;

    for (int i = 0;
        i < dailyData.length;
        i++) {
      final day = dailyData[i];

      incomeSpots.add(
        FlSpot(
          i.toDouble(),
          day.income.toDouble(),
        ),
      );

      expenseSpots.add(
        FlSpot(
          i.toDouble(),
          day.expense.toDouble(),
        ),
      );

      balanceSpots.add(
        FlSpot(
          i.toDouble(),
          day.balance.toDouble(),
        ),
      );

      final values = [
        day.income.toDouble(),
        day.expense.toDouble(),
        day.balance.toDouble(),
      ];

      for (final value in values) {
        if (value > highestValue) {
          highestValue = value;
        }

        if (value < lowestValue) {
          lowestValue = value;
        }
      }
    }

    /*
     * Give the chart some breathing space.
     */
    if (highestValue == lowestValue) {
      highestValue += 100;
      lowestValue -= 100;
    }

    final range =
        highestValue - lowestValue;

    final chartMax =
        highestValue + (range * 0.15);

    final chartMin =
        lowestValue - (range * 0.15);

    /*
     * IMPORTANT:
     *
     * The graph gets a fixed amount of
     * horizontal space per day.
     *
     * So 10 days might become:
     *
     * 10 × 85 = 850 pixels
     *
     * Since the phone is much narrower,
     * the user can swipe horizontally.
     */
    final screenWidth =
        MediaQuery.of(context)
            .size
            .width;

    final minimumWidth =
        screenWidth - 70;

    final dailyWidth =
        dailyData.length * 85.0;

    final chartWidth =
        dailyWidth > minimumWidth
            ? dailyWidth
            : minimumWidth;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        18,
        12,
        12,
      ),

      decoration: BoxDecoration(
        color:
            Theme.of(context).cardColor,

        borderRadius:
            BorderRadius.circular(24),

        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withOpacity(0.5),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.04,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        children: [
          /// ---------------------------------------------------------------
          /// LEGEND
          /// ---------------------------------------------------------------

          Row(
            children: const [
              _ChartLegend(
                color: AppColors.green,
                label: 'Income',
              ),

              SizedBox(width: 18),

              _ChartLegend(
                color: AppColors.clay,
                label: 'Expenses',
              ),

              SizedBox(width: 18),

              _ChartLegend(
                color: AppColors.indigo,
                label: 'Balance',
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment:
                Alignment.centerLeft,
            child: Text(
              'Swipe left to see previous days',
              style: TextStyle(
                fontSize: 11,
                color:
                    AppColors.inkMuted,
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// ---------------------------------------------------------------
          /// HORIZONTAL SCROLLABLE GRAPH
          /// ---------------------------------------------------------------

          SizedBox(
            height: 250,

            child: SingleChildScrollView(
              controller:
                  _scrollController,

              scrollDirection:
                  Axis.horizontal,

              physics:
                  const BouncingScrollPhysics(),

              child: SizedBox(
                width: chartWidth,

                child: LineChart(
                  LineChartData(
                    minX: 0,

                    maxX:
                        dailyData.length > 1
                            ? (dailyData.length -
                                    1)
                                .toDouble()
                            : 1,

                    minY: chartMin,

                    maxY: chartMax,

                    clipData:
                        const FlClipData.all(),

                    /// -----------------------------------------------------
                    /// GRID
                    /// -----------------------------------------------------

                    gridData:
                        FlGridData(
                      show: true,

                      drawVerticalLine:
                          false,

                      horizontalInterval:
                          _calculateInterval(
                        chartMin,
                        chartMax,
                      ),

                      getDrawingHorizontalLine:
                          (value) {
                        return FlLine(
                          color: Theme.of(
                            context,
                          )
                              .dividerColor
                              .withOpacity(
                                0.35,
                              ),
                          strokeWidth: 1,
                        );
                      },
                    ),

                    borderData:
                        FlBorderData(
                      show: false,
                    ),

                    /// -----------------------------------------------------
                    /// TITLES
                    /// -----------------------------------------------------

                    titlesData:
                        FlTitlesData(
                      topTitles:
                          const AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles:
                              false,
                        ),
                      ),

                      rightTitles:
                          const AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles:
                              false,
                        ),
                      ),

                      /// Y AXIS
                      leftTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles:
                              true,

                          reservedSize:
                              42,

                          interval:
                              _calculateInterval(
                            chartMin,
                            chartMax,
                          ),

                          getTitlesWidget:
                              (value, meta) {
                            return Text(
                              _formatAmount(
                                value,
                              ),
                              style:
                                  const TextStyle(
                                fontSize:
                                    9,
                                color:
                                    AppColors
                                        .inkMuted,
                              ),
                            );
                          },
                        ),
                      ),

                      /// X AXIS
                      bottomTitles:
                          AxisTitles(
                        sideTitles:
                            SideTitles(
                          showTitles:
                              true,

                          reservedSize:
                              32,

                          interval: 1,

                          getTitlesWidget:
                              (value, meta) {
                            final index =
                                value.round();

                            if (index <
                                    0 ||
                                index >=
                                    dailyData
                                        .length) {
                              return const SizedBox
                                  .shrink();
                            }

                            final date =
                                dailyData[
                                        index]
                                    .date;

                            final isToday =
                                _isToday(
                              date,
                            );

                            return Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 8,
                              ),

                              child: Text(
                                _formatDate(
                                  date,
                                ),
                                style:
                                    TextStyle(
                                  fontSize:
                                      9,
                                  fontWeight:
                                      isToday
                                          ? FontWeight
                                              .w800
                                          : FontWeight
                                              .w500,
                                  color: isToday
                                      ? AppColors
                                          .indigo
                                      : AppColors
                                          .inkMuted,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    /// -----------------------------------------------------
                    /// TOUCH INTERACTION
                    /// -----------------------------------------------------

                    lineTouchData:
                        LineTouchData(
                      enabled: true,

                      touchSpotThreshold:
                          20,

                      handleBuiltInTouches:
                          true,

                      touchTooltipData:
                          LineTouchTooltipData(
                        getTooltipItems:
                            (touchedSpots) {
                          return touchedSpots
                              .map(
                            (spot) {
                              String label;

                              if (spot.barIndex ==
                                  0) {
                                label =
                                    'Income';
                              } else if (spot
                                      .barIndex ==
                                  1) {
                                label =
                                    'Expenses';
                              } else {
                                label =
                                    'Balance';
                              }

                              final index =
                                  spot.x.round();

                              String dateText =
                                  '';

                              if (index >=
                                      0 &&
                                  index <
                                      dailyData
                                          .length) {
                                dateText =
                                    _formatLongDate(
                                  dailyData[
                                          index]
                                      .date,
                                );
                              }

                              return LineTooltipItem(
                                '$label\n'
                                '$dateText\n'
                                '${spot.y.toInt()} XAF',

                                const TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              );
                            },
                          ).toList();
                        },
                      ),
                    ),

                    /// -----------------------------------------------------
                    /// GRAPH LINES
                    /// -----------------------------------------------------

                    lineBarsData: [
                      /// INCOME
                      LineChartBarData(
                        spots:
                            incomeSpots,

                        isCurved: true,

                        curveSmoothness:
                            0.25,

                        color:
                            AppColors.green,

                        barWidth: 3,

                        isStrokeCapRound:
                            true,

                        dotData:
                            FlDotData(
                          show:
                              dailyData
                                      .length <=
                                  31,
                        ),

                        belowBarData:
                            BarAreaData(
                          show: true,

                          color: AppColors
                              .green
                              .withOpacity(
                            0.08,
                          ),
                        ),
                      ),

                      /// EXPENSES
                      LineChartBarData(
                        spots:
                            expenseSpots,

                        isCurved: true,

                        curveSmoothness:
                            0.25,

                        color:
                            AppColors.clay,

                        barWidth: 3,

                        isStrokeCapRound:
                            true,

                        dotData:
                            FlDotData(
                          show:
                              dailyData
                                      .length <=
                                  31,
                        ),

                        belowBarData:
                            BarAreaData(
                          show: true,

                          color: AppColors
                              .clay
                              .withOpacity(
                            0.07,
                          ),
                        ),
                      ),

                      /// RUNNING BALANCE
                      LineChartBarData(
                        spots:
                            balanceSpots,

                        isCurved: true,

                        curveSmoothness:
                            0.25,

                        color:
                            AppColors.indigo,

                        barWidth: 3.5,

                        isStrokeCapRound:
                            true,

                        dotData:
                            FlDotData(
                          show:
                              dailyData
                                      .length <=
                                  31,
                        ),

                        belowBarData:
                            BarAreaData(
                          show: true,

                          color: AppColors
                              .indigo
                              .withOpacity(
                            0.04,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          /// ---------------------------------------------------------------
          /// SWIPE HINT
          /// ---------------------------------------------------------------

          Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color:
                    AppColors.inkMuted,
              ),

              SizedBox(width: 3),

              Text(
                'Swipe to explore your history',
                style: TextStyle(
                  fontSize: 10,
                  color:
                      AppColors.inkMuted,
                ),
              ),

              SizedBox(width: 3),

              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color:
                    AppColors.inkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }


  /// =========================================================================
  /// BUILD DAILY FINANCE DATA
  /// =========================================================================

  List<_DailyFinanceData>
      _buildDailyFinanceData(
    List<FinanceEntry> entries,
  ) {
    final validEntries =
        entries
            .where(
              (entry) =>
                  entry.date != null,
            )
            .toList();

    /*
     * If there are no dated entries,
     * there is nothing to plot.
     */
    if (validEntries.isEmpty) {
      return [];
    }

    /*
     * Sort transactions from oldest
     * to newest.
     */
    validEntries.sort(
      (a, b) => a.date!.compareTo(
        b.date!,
      ),
    );

    final now = DateTime.now();

    /*
     * Today's date without hours/minutes.
     */
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    /*
     * Show the latest 30 days.
     *
     * This keeps the graph usable on
     * a mobile phone.
     */
    final thirtyDaysAgo =
        today.subtract(
      const Duration(days: 29),
    );

    DateTime firstDate = DateTime(
      validEntries.first.date!.year,
      validEntries.first.date!.month,
      validEntries.first.date!.day,
    );

    /*
     * If the oldest transaction is more
     * than 30 days old, start from the
     * last 30 days.
     */
    if (firstDate.isBefore(
      thirtyDaysAgo,
    )) {
      firstDate = thirtyDaysAgo;
    }

    final Map<String, _DailyFinanceData>
        grouped = {};

    /*
     * IMPORTANT:
     *
     * Create an entry for EVERY DAY,
     * even if there was no transaction.
     *
     * Example:
     *
     * Aug 22
     * Aug 23
     * Aug 24
     * Aug 25
     * Aug 26
     * Aug 27
     *
     * This means TODAY always exists.
     */
    DateTime current = firstDate;

    while (!current.isAfter(today)) {
      final key =
          _dateKey(current);

      grouped[key] =
          _DailyFinanceData(
        date: current,
      );

      current = current.add(
        const Duration(days: 1),
      );
    }

    /*
     * Put every transaction into
     * the correct calendar day.
     */
    for (final entry in validEntries) {
      final entryDate =
          entry.date!;

      final day = DateTime(
        entryDate.year,
        entryDate.month,
        entryDate.day,
      );

      /*
       * Ignore transactions outside
       * the displayed period.
       */
      if (day.isBefore(firstDate) ||
          day.isAfter(today)) {
        continue;
      }

      final key =
          _dateKey(day);

      if (!grouped.containsKey(key)) {
        continue;
      }

      if (entry.type == 'income') {
        grouped[key]!.income +=
            entry.amount;
      } else {
        grouped[key]!.expense +=
            entry.amount;
      }
    }

    final result =
        grouped.values.toList();

    result.sort(
      (a, b) => a.date.compareTo(
        b.date,
      ),
    );

    /*
     * Calculate running balance.
     *
     * Example:
     *
     * Aug 22:
     * +5000 income
     * -1000 expense
     * = 4000 balance
     *
     * Aug 23:
     * +2000 income
     * -500 expense
     * = 5500 balance
     */
    int runningBalance = 0;

    for (final day in result) {
      runningBalance +=
          day.income - day.expense;

      day.balance =
          runningBalance;
    }

    return result;
  }


  /// =========================================================================
  /// DATE KEY
  /// =========================================================================

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }


  /// =========================================================================
  /// CHECK TODAY
  /// =========================================================================

  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }


  /// =========================================================================
  /// SHORT DATE
  /// =========================================================================

  String _formatDate(
    DateTime date,
  ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}';
  }


  /// =========================================================================
  /// LONG DATE
  /// =========================================================================

  String _formatLongDate(
    DateTime date,
  ) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }


  /// =========================================================================
  /// Y AXIS INTERVAL
  /// =========================================================================

  double _calculateInterval(
    double min,
    double max,
  ) {
    final range = max - min;

    if (range <= 1000) {
      return 250;
    }

    if (range <= 10000) {
      return 2500;
    }

    if (range <= 100000) {
      return 25000;
    }

    if (range <= 1000000) {
      return 250000;
    }

    return range / 4;
  }


  /// =========================================================================
  /// FORMAT AMOUNT
  /// =========================================================================

  String _formatAmount(
    double value,
  ) {
    final absolute =
        value.abs();

    if (absolute >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }

    if (absolute >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }

    return value.toInt().toString();
  }
}


/// ==========================================================================
/// CHART LEGEND
/// ==========================================================================

class _ChartLegend
    extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegend({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration:
              BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style:
              const TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


/// ==========================================================================
/// SECTION HEADER
/// ==========================================================================

class _SectionHeader
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// ==========================================================================
/// TRANSACTION CARD
/// ==========================================================================

class _TransactionCard
    extends StatelessWidget {
  final FinanceEntry entry;

  const _TransactionCard({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome =
        entry.type == 'income';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),

      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .cardColor,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withOpacity(
                0.45,
              ),
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 14,
          vertical: 13,
        ),

        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,

              decoration:
                  BoxDecoration(
                color: (isIncome
                        ? AppColors
                            .green
                        : AppColors
                            .clay)
                    .withOpacity(
                  0.10,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  15,
                ),
              ),

              child: Icon(
                isIncome
                    ? Icons
                        .south_west_rounded
                    : Icons
                        .north_east_rounded,

                color: isIncome
                    ? AppColors.green
                    : AppColors.clay,

                size: 21,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    entry.category
                            .isNotEmpty
                        ? entry.category
                        : entry.type,

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    entry.date
                            ?.toString()
                            .split('.')
                            .first ??
                        'No date',

                    style:
                        const TextStyle(
                      color:
                          AppColors
                              .inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            Text(
              '${isIncome ? '+' : '-'}'
              '${entry.amount} XAF',

              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w800,
                fontSize: 13,
                color: isIncome
                    ? AppColors.green
                    : AppColors.clay,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// ==========================================================================
/// EMPTY FINANCE STATE
/// ==========================================================================

class _EmptyFinanceState
    extends StatelessWidget {
  const _EmptyFinanceState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 10,
      ),

      padding:
          const EdgeInsets.all(
        30,
      ),

      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .cardColor,

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        border: Border.all(
          color: Theme.of(context)
              .dividerColor
              .withOpacity(
                0.5,
              ),
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,

            decoration:
                BoxDecoration(
              color: AppColors
                  .indigo
                  .withOpacity(
                0.10,
              ),
              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons
                  .bar_chart_rounded,
              size: 34,
              color:
                  AppColors.indigo,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Text(
            'No transactions yet',
            style:
                TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 17,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Start adding your income and expenses to see your financial activity here.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  AppColors.inkMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}