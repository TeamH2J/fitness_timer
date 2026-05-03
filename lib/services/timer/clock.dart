abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  DateTime _now;

  FakeClock(this._now);

  void advance(Duration d) => _now = _now.add(d);

  void setNow(DateTime t) => _now = t;

  @override
  DateTime now() => _now;
}
