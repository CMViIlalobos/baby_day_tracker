import 'package:flutter_test/flutter_test.dart';

import 'package:baby_day_tracker/models/event.dart';

void main() {
  test('event serialization preserves type and metadata', () {
    final event = BabyEvent(
      id: 1,
      type: EventType.feeding,
      timestamp: DateTime(2026, 4, 20, 9, 30),
      notes: 'Morning feed',
      feedingDuration: 20,
      feedingSide: 'Left',
    );

    final roundTrip = BabyEvent.fromMap(event.toMap());

    expect(roundTrip.id, 1);
    expect(roundTrip.type, EventType.feeding);
    expect(roundTrip.feedingDuration, 20);
    expect(roundTrip.feedingSide, 'Left');
    expect(roundTrip.notes, 'Morning feed');
  });
}
