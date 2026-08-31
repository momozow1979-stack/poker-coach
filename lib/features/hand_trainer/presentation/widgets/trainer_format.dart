/// BB 表記を「5.5」「20」のように、無駄な小数を出さずに整える。
String formatBb(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
