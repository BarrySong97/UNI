class DateTimeUtils {
  static int toMillis(DateTime value) => value.millisecondsSinceEpoch;

  static DateTime fromMillis(int value) => DateTime.fromMillisecondsSinceEpoch(value);
}
