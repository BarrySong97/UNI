import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(instance != null, 'AppLocalizations not found in widget tree.');
    return instance!;
  }

  static const Map<String, Map<String, String>>
  _strings = <String, Map<String, String>>{
    'en': <String, String>{
      'appTitle': 'Uni Reader',
      'libraryTitle': 'Library',
      'emptyLibrary': 'No books yet',
      'openReader': 'Open Reader',
      'highlights': 'Highlights',
      'highlightAction': 'Highlight',
      'importBook': 'Import Book',
      'importingBook': 'Importing book...',
      'importDone': 'Import finished',
      'searchComingSoon': 'Search coming soon',
      'menuComingSoon': 'Menu coming soon',
      'myLibrary': 'MY LIBRARY',
      'nowReading': 'NOW READING',
      'yourCollection': 'YOUR COLLECTION',
      'myHighlights': 'MY HIGHLIGHTS',
      'noHighlightsYet': 'No highlights yet',
      'emptyHighlight': 'Untitled highlight',
      'viewAll': 'VIEW ALL',
      'continueReading': 'CONTINUE',
      'pageLabel': 'Page {page}',
      'bookNotFound': 'Book not found',
      'bookProfileSettings': 'Book settings',
      'deleteBook': 'Delete book',
      'deleteBookConfirmTitle': 'Delete this book?',
      'deleteBookConfirmMessage':
          'This will remove the book, chapters, progress, and highlights from this app.',
      'deleteBookFailed': 'Delete failed',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'readerChapterList': 'Chapters',
      'readerSearchBook': 'Search this book',
      'readerCurrentRead': 'Current reading',
      'readerCurrentReadProgress': 'Current reading {current}/{total}',
      'readerAddBookmark': 'Add bookmark',
      'readerDownloadDone': 'Download done',
      'readerAutoFlip': 'Auto flip',
      'readerGlobalSearch': 'Global search',
      'readerOpenNotes': 'View notes',
      'readerBookThoughts': 'Book thoughts',
    },
    'zh': <String, String>{
      'appTitle': 'Uni Reader',
      'libraryTitle': '书架',
      'emptyLibrary': '暂无书籍',
      'openReader': '开始阅读',
      'highlights': '划线',
      'highlightAction': '标注',
      'importBook': '导入书籍',
      'importingBook': '正在导入书籍...',
      'importDone': '导入完成',
      'searchComingSoon': '搜索功能开发中',
      'menuComingSoon': '菜单功能开发中',
      'myLibrary': '我的书库',
      'nowReading': '正在阅读',
      'yourCollection': '馆藏书目',
      'myHighlights': '我的划线',
      'noHighlightsYet': '还没有划线',
      'emptyHighlight': '未命名划线',
      'viewAll': '查看全部',
      'continueReading': '继续阅读',
      'pageLabel': '第 {page} 页',
      'bookNotFound': '未找到该书籍',
      'bookProfileSettings': '图书设置',
      'deleteBook': '删除图书',
      'deleteBookConfirmTitle': '删除这本书？',
      'deleteBookConfirmMessage': '这会从本应用中删除该书及其章节、阅读进度和划线。',
      'deleteBookFailed': '删除失败',
      'cancel': '取消',
      'delete': '删除',
      'readerChapterList': '章节列表',
      'readerSearchBook': '搜本书',
      'readerCurrentRead': '当前读到',
      'readerCurrentReadProgress': '当前读到 {current}/{total}',
      'readerAddBookmark': '添加书签',
      'readerDownloadDone': '下载完成',
      'readerAutoFlip': '开启自动翻页',
      'readerGlobalSearch': '全文搜索',
      'readerOpenNotes': '查看笔记',
      'readerBookThoughts': '书友想法',
    },
  };

  String tr(String key) {
    final lang = _strings[locale.languageCode] ?? _strings['en']!;
    return lang[key] ?? _strings['en']![key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>{'en', 'zh'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
