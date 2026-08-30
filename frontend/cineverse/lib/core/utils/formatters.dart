import 'package:intl/intl.dart';

/// Conversão de exibição para dinheiro e data. Tudo em centavos inteiros
/// (`priceCents`) e `DateTime` chega ao app já convertido pelo repositório —
/// aqui só formata para pt_BR (ver CLAUDE.md § Dinheiro / § Datas).
class Formatters {
  const Formatters._();

  static final _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
  );
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _time = DateFormat('HH:mm', 'pt_BR');

  static String money(int cents) => _currency.format(cents / 100);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String date(DateTime value) => _date.format(value);

  static String time(DateTime value) => _time.format(value);
}
