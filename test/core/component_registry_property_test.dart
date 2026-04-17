// Feature: learning-os-architecture
// Property 9: ComponentInterface 实现不完整时注册被拒绝
// Property 10: 未注册组件返回错误而非异常
//
// 使用 flutter_test + 随机数据生成模拟属性测试，每个属性运行 100 次迭代。

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_assistant_app/core/component/component_interface.dart';
import 'package:study_assistant_app/core/component/component_registry.dart';
import 'package:study_assistant_app/core/component/component_registry_impl.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

final _rng = Random(42);

String _randomId([int length = 8]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
}

ComponentMeta _randomMeta(String id) => ComponentMeta(
      id: id,
      name: 'Component_$id',
      version: '1.0.0',
      supportedDataTypes: const ['data'],
      isBuiltin: false,
    );

/// A fully compliant ComponentInterface implementation.
class _ValidComponent implements ComponentInterface {
  @override
  Future<void> open(ComponentContext context) async {}

  @override
  Future<void> write(ComponentData data) async {}

  @override
  Future<ComponentData> read(ComponentQuery query) async => ComponentData(
        componentId: 'test',
        dataType: 'test',
        payload: const {},
      );

  @override
  Future<void> close() async {}
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Property 9 ──────────────────────────────────────────────────────────────
  // For any fully-compliant ComponentInterface implementation, registration
  // must succeed and the component must appear in listAll().
  group('Property 9: valid components are accepted and appear in listAll()', () {
    test('runs 100 iterations with random component IDs', () {
      // Feature: learning-os-architecture, Property 9: ComponentInterface 实现完整时注册成功
      for (var i = 0; i < 100; i++) {
        final registry = ComponentRegistryImpl();
        final id = _randomId();
        final meta = _randomMeta(id);

        // Should not throw.
        expect(
          () => registry.register(_ValidComponent(), meta),
          returnsNormally,
          reason: 'Valid component should be registered without error (iteration $i)',
        );

        // Must appear in listAll().
        final all = registry.listAll();
        expect(
          all.any((m) => m.id == id),
          isTrue,
          reason: 'Registered component "$id" must appear in listAll() (iteration $i)',
        );
      }
    });
  });

  // ── Property 10 ─────────────────────────────────────────────────────────────
  // For any unregistered component ID, get() must return a Result.err with
  // ComponentNotFoundError — never throw an unhandled exception.
  group('Property 10: unregistered component IDs return error, not exception', () {
    test('runs 100 iterations with random unregistered IDs', () {
      // Feature: learning-os-architecture, Property 10: 未注册组件返回错误而非异常
      final registry = ComponentRegistryImpl();

      for (var i = 0; i < 100; i++) {
        final id = 'unregistered_${_randomId()}';

        // Must not throw.
        late Result<ComponentInterface> result;
        expect(
          () { result = registry.get(id); },
          returnsNormally,
          reason: 'get() must not throw for unregistered ID "$id" (iteration $i)',
        );

        // Must be an error result.
        expect(
          result.isOk,
          isFalse,
          reason: 'Result must be an error for unregistered ID "$id" (iteration $i)',
        );

        // Error must be ComponentNotFoundError containing the component ID.
        expect(
          result.error,
          isA<ComponentNotFoundError>(),
          reason: 'Error must be ComponentNotFoundError (iteration $i)',
        );

        final notFound = result.error as ComponentNotFoundError;
        expect(
          notFound.componentId,
          equals(id),
          reason: 'ComponentNotFoundError must contain the queried ID (iteration $i)',
        );
      }
    });

    test('get() on empty registry always returns ComponentNotFoundError', () {
      // Feature: learning-os-architecture, Property 10: 空注册表查询返回错误
      final registry = ComponentRegistryImpl();
      for (var i = 0; i < 100; i++) {
        final id = _randomId();
        final result = registry.get(id);
        expect(result.isOk, isFalse);
        expect(result.error, isA<ComponentNotFoundError>());
      }
    });
  });

  // ── Integration: register then get ──────────────────────────────────────────
  group('register → get round-trip', () {
    test('registered component is retrievable by ID (100 iterations)', () {
      for (var i = 0; i < 100; i++) {
        final registry = ComponentRegistryImpl();
        final id = _randomId();
        final meta = _randomMeta(id);
        final component = _ValidComponent();

        registry.register(component, meta);

        final result = registry.get(id);
        expect(result.isOk, isTrue, reason: 'Should find registered component (iteration $i)');
        expect(result.value, same(component), reason: 'Should return the exact registered instance (iteration $i)');
      }
    });
  });

  // ── createDefaultRegistry smoke test ────────────────────────────────────────
  group('createDefaultRegistry()', () {
    test('registers exactly 6 built-in components', () {
      final registry = createDefaultRegistry();
      final all = registry.listAll();
      expect(all.length, equals(6));
      expect(all.every((m) => m.isBuiltin), isTrue);
    });

    test('all 6 built-in component IDs are retrievable', () {
      final registry = createDefaultRegistry();
      const ids = ['chat', 'solve', 'mindmap', 'quiz', 'notebook', 'mistake_book'];
      for (final id in ids) {
        final result = registry.get(id);
        expect(result.isOk, isTrue, reason: 'Built-in component "$id" must be registered');
      }
    });
  });
}
