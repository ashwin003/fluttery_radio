import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttery_radio/widgets/player/visualizer.dart';

void main() {
  Future<void> pumpVisualizer(
    WidgetTester tester, {
    required bool active,
    Stream<Float32List>? spectrum,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          height: 72,
          child: Visualizer(active: active, spectrum: spectrum),
        ),
      ),
    ),
  );

  testWidgets('shows the sync mark only while spectrum data arrives', (
    tester,
  ) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    await pumpVisualizer(tester, active: true, spectrum: spectrum.stream);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.graphic_eq), findsNothing);

    // Feed packets every frame for a second.
    for (var i = 0; i < 60; i++) {
      spectrum.add(Float32List(128)..fillRange(0, 128, 0.7));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);

    // Data stops: blends back to the decorative animation.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.graphic_eq), findsNothing);
  });

  testWidgets('stops listening to the spectrum when inactive', (tester) async {
    final spectrum = StreamController<Float32List>.broadcast();
    addTearDown(spectrum.close);
    await pumpVisualizer(tester, active: true, spectrum: spectrum.stream);
    expect(spectrum.hasListener, isTrue);

    await pumpVisualizer(tester, active: false, spectrum: spectrum.stream);
    expect(spectrum.hasListener, isFalse);
    await tester.pumpAndSettle();
  });
}
