import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/task.dart';

class BalancesScreen extends StatefulWidget {
  final String groupId;
  final Future<void> Function()? onCalculated;

  const BalancesScreen({required this.groupId, this.onCalculated, Key? key})
      : super(key: key);

  @override
  State<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends State<BalancesScreen>
    with AutomaticKeepAliveClientMixin<BalancesScreen> {
  static bool _didInitialReset = false;
  final _fs = FirestoreService();

  Map<String, double> _weights = {};
  bool _hasCalculated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_didInitialReset) {
      _fs
          .groupDoc(widget.groupId)
          .update({'calculatedBalances': FieldValue.delete()}).catchError((_) {});
      _didInitialReset = true;
    }
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    final snap = await _fs.groupDoc(widget.groupId).get();
    final raw = (snap.data()?['weights'] as Map<String, dynamic>?) ?? {};
    setState(() {
      _weights = {
        for (var e in raw.entries) e.key: (e.value as num).toDouble(),
      };
    });
  }

  Future<Map<String, String>> _fetchNicknames(List<String> members) async {
    final m = <String, String>{};
    for (var u in members) {
      try {
        m[u] = await _fs.getUserNickname(u);
      } catch (_) {
        m[u] = u;
      }
    }
    return m;
  }

  Future<void> _calculate(List<String> members, List<Task> tasks) async {
    final spent = {for (var u in members) u: 0.0};
    for (var t in tasks) {
      final assigned = t.assignedTo;
      if (assigned.isNotEmpty && t.amountSpent > 0) {
        if (!spent.containsKey(assigned)) continue;
        spent[assigned] = spent[assigned]! + t.amountSpent;
      }
    }
    final total = spent.values.fold(0.0, (a, b) => a + b);
    final tw =
        members.map((u) => _weights[u] ?? 1.0).fold(0.0, (a, b) => a + b);
    final perUnit = tw > 0 ? total / tw : 0.0;
    final newBal = <String, double>{};
    for (var u in members) {
      final weight = _weights[u] ?? 1.0;
      final userSpent = spent[u] ?? 0.0;
      newBal[u] = perUnit * weight - userSpent;
    }
    await _fs.groupDoc(widget.groupId).set({
      'calculatedBalances': {for (var e in newBal.entries) e.key: e.value}
    }, SetOptions(merge: true));

    setState(() => _hasCalculated = true);

    if (widget.onCalculated != null) await widget.onCalculated!();
  }

  void _showTasksIncompleteAlert() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Task incompleti'),
        content: const Text(
          'Non è ancora possibile calcolare le quote. Tutti i task devono essere completati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRecalcPrompt() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifiche Effettuate',
            style: Theme.of(context).textTheme.titleMedium),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Aggiorna le quote per allineare i dati.',
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(String key) {
    final palette = Colors.primaries;
    final idx = key.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    const collapsedHeight = 120.0;
    const extrasHeight = 40.0;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _fs.groupDocStream(widget.groupId),
        builder: (_, gSnap) {
          if (!gSnap.hasData || gSnap.data!.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = gSnap.data!.data()!;
          final members = List<String>.from(data['members'] ?? []);
          final rawWeights = (data['weights'] as Map<String, dynamic>?) ?? {};
          _weights = {
            for (var e in rawWeights.entries) e.key: (e.value as num).toDouble(),
          };
          final settledMap =
              (data['settledBalances'] as Map<String, dynamic>?) ?? {};
          final rawCalc = data['calculatedBalances'] as Map<String, dynamic>?;
          final calculated = rawCalc != null;
          final balances = calculated
              ? rawCalc.map((k, v) => MapEntry(k, (v as num).toDouble()))
              : <String, double>{};

          return FutureBuilder<Map<String, String>>(
            future: _fetchNicknames(members),
            builder: (_, nSnap) {
              if (!nSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final nick = nSnap.data!;

              return StreamBuilder<List<Task>>(
                stream: _fs.tasksStream(widget.groupId),
                builder: (_, tSnap) {
                  if (!tSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final tasks = tSnap.data!;

                  final allTasksDone =
                      tasks.isNotEmpty && tasks.every((t) => t.status == 'done');

                  final totalSpent =
                      tasks.fold<double>(0, (s, t) => s + t.amountSpent);

                  final tw = members
                      .map((u) => _weights[u] ?? 1.0)
                      .fold(0.0, (a, b) => a + b);
                  final perUnit = tw > 0 ? totalSpent / tw : 0.0;

                  final myBalance = balances[currentUid] ?? 0.0;
                  final myAbs = myBalance.abs();
                  final myShouldReceive = myBalance < 0;

                  // --- Ordinamento alfabetico per nickname di unsettled e settled ---
                  final compareByNickname = (String a, String b) =>
                      (nick[a] ?? a).toLowerCase().compareTo((nick[b] ?? b).toLowerCase());

                  final unsettled = members
                      .where((u) =>
                          u != currentUid && !(settledMap[u] as bool? ?? false))
                      .toList()
                    ..sort(compareByNickname);

                  final settled = members
                      .where((u) =>
                          u != currentUid && (settledMap[u] as bool? ?? false))
                      .toList()
                    ..sort(compareByNickname);

                  final ordered = [currentUid, ...unsettled, ...settled];

                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: calculated
                            ? (collapsedHeight + extrasHeight)
                            : collapsedHeight,
                        collapsedHeight: collapsedHeight,
                        automaticallyImplyLeading: false,
                        backgroundColor: theme.primaryColor,
                        flexibleSpace: LayoutBuilder(
                          builder: (context, constraints) {
                            final showExtras = calculated &&
                                constraints.maxHeight >=
                                    (collapsedHeight + extrasHeight - 10);

                            double fontTitle = 18;
                            double fontAmount = 28;
                            if (constraints.maxHeight < 100) {
                              fontTitle = 15;
                              fontAmount = 20;
                            }

                            final labelStyle = theme.textTheme.titleMedium!
                                .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: fontTitle,
                                    overflow: TextOverflow.ellipsis);
                            final amountStyle = theme.textTheme.titleSmall!
                                .copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: fontAmount,
                                    overflow: TextOverflow.ellipsis);

                            return FlexibleSpaceBar(
                              collapseMode: CollapseMode.pin,
                              titlePadding: const EdgeInsets.only(
                                  left: 16, bottom: 8, right: 16),
                              title: SizedBox(
                                width: double.infinity,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Totale Speso:',
                                          style: labelStyle, maxLines: 1),
                                    ),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                          '€${totalSpent.toStringAsFixed(2)}',
                                          style: amountStyle,
                                          maxLines: 1),
                                    ),
                                    if (showExtras) ...[
                                      const SizedBox(height: 4),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '(1×) Quota Intera: €${perUnit.toStringAsFixed(2)}',
                                          style: theme.textTheme.labelSmall!
                                              .copyWith(color: Colors.white),
                                          maxLines: 1,
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '(½×) Mezza Quota: €${(perUnit * 0.5).toStringAsFixed(2)}',
                                          style: theme.textTheme.labelSmall!
                                              .copyWith(color: Colors.white),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              background: Container(color: theme.primaryColor),
                            );
                          },
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calculate),
                              label: Text(
                                  calculated ? 'Aggiorna quote' : 'Calcola quote'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: allTasksDone
                                    ? Colors.white
                                    : Colors.grey.shade300,
                                foregroundColor: theme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () {
                                if (!allTasksDone) {
                                  _showTasksIncompleteAlert();
                                } else {
                                  _calculate(members, tasks);
                                }
                              },
                            ),
                          ),
                        ),
                      ),

                      if (calculated)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    myShouldReceive
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: myShouldReceive
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    myShouldReceive
                                        ? 'Tu devi ricevere €${myAbs.toStringAsFixed(2)}'
                                        : 'Tu devi dare €${myAbs.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyLarge!.copyWith(
                                        color: myShouldReceive
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance),
                              const SizedBox(width: 8),
                              Text('Bilanci',
                                  style: theme.textTheme.titleMedium!
                                      .copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),

                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) {
                            final u = ordered[index];
                            final spentBy = tasks
                                .where((t) => t.assignedTo == u)
                                .fold<double>(0, (s, t) => s + t.amountSpent);
                            final quota = _weights[u] ?? 1.0;
                            final b = balances[u] ?? 0.0;
                            final absB = b.abs();
                            final shouldReceive = b < 0;
                            final settled = settledMap[u] as bool? ?? false;
                            final cardColor =
                                settled ? Colors.grey.shade200 : Colors.white;
                            final avatarCol = _avatarColor(u);

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: Card(
                                color: cardColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: avatarCol.withOpacity(0.2),
                                    child: Text(
                                      (nick[u] ?? u)[0].toUpperCase(),
                                      style: TextStyle(
                                          color: avatarCol,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    nick[u] ?? u,
                                    style: theme.textTheme.titleMedium!.copyWith(
                                      decoration: settled
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ha speso: €${spentBy.toStringAsFixed(2)}   Quota: ${quota == 1.0 ? '1×' : '½×'}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        shouldReceive
                                            ? 'Deve ricevere €${absB.toStringAsFixed(2)}'
                                            : 'Deve dare €${absB.toStringAsFixed(2)}',
                                        style: theme.textTheme.bodyMedium!.copyWith(
                                            color: shouldReceive
                                                ? Colors.green
                                                : Colors.red),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!settled)
                                        DropdownButton<double>(
                                          value: (quota == 1.0 || quota == 0.5)
                                              ? quota
                                              : 1.0,
                                          items: const [
                                            DropdownMenuItem(
                                                value: 1.0, child: Text('1×')),
                                            DropdownMenuItem(
                                                value: 0.5, child: Text('½×')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) {
                                              _fs.groupDoc(widget.groupId).set(
                                                  {'weights': {u: v}},
                                                  SetOptions(merge: true));
                                              setState(() => _weights[u] = v);
                                              if (_hasCalculated) {
                                                _showRecalcPrompt();
                                              }
                                            }
                                          },
                                        ),
                                      Checkbox(
                                        value: settled,
                                        onChanged: (v) {
                                          _fs.updateSettledBalance(
                                              widget.groupId, u, v!);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: ordered.length,
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


