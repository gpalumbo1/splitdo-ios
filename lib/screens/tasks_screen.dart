// lib/screens/tasks_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';
import '../models/task.dart';

class TasksScreen extends StatefulWidget {
  final String groupId;
  const TasksScreen({required this.groupId, Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen>
    with AutomaticKeepAliveClientMixin<TasksScreen> {
  final _fs = FirestoreService();
  final _titleCtrl = TextEditingController();
  List<String> _italianWords = [];

  List<String> _currentOrderIds = [];
  bool _orderFrozen = false;
  bool _hasCalculatedOnceInSession = false;

  void onCalculatedOnce() {
    setState(() => _hasCalculatedOnceInSession = true);
  }

  @override
  void initState() {
    super.initState();
    _loadItalianVocabulary();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadItalianVocabulary() async {
    final raw = await rootBundle.loadString('assets/italian_words.txt');
    final lines = raw
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    lines.sort();
    setState(() => _italianWords = lines);
  }

  int _lowerBound(List<String> list, String prefix) {
    int low = 0, high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (list[mid].compareTo(prefix) < 0)
        low = mid + 1;
      else
        high = mid;
    }
    return low;
  }

  int _upperBound(List<String> list, String prefix) {
    final hi = prefix + '\uffff';
    int low = 0, high = list.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (list[mid].compareTo(hi) <= 0)
        low = mid + 1;
      else
        high = mid;
    }
    return low;
  }

  Future<void> _incrementLocalCount(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('localFrequentTasks') ?? '{}';
    final raw = json.decode(rawJson) as Map<String, dynamic>;
    final key = title.trim();
    raw[key] = ((raw[key] as int?) ?? 0) + 1;
    await prefs.setString('localFrequentTasks', json.encode(raw));
  }

  Future<void> _promptRecalculateIfNeeded() async {
    debugPrint("🏷️k [TasksScreen] _promptRecalculateIfNeeded, flag=$_hasCalculatedOnceInSession");
    if (!_hasCalculatedOnceInSession) return;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Modifiche Effettuate',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aggiorna le quote per allineare i dati.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTask() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final task = Task(
      id: '',
      title: title,
      assignedTo: '',
      status: 'pending',
      amountSpent: 0.0,
    );
    await _fs.addTask(widget.groupId, task);

    await _incrementLocalCount(title);
    await _promptRecalculateIfNeeded();

    FocusScope.of(context).unfocus();
    _titleCtrl.clear();
  }

  Future<void> _deleteTask(Task t) async {
    await _fs.deleteTask(widget.groupId, t.id);
    await _promptRecalculateIfNeeded();
  }

  Future<void> _takeCharge(Task t) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _fs.updateTask(widget.groupId, t.id, {'assignedTo': uid});
  }

  Future<void> _releaseTask(Task t) async {
    await _fs.updateTask(widget.groupId, t.id, {'assignedTo': ''});
  }

  Future<void> _editAmount(Task t) async {
    final ctrl = TextEditingController();
    bool valid = false;
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: theme.cardColor,
        title: Text('Inserisci importo', style: theme.textTheme.titleMedium),
        content: TextField(
          controller: ctrl,
          cursorColor: theme.primaryColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.primaryColor.withOpacity(0.05),
            prefixText: '€ ',
            hintText: '0,00',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\.,]'))
          ],
          onChanged: (text) {
            final raw = text.replaceAll(',', '.');
            valid = double.tryParse(raw) != null && double.parse(raw) >= 0;
            (ctx as Element).markNeedsBuild();
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annulla', style: theme.textTheme.bodyMedium)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor),
            onPressed: valid
                ? () async {
                    final raw = ctrl.text.replaceAll(',', '.');
                    final v = double.tryParse(raw) ?? 0.0;
                    Navigator.pop(ctx);
                    await _fs.updateTask(
                        widget.groupId, t.id, {'amountSpent': v});
                    await _promptRecalculateIfNeeded();
                  }
                : null,
            child: Text('Salva',
                style:
                    theme.textTheme.bodyMedium!.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDone(Task t, bool? done) async {
    await _fs.updateTask(
        widget.groupId, t.id, {'status': done! ? 'done' : 'pending'});
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.grey).withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color ?? Colors.grey.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color ?? Colors.black87),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: color ?? Colors.black87)),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>> _fetchNicknames(Iterable<String> uids) async {
    final m = <String, String>{};
    for (var u in uids) {
      try {
        m[u] = await _fs.getUserNickname(u);
      } catch (_) {
        m[u] = u;
      }
    }
    return m;
  }

  Future<void> _refreshTasks() async {
    setState(() {
      _orderFrozen = false;
    });
  }

  /// Trova la posizione alfabetica tra una lista di id dati, restituisce l’indice dove inserire il nuovo task.
  int _findInsertIndex(Task newTask, List<Task> list) {
    for (int i = 0; i < list.length; i++) {
      if (newTask.title.toLowerCase().compareTo(list[i].title.toLowerCase()) < 0) {
        return i;
      }
    }
    return list.length;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return StreamBuilder<List<Task>>(
      stream: _fs.tasksStream(widget.groupId),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snap.data!;

        // Categorie ordinate alfabeticamente
        final free = tasks.where((t) => t.assignedTo.isEmpty).toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        final minePending = tasks
            .where((t) => t.assignedTo == currentUid && t.status != 'done')
            .toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        final mineDone = tasks
            .where((t) => t.assignedTo == currentUid && t.status == 'done')
            .toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        final others = tasks
            .where((t) => t.assignedTo.isNotEmpty && t.assignedTo != currentUid)
            .toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

        final orderedTasks = [...free, ...minePending, ...mineDone, ...others];

        // Allineamento su refresh: salva solo la sequenza degli ID ordinati
        if (!_orderFrozen || _currentOrderIds.isEmpty) {
          _currentOrderIds = orderedTasks.map((t) => t.id).toList();
          _orderFrozen = true;
        }

        // Prende le task già mostrate (id -> oggetto)
        final taskMap = {for (var t in tasks) t.id: t};

        // Per ogni nuova task non ancora presente, inseriscila nella posizione giusta nella sua categoria
        for (final t in orderedTasks) {
          if (!_currentOrderIds.contains(t.id)) {
              _currentOrderIds.insert(0, t.id);
          }
        }

        // --- FINE AGGIORNAMENTO ---

        // Usa sempre l’ordine memorizzato, ma prendi i dati aggiornati
        final _sortedTasks = _currentOrderIds
            .map((id) => taskMap[id])
            .where((t) => t != null)
            .cast<Task>()
            .toList();

        final uids = _sortedTasks.where((t) => t.assignedTo.isNotEmpty).map((t) => t.assignedTo).toSet();

        return FutureBuilder<Map<String, String>>(
          future: _fetchNicknames(uids),
          builder: (context, nickSnap) {
            if (!nickSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final nickMap = nickSnap.data!;

            return RefreshIndicator(
              onRefresh: _refreshTasks,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: theme.primaryColor,
                    expandedHeight: 100,
                    automaticallyImplyLeading: false,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      titlePadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: Autocomplete<String>(
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                  final prefix =
                                      textEditingValue.text.toLowerCase();
                                  if (prefix.isEmpty ||
                                      _italianWords.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  final low =
                                      _lowerBound(_italianWords, prefix);
                                  final high =
                                      _upperBound(_italianWords, prefix);
                                  final end =
                                      (high - low > 4) ? low + 4 : high;
                                  return _italianWords.sublist(low, end);
                                },
                                fieldViewBuilder: (context, controller,
                                    focusNode, onFieldSubmitted) {
                                  controller.text = _titleCtrl.text;
                                  controller.selection =
                                      _titleCtrl.selection;
                                  controller.addListener(() {
                                    _titleCtrl.text = controller.text;
                                    _titleCtrl.selection =
                                        controller.selection;
                                  });
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    cursorColor: Colors.white,
                                    textAlignVertical:
                                        TextAlignVertical.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    enableInteractiveSelection: false,
                                    toolbarOptions: const ToolbarOptions(
                                      copy: false,
                                      cut: false,
                                      paste: false,
                                      selectAll: false,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'es. bevande, posate…',
                                      hintStyle: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                      fillColor: Colors.white24,
                                      filled: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4.0,
                                      borderRadius: BorderRadius.circular(8),
                                      child: ListView(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        children: options.map((opt) {
                                          return ListTile(
                                            title: Text(
                                              opt,
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                            onTap: () => onSelected(opt),
                                            dense: true,
                                            visualDensity: VisualDensity.compact,
                                            minVerticalPadding: 0,
                                            minLeadingWidth: 0,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  );
                                },
                                onSelected: (String selection) {
                                  _titleCtrl.value = TextEditingValue(
                                    text: selection,
                                    selection: TextSelection.collapsed(
                                        offset: selection.length),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _addTask,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle),
                              child: Icon(Icons.add,
                                  size: 20,
                                  color: theme.primaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  if (_sortedTasks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('Nessun item nella lista',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(
                              'Aggiungi un Item premi il +\n'
                              '(es. bevande, posate…).\n'
                              'Elimina con swipe.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final t = _sortedTasks[i];
                          final taken = t.assignedTo.isNotEmpty;
                          final assignedToMe = t.assignedTo == currentUid;
                          final done = t.status == 'done';
                          final tileColor = taken ? Colors.grey.shade200 : Colors.white;
                          final doneColor = Colors.red;

                          final canDelete =
                              t.assignedTo.isEmpty || assignedToMe;
                          final canRelease = assignedToMe && !done;

                          final nickname = taken
                            ? (nickMap.containsKey(t.assignedTo)
                                ? nickMap[t.assignedTo]!
                                : '..')
                            : "";

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Slidable(
                              key: ValueKey(t.id),
                              startActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: canDelete
                                    ? [
                                        SlidableAction(
                                          onPressed: (_) =>
                                              _deleteTask(t),
                                          backgroundColor:
                                              Colors.red.shade400,
                                          foregroundColor:
                                              Colors.white,
                                          icon: Icons.delete,
                                          label: 'Elimina',
                                        ),
                                      ]
                                    : [],
                              ),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: canDelete
                                    ? [
                                        SlidableAction(
                                          onPressed: (_) =>
                                              _deleteTask(t),
                                          backgroundColor:
                                              Colors.red.shade400,
                                          foregroundColor:
                                              Colors.white,
                                          icon: Icons.delete,
                                          label: 'Elimina',
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Card(
                                color: tileColor,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  onLongPress: canDelete
                                      ? () async {
                                          FocusScope.of(context).unfocus(); // <--- AGGIUNTA QUI
                                          // Dialog elimina
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Elimina Task?'),
                                              content: Text('Sei sicuro di voler eliminare "${t.title}"?'),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Annulla'),
                                                  onPressed: () => Navigator.pop(context, false),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Elimina', style: TextStyle(color: Colors.white)),
                                                  onPressed: () => Navigator.pop(context, true),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            await _deleteTask(t);
                                          }
                                        }
                                      : null,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                         horizontal: 16, vertical: 8),
                                  title: Text(
                                    t.title,
                                    style: theme.textTheme
                                        .titleMedium!
                                        .copyWith(
                                      color: done
                                          ? Colors.grey
                                          : null,
                                      decoration: done
                                          ? TextDecoration
                                              .lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Importo: €${t.amountSpent.toStringAsFixed(2).replaceAll('.', ',')}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      taken
                                        ? Text('In carico a: $nickname')
                                        : const Text('Non assegnato'),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (assignedToMe && !done)
                                            _actionIcon(
                                              icon: Icons.euro_symbol,
                                              label: 'Costo',
                                              onTap: () => _editAmount(t),
                                              color: Colors.blue,
                                            ),
                                          if (!taken)
                                            _actionIcon(
                                              icon: Icons.lock,
                                              label: 'Prendi in carico',
                                              onTap: () => _takeCharge(t),
                                              color: Colors.green,
                                            ),
                                          if (canRelease)
                                            _actionIcon(
                                              icon: Icons.lock_open,
                                              label: 'Rilascia',
                                              onTap: () => _releaseTask(t),
                                              color: Colors.orange,
                                            ),
                                          if (assignedToMe)
                                            _actionIcon(
                                              icon: done
                                                  ? Icons.check_box
                                                  : Icons.check_box_outline_blank,
                                              label: 'Fatto',
                                              onTap: () => _toggleDone(t, !done),
                                              color: doneColor,
                                            ),
                                        ],
                                      ),
                                      if (taken && !assignedToMe) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          done
                                              ? 'Completato'
                                              : 'In corso',
                                          style: theme.textTheme.bodyMedium!.copyWith(
                                            color: done
                                                ? Colors.green
                                                : Colors.orange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _sortedTasks.length,
                      ),
                    ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 24)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
