import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'local_file.dart';
import 'file_bridge_stub.dart'
    if (dart.library.js_interop) 'file_bridge_web.dart'
    as file_bridge;
part 'discovery.dart';
part 'events.dart';
part 'organizer.dart';
part 'organizer_demo.dart';
part 'event_workspace.dart';
part 'event_ticket_editor.dart';
part 'event_operations.dart';
part 'partnerships.dart';
part 'partnerships_views.dart';
part 'organizer_today.dart';

void main() => runApp(const MontasApp(seedDemo: true));

abstract final class C {
  static const canvas = Color(0xFFF5F7F6);
  static const ink = Color(0xFF0B0F0E);
  static const muted = Color(0xFF66716B);
  static const line = Color(0xFFE6EAE4);
  static const soft = Color(0xFFF2F4EF);
  static const dark = Color(0xFF0A2019);
  static const green = Color(0xFF008F4C);
  static const lime = Color(0xFFB6FF00);
}

TextStyle tx(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = C.ink,
  double? height,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height ?? 1.45,
);

class MontasApp extends StatelessWidget {
  const MontasApp({this.seedDemo = false, super.key});
  final bool seedDemo;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MONTAS · Организатор',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Onest',
      scaffoldBackgroundColor: C.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: C.green,
        primary: C.dark,
        surface: Colors.white,
      ),
      textTheme: TextTheme(bodyMedium: tx(14), bodyLarge: tx(15)),
      dividerColor: C.line,
      tooltipTheme: TooltipThemeData(
        textStyle: tx(12, color: Colors.white),
        decoration: BoxDecoration(
          color: C.dark,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: C.dark,
          textStyle: const TextStyle(
            fontFamily: 'Onest',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
    home: OrganizerDemo(seedDemo: seedDemo),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    required this.child,
    this.padding = 24,
    this.color = Colors.white,
    super.key,
  });
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
      border: color == Colors.white ? Border.all(color: C.line) : null,
      boxShadow: color == Colors.white
          ? const [
              BoxShadow(
                color: Color(0x05061713),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, this.onPressed, {super.key});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: onPressed == null
          ? null
          : const LinearGradient(
              colors: [Color(0xFFC8FF4D), Color(0xFF5CEB7A)],
            ),
      color: onPressed == null ? C.soft : null,
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: const StadiumBorder(),
        foregroundColor: C.ink,
        disabledForegroundColor: C.muted,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Onest',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class RoundAction extends StatelessWidget {
  const RoundAction(
    this.icon,
    this.label,
    this.onPressed, {
    this.color = C.ink,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .9),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 21, color: color),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {this.green = false, super.key});
  final String text;
  final bool green;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: green ? const Color(0xFFEAFBD9) : C.soft,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: tx(11, color: green ? C.green : C.muted, weight: FontWeight.w500),
    ),
  );
}
