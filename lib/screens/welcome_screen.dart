import 'package:flutter/material.dart';

import '../data/options.dart';
import '../theme/app_theme.dart';
import '../widgets/book_stack_art.dart';
import 'auth_screen.dart';

/// The first page anyone sees before signing up or logging in.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text('T B R', style: AppText.serif(size: 22, color: AppColors.green)),
                      ),
                      const Spacer(),
                      Center(
                        child: BookStackArt(
                          width: constraints.maxWidth * 0.72 > 300 ? 300 : constraints.maxWidth * 0.72,
                        ),
                      ),
                      const Spacer(),
                      Text(welcomeQuote, style: AppText.hand(size: 30).copyWith(height: 1.15)),
                      const _Swoosh(),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Find your next favourite book.',
                          style: AppText.sans(size: 14, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const AuthScreen(startWithSignUp: true))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text("Let's go"),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, size: 20, color: AppColors.sand),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hand-drawn underline under the quote.
class _Swoosh extends StatelessWidget {
  const _Swoosh();

  @override
  Widget build(BuildContext context) => SizedBox(width: 240, height: 14, child: CustomPaint(painter: _SwooshPainter()));
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, size.height - 3)
      ..cubicTo(size.width * .3, 2, size.width * .8, 2, size.width - 6, 6);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.green
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
