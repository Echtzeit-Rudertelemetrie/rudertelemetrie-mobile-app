import 'package:flutter_test/flutter_test.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/dashboard_layout_engine.dart';
import 'package:rudertelemetrie_mobile_app/dashboard/widget_config.dart';

void main() {
  const engine = DashboardLayoutEngine(cols: 4, rows: 6);

  WidgetConfig w(String id, int x, int y, int w, int h) =>
      WidgetConfig(id: id, x: x, y: y, w: w, h: h, type: 'test');

  // ---------------------------------------------------------------------------
  // collides
  // ---------------------------------------------------------------------------
  group('collides', () {
    test('overlapping items collide', () {
      expect(engine.collides(w('a', 0, 0, 2, 2), w('b', 1, 1, 2, 2)), isTrue);
    });

    test('horizontally adjacent items do not collide', () {
      expect(engine.collides(w('a', 0, 0, 2, 2), w('b', 2, 0, 2, 2)), isFalse);
    });

    test('vertically adjacent items do not collide', () {
      expect(engine.collides(w('a', 0, 0, 2, 2), w('b', 0, 2, 2, 2)), isFalse);
    });

    test('same-id item never collides with itself', () {
      final a = w('a', 0, 0, 2, 2);
      expect(engine.collides(a, a), isFalse);
    });

    test('touching corner does not collide', () {
      expect(engine.collides(w('a', 0, 0, 1, 1), w('b', 1, 1, 1, 1)), isFalse);
    });

    test('full overlap collides', () {
      expect(engine.collides(w('a', 1, 1, 2, 2), w('b', 1, 1, 2, 2)), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // getAllCollisions
  // ---------------------------------------------------------------------------
  group('getAllCollisions', () {
    test('returns empty when no overlaps', () {
      final layout = [w('a', 0, 0, 2, 2), w('b', 2, 0, 2, 2)];
      expect(engine.getAllCollisions(layout, w('a', 0, 0, 2, 2)), isEmpty);
    });

    test('returns colliding item', () {
      final layout = [w('a', 0, 0, 2, 2), w('b', 1, 0, 2, 2)];
      final collisions = engine.getAllCollisions(layout, w('a', 0, 0, 2, 2));
      expect(collisions.map((e) => e.id), contains('b'));
    });

    test('result sorted by (y, x)', () {
      final layout = [
        w('a', 0, 0, 4, 4),
        w('b', 2, 0, 2, 2),
        w('c', 0, 2, 2, 2),
      ];
      final collisions = engine.getAllCollisions(
        layout,
        w('a', 0, 0, 4, 4),
      );
      // b is at y=0,x=2; c is at y=2,x=0 → b should come first
      expect(collisions[0].id, 'b');
      expect(collisions[1].id, 'c');
    });
  });

  // ---------------------------------------------------------------------------
  // compact
  // ---------------------------------------------------------------------------
  group('compact', () {
    test('moves item at y=3 to y=0 when nothing is below it', () {
      final layout = [w('a', 0, 3, 2, 2)];
      final result = engine.compact(layout);
      expect(result.first.y, 0);
    });

    test('stacks two items without gap', () {
      final layout = [w('a', 0, 0, 2, 2), w('b', 0, 5, 2, 1)];
      final result = engine.compact(layout);
      final a = result.firstWhere((e) => e.id == 'a');
      final b = result.firstWhere((e) => e.id == 'b');
      expect(a.y, 0);
      expect(b.y, a.y + a.h); // stacked immediately below
    });

    test('side-by-side items both go to y=0', () {
      final layout = [w('a', 0, 2, 2, 2), w('b', 2, 2, 2, 2)];
      final result = engine.compact(layout);
      expect(result.every((e) => e.y == 0), isTrue);
    });

    test('preserves x positions', () {
      final layout = [w('a', 1, 3, 1, 1)];
      final result = engine.compact(layout);
      expect(result.first.x, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // moveElement
  // ---------------------------------------------------------------------------
  group('moveElement', () {
    test('moves item to empty space', () {
      final layout = [w('a', 0, 0, 2, 2)];
      final result = engine.moveElement(layout, 'a', 2, 0);
      final a = result.firstWhere((e) => e.id == 'a');
      expect(a.x, 2);
      expect(a.y, 0);
    });

    test('pushes colliding item down', () {
      // 'a' is at (2,0); moving it to (0,0) where 'b' already sits → 'b' must move down
      final layout = [w('a', 2, 0, 2, 2), w('b', 0, 0, 2, 2)];
      final result = engine.moveElement(layout, 'a', 0, 0);
      final a = result.firstWhere((e) => e.id == 'a');
      final b = result.firstWhere((e) => e.id == 'b');
      expect(engine.collides(a, b), isFalse);
    });

    test('cascading push: chain of three items', () {
      final layout = [
        w('a', 0, 0, 2, 2),
        w('b', 0, 2, 2, 2),
        w('c', 0, 4, 2, 1),
      ];
      // move 'a' down by 1, pushing b and then c down
      final result = engine.moveElement(layout, 'a', 0, 1);
      for (var i = 0; i < result.length - 1; i++) {
        for (var j = i + 1; j < result.length; j++) {
          expect(engine.collides(result[i], result[j]), isFalse,
              reason: '${result[i].id} and ${result[j].id} should not collide');
        }
      }
    });

    test('no-op when target equals current position', () {
      final layout = [w('a', 1, 1, 2, 2)];
      final result = engine.moveElement(layout, 'a', 1, 1);
      expect(result, equals(layout));
    });

    test('clamps x to grid bounds', () {
      final layout = [w('a', 0, 0, 2, 2)];
      final result = engine.moveElement(layout, 'a', 99, 0);
      expect(result.first.x, lessThanOrEqualTo(engine.cols - 2));
    });

    test('clamps y to grid bounds', () {
      final layout = [w('a', 0, 0, 2, 2)];
      final result = engine.moveElement(layout, 'a', 0, 99);
      expect(result.first.y, lessThanOrEqualTo(engine.rows - 2));
    });
  });

  // ---------------------------------------------------------------------------
  // resizeElement
  // ---------------------------------------------------------------------------
  group('resizeElement', () {
    test('grows width', () {
      final layout = [w('a', 0, 0, 1, 1)];
      final result = engine.resizeElement(layout, 'a', 3, 1);
      expect(result.first.w, 3);
    });

    test('clamps width to not exceed grid', () {
      final layout = [w('a', 2, 0, 1, 1)];
      final result = engine.resizeElement(layout, 'a', 99, 1);
      expect(result.first.w, engine.cols - 2); // 4 - 2 = 2
    });

    test('pushes colliding item down on resize', () {
      final layout = [w('a', 0, 0, 2, 1), w('b', 0, 1, 2, 2)];
      final result = engine.resizeElement(layout, 'a', 2, 2);
      final a = result.firstWhere((e) => e.id == 'a');
      final b = result.firstWhere((e) => e.id == 'b');
      expect(engine.collides(a, b), isFalse);
    });

    test('minimum size is 1×1', () {
      final layout = [w('a', 0, 0, 3, 3)];
      final result = engine.resizeElement(layout, 'a', 0, 0);
      expect(result.first.w, 1);
      expect(result.first.h, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // addWidget / removeWidget
  // ---------------------------------------------------------------------------
  group('addWidget', () {
    test('places widget at first free slot', () {
      final layout = [w('a', 0, 0, 2, 2)];
      final result = engine.addWidget(layout, w('b', 0, 0, 2, 2));
      final a = result.firstWhere((e) => e.id == 'a');
      final b = result.firstWhere((e) => e.id == 'b');
      expect(engine.collides(a, b), isFalse);
    });

    test('adds to empty layout at (0,0)', () {
      final result = engine.addWidget([], w('a', 0, 0, 2, 2));
      expect(result.first.x, 0);
      expect(result.first.y, 0);
    });
  });

  group('removeWidget', () {
    test('removes item by id', () {
      final layout = [w('a', 0, 0, 2, 2), w('b', 2, 0, 2, 2)];
      final result = engine.removeWidget(layout, 'a');
      expect(result.any((e) => e.id == 'a'), isFalse);
      expect(result.any((e) => e.id == 'b'), isTrue);
    });

    test('preserves position of remaining items after removal', () {
      final layout = [w('a', 0, 0, 2, 2), w('b', 0, 3, 2, 2)];
      final result = engine.removeWidget(layout, 'a');
      final b = result.firstWhere((e) => e.id == 'b');
      expect(b.y, 3); // free placement: gap is kept, 'b' stays in place
    });
  });

  // ---------------------------------------------------------------------------
  // clampPosition
  // ---------------------------------------------------------------------------
  group('clampPosition', () {
    test('does not go negative', () {
      final (x, y) = engine.clampPosition(-5, -3, 2, 2);
      expect(x, 0);
      expect(y, 0);
    });

    test('stays within right/bottom edge', () {
      final (x, y) = engine.clampPosition(10, 10, 2, 2);
      expect(x, engine.cols - 2);
      expect(y, engine.rows - 2);
    });

    test('valid position unchanged', () {
      final (x, y) = engine.clampPosition(1, 1, 2, 2);
      expect(x, 1);
      expect(y, 1);
    });
  });
}
