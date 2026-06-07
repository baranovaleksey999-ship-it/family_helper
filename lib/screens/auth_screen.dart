import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLogin = true;
  bool _isParent = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _generateCode() => (100000 + Random().nextInt(900000)).toString();

  Future<void> _submit() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.trim().isEmpty) {
      _showError('Заполни все поля');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(
            _emailCtrl.text.trim(), _passCtrl.text.trim());

        if (!mounted) return;
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainScreen()));
        return;
      } else {
        final userCred = await _authService.signUp(
            _emailCtrl.text.trim(), _passCtrl.text.trim());
        final uid = userCred.user!.uid;

        if (_isParent) {
          final code = _generateCode();
          await _authService.saveFamilyCode(code, uid);

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'role': 'parent',
            'familyCode': code,
            'displayName': 'Родитель',
            'avatar': '👨',
            'email': _emailCtrl.text.trim(),
            'childrenList': [],
          });

          await _firestoreService.initFirstChild(uid, uid);

          if (!mounted) return;
          _showCodeDialog(code);
          return;
        } else {
          final code = _codeCtrl.text.trim();
          if (code.isEmpty) {
            _showError('Введи код семьи');
            setState(() => _isLoading = false);
            return;
          }

          final parentId = await _authService.findParentByFamilyCode(code);
          if (parentId == null) {
            _showError('Код семьи не найден');
            setState(() => _isLoading = false);
            return;
          }

          String? existingChildId = await _firestoreService.getChildIdByEmail(
              parentId, _emailCtrl.text.trim());

          String childId;
          if (existingChildId != null) {
            childId = existingChildId;
          } else {
            childId = await _firestoreService.addChild(
                parentId, 'Ребёнок', '🌟', _emailCtrl.text.trim());
          }

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'role': 'child',
            'parentId': parentId,
            'childId': childId,
            'familyCode': code,
            'displayName': 'Ребёнок',
            'avatar': '🌟',
            'email': _emailCtrl.text.trim(),
          });

          if (!mounted) return;
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MainScreen()));
          return;
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(_mapFirebaseError(e.code));
    } catch (e) {
      _showError(e.toString());
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email уже занят';
      case 'invalid-email':
        return 'Неверный email';
      case 'weak-password':
        return 'Минимум 6 символов';
      case 'user-not-found':
        return 'Пользователь не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      default:
        return 'Ошибка авторизации';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito()),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text('🔑 Твой код семьи',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)]),
                borderRadius: BorderRadius.circular(20)),
            child: Text(code,
                style: GoogleFonts.nunito(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 8)),
          ),
          const SizedBox(height: 16),
          Text('Сохрани код — он нужен для входа ребёнка',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: Colors.grey.shade600)),
        ]),
        actions: [
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!mounted) return;
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const MainScreen()));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7)),
              child: Text('Запомнил!',
                  style: GoogleFonts.nunito(color: Colors.white)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
              Color(0xFF6C5CE7),
              Color(0xFFA29BFE),
              Color(0xFF00CEC9)
            ])),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 30)
                            ]),
                        child: const Icon(Icons.family_restroom_rounded,
                            size: 64, color: Color(0xFF6C5CE7))),
                    const SizedBox(height: 24),
                    Text('Family Helper',
                        style: GoogleFonts.nunito(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10))
                          ]),
                      child: Column(children: [
                        Container(
                          decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(30)),
                          child: Row(children: [
                            _TabButton(
                                text: 'Вход',
                                active: _isLogin,
                                onTap: _isLoading
                                    ? () {}
                                    : () => setState(() => _isLogin = true)),
                            _TabButton(
                                text: 'Регистрация',
                                active: !_isLogin,
                                onTap: _isLoading
                                    ? () {}
                                    : () => setState(() => _isLogin = false)),
                          ]),
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 20),
                          Text('Выбери роль:',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700)),
                          const SizedBox(height: 12),
                          Row(children: [
                            _RoleButton(
                                icon: Icons.family_restroom_rounded,
                                label: 'Родитель',
                                active: _isParent,
                                onTap: _isLoading
                                    ? () {}
                                    : () => setState(() => _isParent = true)),
                            const SizedBox(width: 12),
                            _RoleButton(
                                icon: Icons.child_care_rounded,
                                label: 'Ребёнок',
                                active: !_isParent,
                                onTap: _isLoading
                                    ? () {}
                                    : () => setState(() => _isParent = false)),
                          ]),
                        ],
                        if (!_isLogin && !_isParent) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _codeCtrl,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                                labelText: 'Код семьи',
                                labelStyle: GoogleFonts.nunito(),
                                prefixIcon: const Icon(Icons.key_rounded,
                                    color: Color(0xFF6C5CE7)),
                                counterText: ''),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                            controller: _emailCtrl,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                                labelText: 'Email',
                                labelStyle: GoogleFonts.nunito(),
                                prefixIcon: const Icon(Icons.email_rounded,
                                    color: Color(0xFF6C5CE7)))),
                        const SizedBox(height: 16),
                        TextField(
                            controller: _passCtrl,
                            enabled: !_isLoading,
                            obscureText: true,
                            decoration: InputDecoration(
                                labelText: 'Пароль',
                                labelStyle: GoogleFonts.nunito(),
                                prefixIcon: const Icon(Icons.lock_rounded,
                                    color: Color(0xFF6C5CE7)))),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLogin
                                  ? const Color(0xFF6C5CE7)
                                  : const Color(0xFF00CEC9),
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _isLogin ? 'Войти' : 'Зарегистрироваться',
                                    style: GoogleFonts.nunito(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;
  const _TabButton(
      {required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: active ? const Color(0xFF6C5CE7) : Colors.transparent,
              borderRadius: BorderRadius.circular(30)),
          child: Text(text,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.grey.shade500)),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RoleButton(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF6C5CE7) : Colors.grey;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
              color: active ? color.withOpacity(0.08) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: active ? color : Colors.transparent, width: 2)),
          child: Column(children: [
            Icon(icon, size: 42, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700, color: color))
          ]),
        ),
      ),
    );
  }
}
