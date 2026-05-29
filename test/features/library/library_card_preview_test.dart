import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/components/library/library_page.dart';
import 'package:study_assistant_app/models/document.dart';
import 'package:study_assistant_app/models/mindmap_library.dart';
import 'package:study_assistant_app/models/subject.dart';
import 'package:study_assistant_app/providers/document_provider.dart';
import 'package:study_assistant_app/providers/library_provider.dart';

Future<void> _loadChineseFont() async {
  final loader = FontLoader('Noto Sans SC')
    ..addFont(
      rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'),
    );
  await loader.load();
}

class _MockSchoolSubjectsNotifier extends SchoolSubjectsNotifier {
  @override
  Future<List<SubjectWithProgress>> build() async => [
        SubjectWithProgress(
          subject: Subject(
            id: 1,
            name: '高等数学',
            category: '理工科',
            description: '微积分、线性代数基础',
            colorIndex: 1,
            createdAt: DateTime(2025, 9, 12),
          ),
          totalNodes: 34,
          litNodes: 12,
          sessionCount: 2,
          lastVisitedAt: DateTime(2026, 5, 20),
        ),
      ];
}

Future<void> _pumpLibraryCard(WidgetTester tester, {bool expanded = false}) async {
  await tester.binding.setSurfaceSize(const Size(420, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        schoolSubjectsProvider.overrideWith(_MockSchoolSubjectsNotifier.new),
        subjectKnowledgeBaseProvider.overrideWith(
          (ref, subjectId) async => SubjectKnowledgeBase(
            subjectId: 1,
            status: 'ready',
            documentCount: 3,
            chunkCount: 128,
            mindmapReady: true,
            updatedAt: DateTime(2026, 5, 18),
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
          useMaterial3: true,
          fontFamily: 'Noto Sans SC',
        ),
        home: const RepaintBoundary(
          key: Key('library_preview'),
          child: LibraryPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (expanded) {
    await tester.tap(find.text('详细'));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadChineseFont();
  });

  testWidgets('library card preview — collapsed', (tester) async {
    await _pumpLibraryCard(tester);
    await expectLater(
      find.byKey(const Key('library_preview')),
      matchesGoldenFile('goldens/library_card_gaodengshuxue_collapsed.png'),
    );
  });

  testWidgets('library card preview — detail expanded', (tester) async {
    await _pumpLibraryCard(tester, expanded: true);
    await expectLater(
      find.byKey(const Key('library_preview')),
      matchesGoldenFile('goldens/library_card_gaodengshuxue_expanded.png'),
    );
  });
}
