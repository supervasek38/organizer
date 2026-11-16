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
part 'organizer_shell.dart';

void main() => runApp(const MontasApp(seedDemo: true));

abstract final class C {
  static const canvas = Color(0xFFF5F7F6);
  static const ink = Color(0xFF0B0F0E);
  static const muted = Color(0xFF5B6660);
  static const line = Color(0xFFE6EAE4);
  static const soft = Color(0xFFF5F7F6);
  static const dark = Color(0xFF0B0F0E);
  static const green = Color(0xFF086136);
  static const mint = Color(0xFFDEF8E2);
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
        seedColor: C.ink,
        secondary: C.ink,
        secondaryContainer: C.mint,
        onSecondaryContainer: C.ink,
        surfaceTint: Colors.transparent,
        primary: C.dark,
        surface: Colors.white,
      ),
      textTheme: TextTheme(bodyMedium: tx(14), bodyLarge: tx(15)),
      dividerColor: C.line,
      visualDensity: VisualDensity.standard,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: C.ink,
        contentTextStyle: tx(14, color: Colors.white),
        insetPadding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: tx(14, color: C.muted),
        hintStyle: tx(14, color: C.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: C.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: C.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: tx(14, weight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: C.ink,
          backgroundColor: Colors.white,
          minimumSize: const Size(44, 48),
          side: const BorderSide(color: C.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: tx(14, weight: FontWeight.w500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: C.mint,
        side: const BorderSide(color: C.line),
        labelStyle: tx(13, weight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

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
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      borderRadius: BorderRadius.circular(24),
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
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: C.lime,
      foregroundColor: C.ink,
      disabledBackgroundColor: C.soft,
      disabledForegroundColor: C.muted,
      minimumSize: const Size(double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: tx(15, weight: FontWeight.w600),
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
      color: green ? C.mint : C.soft,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: tx(11, color: green ? C.ink : C.muted, weight: FontWeight.w500),
    ),
  );
}
