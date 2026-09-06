import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/formats.dart';

void main() {
  group('MÓDULO 1: Sanitización y Formatters Numéricos en Flutter', () {
    final formatter = kDecimalInputFormatters.first;

    test('Físicamente limita la entrada a números con máximo 2 decimales', () {
      var val = const TextEditingValue(text: '');

      // Entrada secuencial de 1.50
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1', selection: TextSelection.collapsed(offset: 1)));
      expect(val.text, '1');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1.', selection: TextSelection.collapsed(offset: 2)));
      expect(val.text, '1.');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1.5', selection: TextSelection.collapsed(offset: 3)));
      expect(val.text, '1.5');

      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1.50', selection: TextSelection.collapsed(offset: 4)));
      expect(val.text, '1.50');

      // Intento de ingresar un tercer decimal (ej. 1.505) -> Bloqueado a 1.50
      val = formatter.formatEditUpdate(val, const TextEditingValue(text: '1.505', selection: TextSelection.collapsed(offset: 5)));
      expect(val.text, '1.50');
    });

    test('Impide físicamente la entrada de datos microscópicos como 0.000004', () {
      const val = TextEditingValue(text: '');
      final updated = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '0.000004', selection: TextSelection.collapsed(offset: 8)),
      );
      expect(updated.text, '0.00');
    });

    test('Rechaza caracteres alfanuméricos y signos negativos', () {
      const val = TextEditingValue(text: '');
      final resAlpha = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: 'abc12', selection: TextSelection.collapsed(offset: 5)),
      );
      expect(resAlpha.text, '');

      final resNeg = formatter.formatEditUpdate(
        val,
        const TextEditingValue(text: '-5.0', selection: TextSelection.collapsed(offset: 4)),
      );
      expect(resNeg.text, '');
    });
  });

  group('MÓDULO 1 & 2: Validadores de Formulario (Form Validators)', () {
    test('validateWeightKg: Regla de Bloqueo de Ceros y Umbral Mínimo 0.5 kg', () {
      expect(validateWeightKg(''), 'Ingresa el peso en kg');
      expect(validateWeightKg(null), 'Ingresa el peso en kg');
      expect(validateWeightKg('0'), 'El valor debe ser mayor a 0');
      expect(validateWeightKg('0.00'), 'El valor debe ser mayor a 0');
      expect(validateWeightKg('0.2'), 'El peso mínimo aceptado es 0.5 kg');
      expect(validateWeightKg('0.49'), 'El peso mínimo aceptado es 0.5 kg');
      expect(validateWeightKg('0.000004'), 'El peso mínimo aceptado es 0.5 kg');

      // Valores válidos
      expect(validateWeightKg('0.5'), isNull);
      expect(validateWeightKg('1.50'), isNull);
      expect(validateWeightKg('10'), isNull);
    });

    test('validateAmount: Regla de Bloqueo de Ceros y Umbral Mínimo 0.10 ECO / PEN', () {
      expect(validateAmount(''), 'Ingresa el monto');
      expect(validateAmount(null), 'Ingresa el monto');
      expect(validateAmount('0'), 'El monto debe ser mayor a 0');
      expect(validateAmount('0.00'), 'El monto debe ser mayor a 0');
      expect(validateAmount('0.05'), 'El monto mínimo es 0.10 ECO');
      expect(validateAmount('0.09'), 'El monto mínimo es 0.10 ECO');

      // Valores válidos
      expect(validateAmount('0.10'), isNull);
      expect(validateAmount('5.00'), isNull);
      expect(validateAmount('20'), isNull);
    });
  });
}
