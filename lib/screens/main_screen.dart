import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../widgets/task_card.dart';
import '../widgets/reward_card.dart';
import '../widgets/chat_widget.dart';
import 'auth_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final _service = FirestoreService();
  final _auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot>? _childSubscription;

  List<Map<String, dynamic>> _childrenList = [];
  Map<String, dynamic>? _selectedChild;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _rewards = [];

  int _points = 0;
  int _streak = 0;
  String _childId = '';
  String _parentId = '';
  String _familyCode = '';
  String _displayName = '';
  String _avatar = '🌟';
  bool _isParent = false;

  late TabController _tabController;

  static const _defaultTasks = [
    {'name': '🗑️ Вынести мусор', 'points': 10},
    {'name': '🧹 Подмести пол', 'points': 15},
    {'name': '📚 Сделать уроки', 'points': 30},
    {'name': '🐕 Погулять с собакой', 'points': 20},
    {'name': '🛏️ Заправить кровать', 'points': 5},
    {'name': '🍽️ Помыть посуду', 'points': 15},
    {'name': '🧸 Убрать игрушки', 'points': 10},
    {'name': '🪴 Полить цветы', 'points': 5},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadUser();
  }

  @override
  void dispose() {
    _childSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data();
    if (data == null) return;
    final isParent = data['role'] == 'parent';
    if (mounted) {
      setState(() {
        _isParent = isParent;
        _displayName =
            data['displayName'] ?? (isParent ? 'Родитель' : 'Ребёнок');
        _avatar = data['avatar'] ?? (isParent ? '👨' : '🌟');
      });
    }
    if (isParent) {
      _childId = user.uid;
      _familyCode = await _service.getFamilyCode(user.uid);
      await _service.initFirstChild(user.uid, user.uid);
      await _loadChildrenList();
      if (_childrenList.isEmpty) _subscribeToChild(user.uid);
    } else {
      _childId = data['childId'] as String? ?? user.uid;
      _familyCode = data['familyCode'] ?? '';
      _parentId = data['parentId'] ?? '';
      _subscribeToChild(_childId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkDailyBonus());
    }
  }

  Future<void> _loadChildrenList() async {
    final list = await _service.getChildrenList(_auth.currentUser!.uid);
    if (mounted) {
      setState(() {
        _childrenList = list;
        if (_selectedChild == null && list.isNotEmpty) {
          _selectedChild = list.first;
          _subscribeToChild(_selectedChild!['id']);
        }
      });
    }
  }

  void _subscribeToChild(String childId) {
    _childSubscription?.cancel();
    _childSubscription = _service.childDocStream(childId).listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
          _rewards = List<Map<String, dynamic>>.from(data['rewards'] ?? []);
          _points = (data['points'] as num?)?.toInt() ?? 0;
          _streak = (data['loginStreak'] as num?)?.toInt() ?? 0;
        });
      }
    });
  }

  Future<void> _checkDailyBonus() async {
    if (_isParent) return;
    final doc = await _service.getChildDoc(_childId);
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastLogin = data['lastLoginDate'] as String? ?? '';
    var streak = data['loginStreak'] as int? ?? 0;
    if (lastLogin == todayStr) return;
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    int bonus;
    if (lastLogin == yesterdayStr) {
      streak++;
      bonus = 5 + (streak * 2);
    } else {
      streak = 1;
      bonus = 5;
    }
    await _service.updateDailyBonus(_childId,
        points: _points + bonus, lastLoginDate: todayStr, streak: streak);
    if (!mounted) return;
    _showBonusDialog(bonus, streak);
  }

  void _showBonusDialog(int bonus, int streak) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎁', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('+$bonus баллов!',
              style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.green)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.orange.shade400,
                  Colors.deepOrange.shade400
                ]),
                borderRadius: BorderRadius.circular(24)),
            child: Text('$streak дней 🔥',
                style: GoogleFonts.nunito(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              child: const Text('ЗАБРАТЬ!')),
        ]),
      ),
    );
  }

  Widget _buildAvatarPicker(
      String selectedAvatar, List<String> avatars, Function(String) onSelect) {
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: avatars
            .map((a) => GestureDetector(
                  onTap: () => onSelect(a),
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: selectedAvatar == a
                              ? Colors.purple.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: selectedAvatar == a
                              ? Border.all(color: Colors.purple, width: 2)
                              : null),
                      child: Text(a, style: const TextStyle(fontSize: 36))),
                ))
            .toList());
  }

  void _openSettings() {
    if (_isParent) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Text('👨‍👩‍👧 Код семьи',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                content: Row(children: [
                  Expanded(
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(_familyCode,
                              style: GoogleFonts.nunito(
                                  fontSize: 22, fontWeight: FontWeight.w900)))),
                  IconButton(
                      icon: const Icon(Icons.copy, color: Colors.purple),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _familyCode));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Код скопирован!')));
                      }),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Закрыть'))
                ],
              ));
    } else {
      final nameCtrl = TextEditingController(text: _displayName);
      String currentAvatar = _avatar;
      final avatars = [
        '👦',
        '👧',
        '🧒',
        '👶',
        '🐶',
        '🐱',
        '🦊',
        '🐼',
        '🌟',
        '🎮'
      ];

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('⚙️ Мой профиль',
                style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Кнопка загрузки своей аватарки
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 50);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      final url = await _service.uploadPhoto(_childId, bytes);
                      setDialog(() => currentAvatar = url);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo, color: Colors.purple),
                          const SizedBox(width: 8),
                          Text('Загрузить своё фото',
                              style: GoogleFonts.nunito(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Или выбери эмодзи:',
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                // Показываем текущую аватарку если это URL
                if (currentAvatar.startsWith('http'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(currentAvatar,
                          width: 80, height: 80, fit: BoxFit.cover),
                    ),
                  ),
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Имя в чате')),
                const SizedBox(height: 16),
                _buildAvatarPicker(currentAvatar, avatars,
                    (val) => setDialog(() => currentAvatar = val)),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isNotEmpty) {
                    await _service.updateChildProfileAsChild(
                        _childId,
                        _auth.currentUser!.uid,
                        _parentId,
                        nameCtrl.text.trim(),
                        currentAvatar);
                    if (mounted) {
                      setState(() {
                        _displayName = nameCtrl.text.trim();
                        _avatar = currentAvatar;
                      });
                      Navigator.pop(ctx);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _getChildId() => _selectedChild?['id'] ?? _childId;

  Future<void> _addTask() async {
    final nameCtrl = TextEditingController();
    final ptsCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('📝 Новое задание',
              style: GoogleFonts.nunito(
                  fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: 'Название', labelStyle: GoogleFonts.nunito())),
          const SizedBox(height: 12),
          TextField(
              controller: ptsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: 'Баллы ⭐', labelStyle: GoogleFonts.nunito())),
          const SizedBox(height: 12),
          TextField(
              controller: commentCtrl,
              decoration: InputDecoration(
                  labelText: 'Комментарий', labelStyle: GoogleFonts.nunito())),
          const SizedBox(height: 24),
          Text('Или выбери готовое:',
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Expanded(
              child: ListView.builder(
                  itemCount: _defaultTasks.length,
                  itemBuilder: (ctx, i) => ListTile(
                        title: Text(_defaultTasks[i]['name'] as String,
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w600)),
                        trailing: Text('+${_defaultTasks[i]['points']} ⭐',
                            style: GoogleFonts.nunito(
                                color: Colors.amber.shade700)),
                        onTap: () {
                          Navigator.pop(ctx);
                          final tasks = List<Map<String, dynamic>>.from(_tasks);
                          tasks.add({
                            'name': _defaultTasks[i]['name'],
                            'points': _defaultTasks[i]['points'],
                            'done': false,
                            'photos': [],
                            'comment': ''
                          });
                          _service.updateTasks(_getChildId(), tasks);
                        },
                      ))),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty && ptsCtrl.text.isNotEmpty) {
                      final tasks = List<Map<String, dynamic>>.from(_tasks);
                      tasks.add({
                        'name': nameCtrl.text.trim(),
                        'points': int.parse(ptsCtrl.text),
                        'done': false,
                        'photos': [],
                        'comment': commentCtrl.text.trim()
                      });
                      _service.updateTasks(_getChildId(), tasks);
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 18)),
                  child: Text('Добавить своё',
                      style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)))),
        ]),
      ),
    );
  }

  Future<void> _toggleTask(int i) async {
    if (!_isParent) return;
    final tasks = List<Map<String, dynamic>>.from(_tasks);
    final t = tasks[i];
    t['done'] = !(t['done'] == true);
    final pts = (t['points'] as num).toInt();
    await _service.updateTasks(_getChildId(), tasks);
    await _service.updatePoints(
        _getChildId(), _points + (t['done'] == true ? pts : -pts));
  }

  Future<void> _deleteTask(int i) async {
    final tasks = List<Map<String, dynamic>>.from(_tasks);
    tasks.removeAt(i);
    await _service.updateTasks(_getChildId(), tasks);
  }

  Future<void> _addReward() async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text('🎁 Новая награда',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Название')),
                const SizedBox(height: 16),
                TextField(
                    controller: costCtrl,
                    decoration: const InputDecoration(labelText: 'Стоимость'),
                    keyboardType: TextInputType.number),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Отмена')),
                ElevatedButton(
                    onPressed: () async {
                      final cost = int.tryParse(costCtrl.text);
                      if (nameCtrl.text.trim().isNotEmpty && cost != null) {
                        final rewards =
                            List<Map<String, dynamic>>.from(_rewards);
                        rewards.add({
                          'name': nameCtrl.text.trim(),
                          'cost': cost,
                          'bought': false
                        });
                        await _service.updateRewards(_getChildId(), rewards);
                        if (mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple),
                    child: const Text('Добавить')),
              ],
            ));
  }

  Future<void> _buyReward(int i) async {
    if (_isParent) return;
    final r = _rewards[i];
    final cost = (r['cost'] as num).toInt();
    if (_points >= cost && !r['bought']) {
      final rewards = List<Map<String, dynamic>>.from(_rewards);
      rewards[i]['bought'] = true;
      await _service.updateRewards(_childId, rewards);
      await _service.updatePoints(_childId, _points - cost);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 ${r['name']} куплено!'),
          backgroundColor: Colors.green));
    }
  }

  Future<void> _resetReward(int i) async {
    final rewards = List<Map<String, dynamic>>.from(_rewards);
    rewards[i]['bought'] = false;
    await _service.updateRewards(_getChildId(), rewards);
  }

  Future<void> _deleteReward(int i) async {
    final rewards = List<Map<String, dynamic>>.from(_rewards);
    rewards.removeAt(i);
    await _service.updateRewards(_getChildId(), rewards);
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty)
      return Center(
          child: Text('Нет заданий',
              style: GoogleFonts.nunito(
                  fontSize: 18, color: Colors.grey.shade500)));
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (ctx, i) => TaskCard(
            task: _tasks[i],
            isParent: _isParent,
            docId: _getChildId(),
            onToggle: () => _toggleTask(i),
            onDelete: () => _deleteTask(i),
            onPhotoUploaded: (url) {
              final tasks = List<Map<String, dynamic>>.from(_tasks);
              final p = List<dynamic>.from(tasks[i]['photos'] ?? []);
              p.add(url);
              tasks[i]['photos'] = p;
              _service.updateTasks(_getChildId(), tasks);
            }).animate().fadeIn(delay: (i * 80).ms));
  }

  Widget _buildRewardsTab() {
    if (_rewards.isEmpty)
      return Center(
          child: Text('Нет наград',
              style: GoogleFonts.nunito(
                  fontSize: 18, color: Colors.grey.shade500)));
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rewards.length,
        itemBuilder: (ctx, i) => RewardCard(
                reward: _rewards[i],
                isParent: _isParent,
                points: _points,
                onBuy: () => _buyReward(i),
                onReset: () => _resetReward(i),
                onDelete: () => _deleteReward(i))
            .animate()
            .fadeIn(delay: (i * 80).ms));
  }

  Widget _buildChatTab() {
    if (_familyCode.isEmpty)
      return Center(
          child: Text('Чат недоступен',
              style: GoogleFonts.nunito(
                  color: Colors.grey.shade500, fontSize: 18)));
    return ChatWidget(familyCode: _familyCode, senderName: _displayName);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        _isParent ? const Color(0xFF6C5CE7) : const Color(0xFF00CEC9);
    final secondaryColor =
        _isParent ? const Color(0xFFA29BFE) : const Color(0xFF81ECEC);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, secondaryColor]),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15))
            ],
          ),
          child: SafeArea(
              bottom: false,
              child: Column(children: [
                Row(children: [
                  // Аватарка (эмодзи или фото)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _avatar.startsWith('http')
                        ? Image.network(_avatar,
                            width: 48, height: 48, fit: BoxFit.cover)
                        : Container(
                            alignment: Alignment.center,
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5)),
                            child: Text(_avatar,
                                style: const TextStyle(fontSize: 26)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Привет,',
                            style: GoogleFonts.nunito(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        if (_isParent && _childrenList.length > 1)
                          DropdownButton<String>(
                            value: _selectedChild?['id'] ?? _childId,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: primaryColor,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Colors.white),
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                            items: _childrenList
                                .map<DropdownMenuItem<String>>((c) =>
                                    DropdownMenuItem<String>(
                                        value: c['id'] as String,
                                        child:
                                            Text(c['name'] as String? ?? '')))
                                .toList(),
                            onChanged: (id) {
                              if (id == null) return;
                              setState(() {
                                _selectedChild = _childrenList
                                    .firstWhere((c) => c['id'] == id);
                                _subscribeToChild(id);
                              });
                            },
                          )
                        else
                          Text(_selectedChild?['name'] ?? _displayName,
                              style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                      ])),
                  _GlassButton(
                      icon: Icons.settings_outlined, onTap: _openSettings),
                  const SizedBox(width: 6),
                  _GlassButton(
                      icon: Icons.logout_rounded,
                      onTap: () async {
                        await _service.signOut();
                        if (!mounted) return;
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AuthScreen()));
                      }),
                ]),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ]),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.amber.shade400,
                                  Colors.orange.shade400
                                ]),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.star_rounded,
                                color: Colors.white, size: 30)),
                        const SizedBox(width: 14),
                        Text('$_points',
                            style: GoogleFonts.nunito(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2D3436))),
                        const SizedBox(width: 6),
                        Text('баллов',
                            style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
                if (!_isParent && _streak > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.orange.shade500,
                          Colors.deepOrange.shade500
                        ]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6))
                        ]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text('$_streak дней подряд!',
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14))
                    ]),
                  ),
                ],
              ])),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4))
                ]),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                  gradient:
                      LinearGradient(colors: [primaryColor, secondaryColor]),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade400,
              labelStyle:
                  GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(
                    icon: Icon(Icons.checklist_rounded, size: 22),
                    text: 'Задания'),
                Tab(
                    icon: Icon(Icons.card_giftcard_rounded, size: 22),
                    text: 'Награды'),
                Tab(icon: Icon(Icons.chat_rounded, size: 22), text: 'Чат'),
              ],
            ),
          ),
        ),
        Expanded(
            child: TabBarView(controller: _tabController, children: [
          _buildTasksTab(),
          _buildRewardsTab(),
          _buildChatTab()
        ])),
      ]),
      floatingActionButton: _isParent && _tabController.index != 2
          ? Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]),
              child: FloatingActionButton.extended(
                onPressed: () =>
                    _tabController.index == 0 ? _addTask() : _addReward(),
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 26),
                label: Text(_tabController.index == 0 ? 'Задание' : 'Награду',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                backgroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            )
          : null,
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
