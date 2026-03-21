import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _BagParticle {
  _BagParticle({
    required this.x,
    required this.speed,
    required this.phase,
    required this.size,
    required this.opacity,
  });

  final double x; // 0..1 (fraction of screen width)
  final double speed; // relative fall speed
  final double phase; // starting offset in animation
  final double size; // icon size
  final double opacity; // 0..1
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final GlobalKey _cardKey = GlobalKey();
  ui.Rect? _cardRect;

  late final AnimationController _rainController;
  late final List<_BagParticle> _bags;

  @override
  void initState() {
    super.initState();
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    final random = Random();
    _bags = List.generate(25, (_) {
      return _BagParticle(
        x: random.nextDouble(),
        speed: 0.5 + random.nextDouble(),
        phase: random.nextDouble(),
        size: 18 + random.nextDouble() * 22,
        opacity: 0.3 + random.nextDouble() * 0.5,
      );
    });
  }

  @override
  void dispose() {
    _rainController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateCardRect() {
    final context = _cardKey.currentContext;
    if (context == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final position = box.localToGlobal(Offset.zero);
    final newRect = ui.Rect.fromLTWH(
      position.dx,
      position.dy,
      box.size.width,
      box.size.height,
    );

    if (_cardRect == newRect) return;

    setState(() {
      _cardRect = newRect;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateCardRect());
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
              ),
            ),
          ),

          // Shopping bag "rain" layer
          AnimatedBuilder(
            animation: _rainController,
            builder: (context, child) {
              final size = MediaQuery.of(context).size;
              return IgnorePointer(
                ignoring: true,
                child: Stack(
                  children: _bags.map((bag) {
                    final progress =
                        (_rainController.value * bag.speed + bag.phase) % 1.0;
                    final top = -60 + progress * (size.height + 120);

                    final bagTop = top;
                    final bagBottom = top + bag.size;
                    final bagLeft = bag.x * size.width;
                    final bagRight = bagLeft + bag.size;

                    bool isOverCard = false;
                    final cardRect = _cardRect;
                    if (cardRect != null) {
                      if (bagRight > cardRect.left &&
                          bagLeft < cardRect.right &&
                          bagBottom > cardRect.top &&
                          bagTop < cardRect.bottom) {
                        isOverCard = true;
                      }
                    }

                    if (isOverCard) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      top: top,
                      left: bag.x * size.width,
                      child: Opacity(
                        opacity: bag.opacity,
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: bag.size,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),

          // Foreground content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo / Title area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Smart Billing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Employee portal for smarter billing',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),

                      const SizedBox(height: 32),

                      // Glassmorphism login card
                      Container(
                        key: _cardKey,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign in',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use your employee credentials to continue',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),

                            const SizedBox(height: 24),

                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Work email',
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Colors.white70,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.lightBlueAccent,
                                    width: 1.6,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                              ),
                            ),

                            const SizedBox(height: 16),

                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.white70,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.25),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.lightBlueAccent,
                                    width: 1.6,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.03),
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              height: 48,
                              child: authProvider.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.lightBlueAccent,
                                            ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.lightBlueAccent,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        await authProvider.login(
                                          _emailController.text,
                                          _passwordController.text,
                                        );
                                      },
                                      child: const Text(
                                        'Continue',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),

                            if (authProvider.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'By continuing you agree to the smart billing terms of use.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
