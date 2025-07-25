// lib/screens/groups_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/firestore_service.dart';
import '../services/ad_service.dart';
import '../models/group.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _fs = FirestoreService();
  String? _myNickname;

  List<Group> _cachedGroups = [];
  bool _hasDataOnce = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _fs.getUserNickname(uid).then((nick) {
      if (mounted) setState(() => _myNickname = nick);
    });
  }

  Future<void> _deleteGroup(String groupId) async {
    await _fs.deleteGroup(groupId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evento eliminato')),
    );
    // Rimuovi focus per evitare apertura tastiera
    FocusScope.of(context).unfocus();
  }

  void _showCreateDialog(BuildContext context, FirestoreService fs, String uid) {
    final ctrl = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: theme.cardColor,
        title: Text('Nuovo evento', style: theme.textTheme.titleMedium),
        content: TextField(
          controller: ctrl,
          cursorColor: theme.primaryColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.primaryColor.withOpacity(0.05),
            hintText: 'Nome dell\'evento',
            hintStyle: theme.textTheme.bodyMedium,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await fs.createGroup(name, [uid]);
              Navigator.pop(context);
            },
            child: Text('Crea',
                style: theme.textTheme.bodyMedium!.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // helper per colore avatar
  Color _avatarColor(String key) {
    final palette = Colors.primaries;
    final idx = key.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: primary,
            toolbarHeight: kToolbarHeight,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Row(
              children: [
                const SizedBox(width: 16),
                Text(
                  'Eventi',
                  style: theme.textTheme.titleMedium!
                      .copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                ),
                Expanded(
                  child: Center(
                    // Nickname abbreviato se >10 char
                    child: Text(
                      _myNickname == null
                          ? ''
                          : (_myNickname!.length > 10
                              ? '${_myNickname!.substring(0, 10)}…'
                              : _myNickname!),
                      style: theme.textTheme.bodyMedium!
                          .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/friends'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 28),
                        const SizedBox(width: 6),
                        Text(
                          'Amici',
                          style: theme.textTheme.bodyMedium!
                              .copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(color: theme.dividerColor, height: 1),
            ),
          ),

          StreamBuilder<List<Group>>(
            stream: _fs.groupsStreamForUser(uid),
            builder: (ctx, snap) {
              if (snap.hasData) {
                _cachedGroups = snap.data!;
                _hasDataOnce = true;
              } else if (!snap.hasData && !_hasDataOnce) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Ordinamento alfabetico dei gruppi
              final groups = List<Group>.from(_cachedGroups)
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (groups.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Non ci sono eventi.\nTocca il + per crearne uno.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: Colors.grey, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx2, i) {
                    final g = groups[i];
                    final avatarCol = _avatarColor(g.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Slidable(
                        key: ValueKey(g.id),
                        startActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                await _deleteGroup(g.id);
                                // Rimuovi il focus dopo swipe
                                FocusScope.of(context).unfocus();
                              },
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Elimina',
                            ),
                          ],
                        ),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                await _deleteGroup(g.id);
                                // Rimuovi il focus dopo swipe
                                FocusScope.of(context).unfocus();
                              },
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              icon: Icons.delete,
                              label: 'Elimina',
                            ),
                          ],
                        ),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await AdService.instance.showAdIfAvailable();
                              if (!mounted) return;
                              Navigator.pushNamed(context, '/groupDetail', arguments: g.id);
                            },
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Elimina evento'),
                                  content: const Text('Sei sicuro di voler eliminare questo evento?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Annulla'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _deleteGroup(g.id);
                                        // Rimuovi il focus dopo elimina con long press
                                        FocusScope.of(context).unfocus();
                                      },
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Elimina'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: avatarCol.withOpacity(0.2),
                                child: Text(
                                  g.name.isNotEmpty
                                      ? g.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: avatarCol,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                              ),
                              title: Text(
                                g.name,
                                style: theme.textTheme.titleMedium!
                                    .copyWith(
                                        color: avatarCol,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18),
                              ),
                              subtitle: Text(
                                '${g.members.length} partecipante${g.members.length > 1 ? 'i' : ''}',
                                style: theme.textTheme.bodyMedium!
                                    .copyWith(fontSize: 15),
                              ),
                              trailing:
                                  Icon(Icons.arrow_forward_ios, color: avatarCol, size: 24),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: groups.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(child: const SizedBox(height: 24)),
        ],
      ),
      floatingActionButton: Tooltip(
        message: 'Crea nuovo evento',
        child: FloatingActionButton(
          onPressed: () => _showCreateDialog(context, _fs, uid),
          backgroundColor: Colors.amber,
          elevation: 6,
          child: const Icon(Icons.add, size: 32),
        ),
      ),
    );
  }
}

