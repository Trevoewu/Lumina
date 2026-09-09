import 'package:flutter/material.dart';

enum AppNavigationSymbol { home, discover, dictionary, me }

/// A shared 24-point outline family for the desktop navigation rail.
/// Color and size follow the rail's IconTheme, including selection and dark mode.
class AppNavigationIcon extends StatelessWidget {
  const AppNavigationIcon(this.symbol, {super.key});

  final AppNavigationSymbol symbol;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    final color = (theme.color ?? Theme.of(context).colorScheme.onSurface)
        .withValues(alpha: theme.opacity ?? 1);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _NavigationIconPainter(symbol, color)),
    );
  }
}

class _NavigationIconPainter extends CustomPainter {
  const _NavigationIconPainter(this.symbol, this.color);

  final AppNavigationSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (symbol) {
      case AppNavigationSymbol.home:
        canvas.drawPath(
          Path()
            ..moveTo(3, 10.5)
            ..lineTo(11, 3.8)
            ..quadraticBezierTo(12, 3, 13, 3.8)
            ..lineTo(21, 10.5)
            ..moveTo(5.5, 8.5)
            ..lineTo(5.5, 19)
            ..quadraticBezierTo(5.5, 20, 6.5, 20)
            ..lineTo(9.5, 20)
            ..lineTo(9.5, 14)
            ..lineTo(14.5, 14)
            ..lineTo(14.5, 20)
            ..lineTo(17.5, 20)
            ..quadraticBezierTo(18.5, 20, 18.5, 19)
            ..lineTo(18.5, 8.5),
          pen,
        );
      case AppNavigationSymbol.discover:
        canvas.drawCircle(const Offset(10.5, 10.5), 6.5, pen);
        canvas.drawLine(const Offset(15.2, 15.2), const Offset(20, 20), pen);
      case AppNavigationSymbol.dictionary:
        canvas.drawPath(
          Path()
            ..moveTo(19, 10)
            ..lineTo(19, 4)
            ..quadraticBezierTo(19, 3, 18, 3)
            ..lineTo(6, 3)
            ..quadraticBezierTo(4, 3, 4, 5)
            ..lineTo(4, 18.5)
            ..quadraticBezierTo(4, 20.5, 6, 20.5)
            ..lineTo(12, 20.5)
            ..moveTo(4, 17)
            ..quadraticBezierTo(4, 15.5, 6, 15.5)
            ..lineTo(8, 15.5)
            ..moveTo(7.5, 3)
            ..lineTo(7.5, 12)
            ..moveTo(10.5, 7)
            ..lineTo(15.5, 7),
          pen,
        );
        canvas.drawCircle(const Offset(15.5, 15), 3.5, pen);
        canvas.drawLine(const Offset(18, 17.5), const Offset(21, 20.5), pen);
      case AppNavigationSymbol.me:
        canvas.drawCircle(const Offset(12, 7), 3.5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(5, 20)
            ..lineTo(5, 18)
            ..cubicTo(5, 12.5, 19, 12.5, 19, 18)
            ..lineTo(19, 20)
            ..close(),
          pen,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NavigationIconPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
