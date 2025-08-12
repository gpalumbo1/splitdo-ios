import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';
import '../models/group.dart';
import '../models/task.dart';
import '../models/user.dart';
import 'tasks_screen.dart';
import 'balances_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final bool joinOnOpen;

  const GroupDetailScreen({
    required this.groupId,
    this.joinOnOpen = false,
    Key? key,
  }) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _fs = FirestoreService();
  int _selectedIndex = 0;
  Group? _group;
  String? _myNickname;
  Set<String> _currentTaskTitles = {};
  List<UserModel> _friends = [];
  Map<String, int> _localCounts = {};

  // SOLO RAM per la sessione/app!
  bool _hasCalculatedOnceInSession = false;
  final GlobalKey<TasksScreenState> _tasksKey = GlobalKey<TasksScreenState>();

  List<MapEntry<String, int>> get _frequentTasks {
    final entries = _localCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  void initState() {
    super.initState();

    if (widget.joinOnOpen) _fs.joinGroup(widget.groupId);

    _fs.groupStream(widget.groupId).listen((g) => setState(() => _group = g));

    _fs
        .getUserNickname(FirebaseAuth.instance.currentUser!.uid)
        .then((nick) => setState(() => _myNickname = nick));

    _loadFriends();
    _loadLocalFrequentTasks();

    _fs.tasksStream(widget.groupId).listen((tasks) {
      setState(() {
        _currentTaskTitles = tasks.map((t) => t.title.trim()).toSet();
      });
    });
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _fs.getFriends();
      setState(() => _friends = friends);
    } catch (_) {
      setState(() => _friends = []);
    }
  }

  Future<void> _loadLocalFrequentTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('localFrequentTasks') ?? '{}';
    final map = json.decode(raw) as Map<String, dynamic>;
    setState(() {
      _localCounts = map.map((k, v) => MapEntry(k, v as int));
    });
  }

  Future<void> _incrementLocalCount(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final t = title.trim();
    _localCounts[t] = (_localCounts[t] ?? 0) + 1;
    await prefs.setString('localFrequentTasks', json.encode(_localCounts));
    setState(() {});
  }

  Future<void> _addCommonTask(String title) async {
    final task = Task(
      id: '',
      title: title,
      assignedTo: '',
      status: 'pending',
      amountSpent: 0.0,
    );
    await _fs.addTask(widget.groupId, task);
    await _incrementLocalCount(title);
  }

  void _showCommonTasksSheet() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AnimatedPopupWrapper(
        child: StatefulBuilder(
          builder: (ctx, setModal) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt_rounded, color: Colors.grey.shade800),
                    const SizedBox(width: 6),
                    Text('Task più frequenti',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const Divider(),
                if (_frequentTasks.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Nessun task ricorrente da mostrare.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                              color: Colors.grey[500], fontSize: 16),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: _frequentTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (_, i) {
                        final entry = _frequentTasks[i];
                        final title = entry.key;
                        final already = _currentTaskTitles.contains(title);
                        return _AnimatedListTile(
                          leading: Icon(
                            already
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: Colors.grey.shade800,
                          ),
                          title: title,
                          enabled: !already,
                          onTap: already
                              ? null
                              : () async {
                                  await _addCommonTask(title);
                                  setModal(() =>
                                      _currentTaskTitles.add(title));
                                },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _promptRecalculateIfNeeded() async {
    if (!_hasCalculatedOnceInSession || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Modifiche Effettuate',
            style: Theme.of(context).textTheme.titleMedium),
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

  Future<void> _addUserByNickname(String nickname) async {
    final ok =
        await _fs.addUserToGroup(groupId: widget.groupId, nickname: nickname);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Utente aggiunto' : 'Username non trovato')),
    );
    if (ok) await _promptRecalculateIfNeeded();
  }

  Future<void> _addMemberByUid(String uid) async {
    await _fs.addMemberByUid(widget.groupId, uid);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Utente aggiunto')));
    await _promptRecalculateIfNeeded();
  }

  Future<void> _setHasCalculatedOnceLocal() async {
    setState(() => _hasCalculatedOnceInSession = true);
    _tasksKey.currentState?.onCalculatedOnce();
  }

  void _showMembersList() {
    if (_group == null) return;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => _AnimatedPopupWrapper(
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Partecipanti', style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: "Aggiungi utente",
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(context);
                          _showAddUserDialog();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(Icons.person_add_alt_1,
                              color: Colors.grey.shade800, size: 26),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: "Rimuovi utente",
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.pop(context);
                          _showRemoveMember();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(Icons.person_remove_alt_1,
                              color: Colors.grey.shade800, size: 26),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    itemCount: _group!.members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final uid = _group!.members[i];
                      return FutureBuilder<String>(
                        future: _fs.getUserNickname(uid),
                        builder: (c, s) {
                          final nickname = s.data ?? uid;
                          final isMe = uid == FirebaseAuth.instance.currentUser!.uid;
                          final alreadyFriend = _friends.any((f) => f.uid == uid);

                          return ListTile(
                            leading: Icon(Icons.person, color: Colors.grey.shade800),
                            title: Text(nickname),
                            trailing: (!isMe && !alreadyFriend)
                                ? Tooltip(
                                    message: "Aggiungi questa persona alla tua lista amici",
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFFFFC107),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        textStyle: const TextStyle(fontSize: 14),
                                      ),
                                      label: const Text("Aggiungi agli amici"),
                                      onPressed: () async {
                                        final ok = await _fs.addFriendByNickname(nickname: nickname);
                                        if (ok) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("$nickname aggiunto agli amici!")),
                                          );
                                          await _loadFriends();
                                          setModalState(() {}); // Aggiorna subito la lista!
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Impossibile aggiungere $nickname.")),
                                          );
                                        }
                                      },
                                    ),
                                  )
                                : (alreadyFriend && !isMe
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Tooltip(
                                            message: "Già amico",
                                            child: Icon(Icons.check_circle, color: Colors.green),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Amico",
                                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                          )
                                        ],
                                      )
                                    : null),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog() {
    final theme = Theme.of(context);
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctxOuter) => StatefulBuilder(
        builder: (ctx, setStateInner) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: theme.cardColor,
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1, color: Colors.grey.shade800),
              const SizedBox(width: 8),
              Text('Aggiungi utente all\'evento',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  cursorColor: theme.primaryColor,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.primaryColor.withOpacity(0.07),
                    hintText: 'Inserisci username',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text('Aggiungi dagli amici',
                    style: theme.textTheme.titleSmall!.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 8),
                _friends.isEmpty
                    ? Text('Non hai amici da selezionare.',
                        style: theme.textTheme.bodyMedium)
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _friends.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final f = _friends[i];
                            final already =
                                _group?.members.contains(f.uid) ?? false;
                            return _AnimatedListTile(
                              leading: Icon(
                                  already
                                      ? Icons.check_circle
                                      : Icons.person_add_alt,
                                  color: Colors.grey.shade800),
                              title: f.nickname,
                              enabled: !already,
                              onTap: already
                                  ? null
                                  : () async {
                                      Navigator.of(ctxOuter).pop();
                                      await _addMemberByUid(f.uid);
                                    },
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Annulla',
                  style: theme.textTheme.bodyMedium),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: loading
                  ? null
                  : () async {
                      final nick = ctrl.text.trim();
                      if (nick.isEmpty) return;
                      setStateInner(() => loading = true);
                      Navigator.of(ctx).pop();
                      await _addUserByNickname(nick);
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Aggiungi',
                      style: theme.textTheme.bodyMedium!
                          .copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // FUNZIONE AGGIORNATA: esclude il mio utente dalla lista rimovibili
  void _showRemoveMember() {
    if (_group == null) return;
    final theme = Theme.of(context);
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final removableMembers = _group!.members.where((uid) => uid != myUid).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AnimatedPopupWrapper(
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_remove, color: Colors.grey.shade800),
                  const SizedBox(width: 8),
                  Text('Rimuovi utente', style: theme.textTheme.titleMedium),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: removableMembers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final uid = removableMembers[i];
                    return FutureBuilder<String>(
                      future: _fs.getUserNickname(uid),
                      builder: (c, s) {
                        final name = s.data ?? uid;
                        return _AnimatedListTile(
                          leading: Icon(Icons.person_remove_alt_1,
                              color: Colors.grey.shade800),
                          title: name,
                          onTap: () async {
                            Navigator.pop(context);
                            await _fs.removeUserFromGroup(
                                groupId: widget.groupId, memberUid: uid);
                            await _promptRecalculateIfNeeded();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.grey.shade800),
            const SizedBox(width: 8),
            const Text('Abbandona evento'),
          ],
        ),
        content: const Text(
            'Sei sicuro di voler abbandonare questo evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((yes) async {
      if (yes == true) {
        final me = FirebaseAuth.instance.currentUser!.uid;
        await _fs.removeUserFromGroup(
            groupId: widget.groupId, memberUid: me);
        await _promptRecalculateIfNeeded();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Elimina evento'),
          ],
        ),
        content: const Text(
            'Sei sicuro di voler eliminare questo evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await _fs.deleteGroup(widget.groupId);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child:
                const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onTap(int idx) => setState(() => _selectedIndex = idx);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final tabs = [
      TasksScreen(key: _tasksKey, groupId: widget.groupId),
      BalancesScreen(
        groupId: widget.groupId,
        onCalculated: _setHasCalculatedOnceLocal,
      ),
    ];

    return Scaffold(
      drawerEnableOpenDragGesture: false,
      drawer: _buildDrawer(theme, primary),
      appBar: _buildAppBar(theme, primary),
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Lista'),
          BottomNavigationBarItem(icon: Icon(Icons.euro_symbol), label: 'Spese'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, Color primary) {
    return AppBar(
      backgroundColor: primary,
      centerTitle: true,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _group?.name ?? 'Caricamento…',
            style: theme.textTheme.titleLarge!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (_group != null)
            GestureDetector(
              onTap: _showMembersList,
              child: Text(
                '${_group!.members.length} partecipanti',
                style: theme.textTheme.bodySmall!
                    .copyWith(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_add, size: 28),
          tooltip: 'Aggiungi utente',
          onPressed: _showAddUserDialog,
        ),
        IconButton(
          icon: const Icon(Icons.share, size: 28),
          tooltip: 'Condividi link gruppo',
          onPressed: _group == null
              ? null
              : () {
                  final link =
                      'https://splitdo-app.web.app/join.html?groupId=${widget.groupId}';
                  Share.share(
                      'Partecipa all\'evento \"${_group!.name}\" su SplitDo\n$link');
                },
        ),
      ],
    );
  }

  Drawer _buildDrawer(ThemeData theme, Color primary) {
    return Drawer(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
            width: double.infinity,
            child: Column(
              children: [
                const Icon(Icons.event, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  _group?.name ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _group == null
                      ? ''
                      : '${_group!.members.length} partecipanti',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),
                _AnimatedDrawerTile(
                  icon: Icons.group,
                  label: 'Partecipanti',
                  onTap: () {
                    Navigator.pop(context);
                    _showMembersList();
                  },
                ),
                _AnimatedDrawerTile(
                  icon: Icons.person_add,
                  label: 'Aggiungi utente',
                  onTap: () {
                    Navigator.pop(context);
                    _showAddUserDialog();
                  },
                ),
                _AnimatedDrawerTile(
                  icon: Icons.person_remove,
                  label: 'Rimuovi utente',
                  color: Colors.grey.shade800,
                  onTap: () {
                    Navigator.pop(context);
                    _showRemoveMember();
                  },
                ),
                const Divider(),
                _AnimatedDrawerTile(
                  icon: Icons.task_alt,
                  label: 'Task più frequenti',
                  onTap: () {
                    Navigator.pop(context);
                    _showCommonTasksSheet();
                  },
                ),
                const Divider(),
                _AnimatedDrawerTile(
                  icon: Icons.exit_to_app,
                  label: 'Abbandona evento',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmLeaveGroup();
                  },
                ),
                _AnimatedDrawerTile(
                  icon: Icons.delete,
                  label: 'Elimina evento',
                  color: Colors.red.shade400,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteGroup();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------- COMPONENTI ANIMATI -------------------
class _AnimatedListTile extends StatefulWidget {
  final Icon leading;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;

  const _AnimatedListTile({
    required this.leading,
    required this.title,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<_AnimatedListTile> createState() => _AnimatedListTileState();
}

class _AnimatedListTileState extends State<_AnimatedListTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.enabled ? widget.onTap : null,
      onHover: (h) => setState(() => _hover = h),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: widget.enabled
              ? (_hover
                  ? theme.primaryColor.withOpacity(0.07)
                  : Colors.transparent)
              : Colors.grey.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            widget.leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.bodyLarge!.copyWith(
                  color: widget.enabled ? null : Colors.grey,
                  fontWeight:
                      widget.enabled ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDrawerTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _AnimatedDrawerTile({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedDrawerTile> createState() => _AnimatedDrawerTileState();
}

class _AnimatedDrawerTileState extends State<_AnimatedDrawerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? Theme.of(context).primaryColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        decoration: BoxDecoration(
          color:
              _hovered ? baseColor.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: ListTile(
          leading: Icon(widget.icon, color: widget.color ?? null),
          title: Text(
            widget.label,
            style: TextStyle(
              color: widget.color ?? null,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          onTap: widget.onTap,
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
        ),
      ),
    );
  }
}

class _AnimatedPopupWrapper extends StatelessWidget {
  final Widget child;
  const _AnimatedPopupWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      tween: Tween(begin: 0.95, end: 1),
      curve: Curves.easeOut,
      builder: (context, s, c) => Transform.scale(scale: s, child: c),
      child: child,
    );
  }
}

