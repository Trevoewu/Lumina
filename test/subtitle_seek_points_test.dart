import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/widgets/subtitle_seek_points.dart';

void main() {
  test('line transport steps from current line and clamps at boundaries', () {
    const points = [0, 1200, 8000, 19000, 35000];
    expect(stepSubtitleStart(points, 9000, -1), 1200);
    expect(stepSubtitleStart(points, 8000, -1), 1200);
    expect(stepSubtitleStart(points, 1800, 3), 35000);
    expect(stepSubtitleStart(points, 36000, 3), 35000);
    expect(stepSubtitleStart(points, 0, -1), 0);
    expect(stepSubtitleStart([], 9000, 3), isNull);
  });
  test('snaps to nearest irregular subtitle start in both directions', () {
    const points = [1200, 5200, 17000, 34000];
    expect(nearestSubtitleStart(points, 0), 1200);
    expect(nearestSubtitleStart(points, 4000), 5200);
    expect(nearestSubtitleStart(points, 13000), 17000);
    expect(nearestSubtitleStart(points, 8000), 5200);
    expect(nearestSubtitleStart(points, 25500), 17000);
    expect(nearestSubtitleStart(points, 99999), 34000);
    expect(nearestSubtitleStart([], 7250), 7250);
  });
}
