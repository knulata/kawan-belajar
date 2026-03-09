import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/student.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    await context.read<StudentProvider>().loadSaved();
  }

  void _onDigitPressed(String digit) {
    if (_pin.length >= 4 || _isLoading) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    if (_pin.length == 4) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _isLoading) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _submitPin() async {
    if (_pin.length != 4) return;
    setState(() => _isLoading = true);

    final error = await context.read<StudentProvider>().loginWithPin(_pin);

    if (error != null && mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
        _pin = '';
      });
      _shakeController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final val = _shakeController.value;
        final offset = _shakeController.isAnimating
            ? 12.0 * (2.0 * (val * 4.0 - (val * 4.0).floorToDouble()) - 1.0).abs() *
                ((val * 4.0).floor().isEven ? 1.0 : -1.0)
            : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final filled = index < _pin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: filled ? 24 : 20,
            height: filled ? 24 : 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _errorMessage != null
                  ? Colors.red.shade400
                  : filled
                      ? Colors.white
                      : Colors.white.withAlpha(60),
              border: Border.all(
                color: Colors.white.withAlpha(180),
                width: 2,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: Colors.white.withAlpha(60),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNumberButton(String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap ?? () => _onDigitPressed(label),
            child: Container(
              height: 72,
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        children: [
          Row(children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ]),
          Row(children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ]),
          Row(children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ]),
          Row(children: [
            // Empty spacer
            Expanded(child: SizedBox(height: 84)),
            _buildNumberButton('0'),
            // Backspace
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _onBackspace,
                    child: Container(
                      height: 72,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
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
            colors: [Color(0xFF81C784), Color(0xFF4CAF50), Color(0xFF388E3C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kawi the Owl — compact
                  FadeInDown(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '\u{1F989}',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  FadeInDown(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      'kawabel',
                      style: GoogleFonts.nunito(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeInDown(
                    delay: const Duration(milliseconds: 250),
                    child: Text(
                      'Masukkan PIN kamu',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withAlpha(220),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // PIN dots
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _buildDots(),
                  ),
                  const SizedBox(height: 12),

                  // Error message
                  AnimatedOpacity(
                    opacity: _errorMessage != null ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _errorMessage ?? '',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Loading indicator
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),

                  // Number pad
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _buildNumberPad(),
                  ),
                  const SizedBox(height: 24),

                  // Help text
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Text(
                      'Belum punya PIN? Minta ke guru',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(160),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }
}
