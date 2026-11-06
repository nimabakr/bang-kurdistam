import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'features/app_shell.dart';
import 'services/baghdad_clock.dart';
import 'services/localization.dart';
import 'services/prayer_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeBangTimeZones();
  final prayerNotifications = PrayerNotifications();
  String? notificationInitializationError;
  try {
    await prayerNotifications.initialize();
  } on PlatformException catch (error) {
    notificationInitializationError =
        'نۆتیفیکەیشن نەتوانرا دەستپێبکرێت: ${error.message}';
  } on MissingPluginException catch (error) {
    notificationInitializationError =
        'خزمەتی نۆتیفیکەیشن بەردەست نییە: ${error.message}';
  }
  final state = await BangAppState.load();
  state.attachPrayerNotifications(prayerNotifications);
  state.notificationError = notificationInitializationError;
  runApp(BangApp(state: state));
  unawaited(state.loadScheduleFor(baghdadNow()));
}

class BangApp extends StatelessWidget {
  const BangApp({required this.state, super.key});

  final BangAppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final dark = ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoSansArabic',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F6654),
            brightness: Brightness.dark,
            primary: const Color(0xFF86D1AE),
            secondary: const Color(0xFFD8B46A),
            surface: const Color(0xFF14251F),
          ),
          scaffoldBackgroundColor: const Color(0xFF0B1713),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B1713),
            foregroundColor: Color(0xFFF4F4ED),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1B3028).withValues(alpha: .82),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: .12)),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 70,
            backgroundColor: const Color(0xFF14251F).withValues(alpha: .9),
            indicatorColor: const Color(0xFF86D1AE).withValues(alpha: .18),
            elevation: 0,
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(color: Colors.white.withValues(alpha: .84)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF14251F).withValues(alpha: .72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .14),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: .12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF86D1AE),
                width: 1.5,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: .18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFF14251F).withValues(alpha: .96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: Colors.white.withValues(alpha: .13)),
            ),
          ),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: const Color(0xFF14251F).withValues(alpha: .96),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        );
        final light = ThemeData(
          useMaterial3: true,
          fontFamily: 'NotoSansArabic',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F6654),
            brightness: Brightness.light,
            primary: const Color(0xFF146A56),
            secondary: const Color(0xFF9A712A),
            surface: const Color(0xFFF9F7F1),
          ),
          scaffoldBackgroundColor: const Color(0xFFF3F4EF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF3F4EF),
            foregroundColor: Color(0xFF172B24),
          ),
          cardTheme: CardThemeData(
            color: Colors.white.withValues(alpha: .84),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: const Color(0xFF172B24).withValues(alpha: .1),
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            height: 70,
            backgroundColor: const Color(0xFFF9F7F1).withValues(alpha: .9),
            indicatorColor: const Color(0xFF146A56).withValues(alpha: .12),
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withValues(alpha: .72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: const Color(0xFF172B24).withValues(alpha: .12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: const Color(0xFF172B24).withValues(alpha: .1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF146A56),
                width: 1.5,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: const Color(0xFF172B24).withValues(alpha: .16),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFFF9F7F1).withValues(alpha: .98),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(
                color: const Color(0xFF172B24).withValues(alpha: .1),
              ),
            ),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFFF9F7F1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        );

        final materialLocale = switch (state.appLanguage) {
          AppLanguage.ku => const Locale('en'),
          AppLanguage.ar => const Locale('ar'),
          AppLanguage.en => const Locale('en'),
        };

        return MaterialApp(
          title: 'بانگ | Kurdistan',
          debugShowCheckedModeBanner: false,
          locale: materialLocale,
          supportedLocales: const [Locale('ku'), Locale('ar'), Locale('en')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizationsDelegate(state.appLanguage),
          ],
          theme: light,
          darkTheme: dark,
          themeMode: state.themeMode,
          builder: (context, child) => Directionality(
            textDirection: state.appLanguage == AppLanguage.en
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: child!,
          ),
          home: AppShell(state: state),
        );
      },
    );
  }
}
