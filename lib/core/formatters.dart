import 'package:intl/intl.dart';

final _compact = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 1);
final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _int = NumberFormat.decimalPattern();
final _date = DateFormat.yMMMd();
final _dateTime = DateFormat('MMM d, y · HH:mm');
final _dateTimeUtc = DateFormat('yyyy-MM-dd HH:mm \'UTC\'');

String money(double v) => _currency.format(v);
String moneyCompact(double v) => _compact.format(v);
String count(num v) => _int.format(v);
String date(DateTime d) => _date.format(d);
String dateTime(DateTime d) => _dateTime.format(d);
String dateTimeUtc(DateTime d) => _dateTimeUtc.format(d.toUtc());
String lift(double v) => v >= 10 ? '${v.round()}x' : '${v.toStringAsFixed(1)}x';
