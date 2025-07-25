// lib/screens/friends_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/firestore_service.dart';
import '../models/user.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _fs = FirestoreService();
  final _ctrl = TextEditingController();
  List<UserModel> _friends = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final friends = await _fs.getFriends();
    setState(() => _friends = friends);
  }

  Future<void> _addFriend() async {
    final nick = _ctrl.text.trim();
    if (nick.isEmpty) return;
    setState(() => _loading = true);
    final ok = await _fs.addFriendByNickname(nickname: nick);
    setState(() => _loading = false);
    if (ok) {
      _ctrl.clear();
      _loadFriends();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username non trovato')),
      );
    }
  }

  Future<void> _removeFriend(String uid) async {
    await _fs.removeFriendByUid(uid);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Amico rimosso')),
    );
    _loadFriends();
    // Rimuovi focus per evitare apertura tastiera
    FocusScope.of(context).unfocus();
  }

  // helper per colore avatar stabile ma "random"
  Color _avatarColor(String key) {
    final palette = Colors.primaries;
    final idx = key.hashCode.abs() % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Ordinamento alfabetico degli amici
    final sortedFriends = List<UserModel>.from(_friends)
      ..sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // AppBar con campo input
          SliverAppBar(
            pinned: true,
            backgroundColor: theme.primaryColor,
            expandedHeight: 100,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(color: theme.primaryColor),
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _ctrl,
                        cursorColor: Colors.white,
                        textAlignVertical: TextAlignVertical.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Username amico',
                          hintStyle: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          fillColor: Colors.white24,
                          filled: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _loading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : InkWell(
                          onTap: _addFriend,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Icon(Icons.person_add,
                                size: 20, color: theme.primaryColor),
                          ),
                        ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Divider(height: 1, color: theme.dividerColor),
          ),

          // Empty state
          if (sortedFriends.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Nessun amico aggiunto',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aggiungi un amico inserendo il suo username\n'
                        'e premendo +.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Lista amici con card in stile Balances/Tasks
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final f = sortedFriends[i];
                  final avatarCol = _avatarColor(f.uid);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Slidable(
                      key: ValueKey(f.uid),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              await _removeFriend(f.uid);
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
                              await _removeFriend(f.uid);
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
                        color: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          // LONG PRESS PER ELIMINAZIONE
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Rimuovi amico'),
                                content: Text('Vuoi davvero rimuovere ${f.nickname}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Annulla'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _removeFriend(f.uid);
                                      // Rimuovi focus dopo elimina con long press
                                      FocusScope.of(context).unfocus();
                                    },
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Rimuovi'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: avatarCol.withOpacity(0.2),
                              child: Text(f.nickname[0].toUpperCase(),
                                  style: TextStyle(
                                      color: avatarCol,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(f.nickname,
                                style: theme.textTheme.titleMedium),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: sortedFriends.length,
              ),
            ),

          SliverToBoxAdapter(child: const SizedBox(height: 24)),
        ],
      ),
    );
  }
}

