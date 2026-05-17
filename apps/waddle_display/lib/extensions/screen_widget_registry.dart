import 'dart:io';

import 'package:flutter/material.dart';
import 'package:waddle_shared/blob/blob_store.dart';
import 'package:waddle_shared/layout/screen_layout_parse.dart';
import 'package:waddle_shared/persistence/database.dart';

import '../curator/screen_program_curator.dart';
import '../display/viewer_invite_runtime.dart';
import '../display/screens/admin_setup/admin_setup_slide_widget.dart';
import '../display/screens/calendar_month/calendar_month_slide_widget.dart';
import '../display/screens/clock/analog_clock_slide_widget.dart';
import '../display/screens/clock/digital_clock_slide_widget.dart';
import '../display/screens/controller_invite/controller_invite_slide_widget.dart';
import '../display/screens/data_health/data_health_slide_widget.dart';
import '../display/screens/guest_wifi/guest_wifi_slide_widget.dart';
import '../display/screens/joke/joke_slide_widget.dart';
import '../display/screens/local_api/local_api_slide_widget.dart';
import '../display/screens/photo/photo_collage_slide_widget.dart';
import '../display/screens/photo/photo_slide_widget.dart';
import '../display/screens/photo/video_slide_widget.dart';
import '../display/screens/news/news_columns_slide_widget.dart';
import '../display/screens/news/news_slide_widget.dart';
import '../display/screens/news/news_stack_slide_widget.dart';
import '../display/screens/plugin_template/plugin_template_slide_widget.dart';
import '../display/screens/stock_quotes/stock_quotes_slide_widget.dart';
import '../display/screens/trivia/trivia_slide_widget.dart';
import '../display/screens/weather/weather_slide_widget.dart';
import '../display/screens/web_page/web_page_slide_widget.dart';

class ScreenWidgetBuildContext {
  const ScreenWidgetBuildContext({
    required this.db,
    required this.blobs,
    required this.localRestBaseUrl,
    required this.adminBaseUrl,
    required this.instanceIdFile,
    required this.viewerInviteRuntime,
    required this.slide,
    required this.theme,
    required this.slideIndex,
    required this.allowVideoPlayback,
    required this.onReportDesiredDwell,
    required this.gap,
  });

  final AppDatabase db;
  final BlobStore blobs;
  final String localRestBaseUrl;
  final String adminBaseUrl;
  final File instanceIdFile;
  final ViewerInviteRuntime viewerInviteRuntime;
  final ResolvedSlide slide;
  final ThemeData theme;
  final int slideIndex;
  final bool allowVideoPlayback;
  final void Function(int slideIndex, int ms) onReportDesiredDwell;
  final double gap;
}

class ScreenWidgetRegistry {
  const ScreenWidgetRegistry();

  Widget buildInColumn(ScreenWidgetBuildContext ctx, ParsedWidgetSpec w) {
          switch (w.type) {
            case 'static_text':
              final text = w.config['text'] as String? ?? '';
              return Padding(
                padding: EdgeInsets.only(bottom: ctx.gap),
                child: Text(
                  text,
                  style: ctx.theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              );
            case 'joke':
              return JokeSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'trivia':
              return TriviaSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'wifi':
              return GuestWifiSlideWidget(spec: w, theme: ctx.theme);
            case 'digital_clock':
              return DigitalClockSlideWidget(spec: w, theme: ctx.theme);
            case 'analog_clock':
              return AnalogClockSlideWidget(spec: w, theme: ctx.theme);
            case 'calendar_month':
              return CalendarMonthSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                spec: w,
                theme: ctx.theme,
              );
            case 'photo_random':
              final key = ctx.slide.randomChoices[w.choiceKey];
              return Padding(
                padding: EdgeInsets.only(bottom: ctx.gap),
                child: Text(
                  key != null ? 'Photo: $key' : 'No photo in pool',
                  style: ctx.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              );
            case 'news':
              return NewsSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
                onReportDesiredDwell: (ms) =>
                    ctx.onReportDesiredDwell(ctx.slideIndex, ms),
              );
            case 'news_columns':
              return NewsColumnsSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
                onReportDesiredDwell: (ms) =>
                    ctx.onReportDesiredDwell(ctx.slideIndex, ms),
              );
            case 'news_stack':
              return NewsStackSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
                onReportDesiredDwell: (ms) =>
                    ctx.onReportDesiredDwell(ctx.slideIndex, ms),
              );
            case 'local_api':
              return LocalApiSlideWidget(
                baseUrl: ctx.localRestBaseUrl,
                spec: w,
                theme: ctx.theme,
              );
            case 'admin_setup':
              return AdminSetupSlideWidget(
                adminBaseUrl: ctx.adminBaseUrl,
                instanceIdFile: ctx.instanceIdFile,
                spec: w,
                theme: ctx.theme,
              );
            case 'controller_invite':
              return ControllerInviteSlideWidget(
                displayApiBaseUrl: ctx.localRestBaseUrl,
                viewerInviteRuntime: ctx.viewerInviteRuntime,
                spec: w,
                theme: ctx.theme,
              );
            case 'weather':
              return WeatherSlideWidget(
                db: ctx.db,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'photo':
              return PhotoSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'photo_collage':
              return PhotoCollageSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'video':
              return VideoSlideWidget(
                db: ctx.db,
                blobs: ctx.blobs,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
                allowPlayback: ctx.allowVideoPlayback,
              );
            case 'stock_quotes':
              return StockQuotesSlideWidget(
                db: ctx.db,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'data_health':
              return DataHealthSlideWidget(
                db: ctx.db,
                slide: ctx.slide,
                spec: w,
                theme: ctx.theme,
              );
            case 'plugin_template':
              return PluginTemplateSlideWidget(
                spec: w,
                theme: ctx.theme,
              );
            case 'web_page':
              return WebPageSlideWidget(
                slide: ctx.slide,
                spec: w,
                onReportDesiredDwell: (ms) =>
                    ctx.onReportDesiredDwell(ctx.slideIndex, ms),
              );
            default:
              return Padding(
                padding: EdgeInsets.only(bottom: ctx.gap),
                child: Text(
                  'Unknown widget: ${w.type}',
                  style: ctx.theme.textTheme.bodyMedium,
                ),
              );
          }

  }
}
