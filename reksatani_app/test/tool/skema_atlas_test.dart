import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/atlas/atlas_ops.dart';

void main() {
  Map<String, dynamic> validator() => {
        r'$jsonSchema': {
          'bsonType': 'object',
          'required': ['grade_terpilih'],
          'properties': {
            'grade_terpilih': {
              'bsonType': 'string',
              'enum': ['A', 'B', 'C'],
            },
            'status_sinkronisasi': {
              'enum': ['pending', 'synced'],
            },
            'berat': {'minimum': 0},
          },
        },
      };

  group('tambahGradeTanpaKualitas', () {
    test('hanya enum grade_terpilih yang berubah', () {
      final lama = validator();
      final baru = tambahGradeTanpaKualitas(lama);

      expect(bedaSkema(lama, baru), [
        contains('grade_terpilih.enum'),
      ]);
      final enumBaru = baru[r'$jsonSchema']['properties']['grade_terpilih']['enum'];
      expect(enumBaru, ['A', 'B', 'C', '-']);
    });

    test('tidak mengubah validator asalnya', () {
      final lama = validator();
      tambahGradeTanpaKualitas(lama);

      expect(bedaSkema(lama, validator()), isEmpty);
    });

    test('dijalankan dua kali hasilnya sama', () {
      final sekali = tambahGradeTanpaKualitas(validator());

      expect(bedaSkema(sekali, tambahGradeTanpaKualitas(sekali)), isEmpty);
    });

    test('validator tanpa enum grade_terpilih ditolak', () {
      expect(
        () => tambahGradeTanpaKualitas({r'$jsonSchema': <String, dynamic>{}}),
        throwsStateError,
      );
    });
  });

  group('bedaSkema', () {
    test('angka tetap sama jenisnya sesudah melewati JSON', () {
      final asli = {'a': 0, 'b': 0.5, 'c': 1.0};

      expect(bedaSkema(asli, jsonDecode(jsonEncode(asli))), isEmpty);
    });

    test('int dan double dianggap berbeda', () {
      expect(bedaSkema({'minimum': 0}, {'minimum': 0.0}), hasLength(1));
    });

    test('urutan kunci dan urutan enum ikut dihitung', () {
      expect(bedaSkema({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), hasLength(1));
      expect(bedaSkema(['A', 'B'], ['B', 'A']), hasLength(2));
    });
  });

  test('skemaDariInfo membaca validator koleksi yang diminta', () {
    final infos = [
      {
        'name': 'petani',
        'options': {'validator': 1},
      },
      {
        'name': 'transaksi',
        'options': {'validator': 2, 'validationLevel': 'strict'},
      },
    ];

    final skema = skemaDariInfo(infos, 'transaksi');

    expect(skema['validator'], 2);
    expect(skema['validationLevel'], 'strict');
    expect(() => skemaDariInfo(infos, 'tidak-ada'), throwsStateError);
  });
}
