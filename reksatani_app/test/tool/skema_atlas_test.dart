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

  group('bedaSelainGradeTanpaKualitas', () {
    Map<String, dynamic> skema(Map<String, dynamic> validator) => {
          'koleksi': 'transaksi',
          'validator': validator,
          'validationLevel': null,
          'validationAction': null,
        };

    test('grade "-" di akhir enum: tidak ada beda lain', () {
      final sesudah = skema(tambahGradeTanpaKualitas(validator()));

      expect(bedaSelainGradeTanpaKualitas(skema(validator()), sesudah), isEmpty);
    });

    test('grade "-" di posisi lain juga diterima', () {
      final v = validator();
      v[r'$jsonSchema']['properties']['grade_terpilih']['enum'] = ['-', 'A', 'B', 'C'];

      expect(bedaSelainGradeTanpaKualitas(skema(validator()), skema(v)), isEmpty);
    });

    test('enum tanpa "-" dilaporkan', () {
      expect(
        bedaSelainGradeTanpaKualitas(skema(validator()), skema(validator())),
        [contains('tidak memuat "-"')],
      );
    });

    test('perubahan lain di luar enum dilaporkan', () {
      final v = tambahGradeTanpaKualitas(validator());
      v[r'$jsonSchema']['properties']['berat'] = {'minimum': 1};
      final s = skema(v)..['validationAction'] = 'warn';

      expect(bedaSelainGradeTanpaKualitas(skema(validator()), s), [
        contains('berat.minimum'),
        contains('validationAction'),
      ]);
    });

    test('grade lain ikut ditambahkan: dilaporkan', () {
      final v = tambahGradeTanpaKualitas(validator());
      (v[r'$jsonSchema']['properties']['grade_terpilih']['enum'] as List).add('D');

      expect(
        bedaSelainGradeTanpaKualitas(skema(validator()), skema(v)),
        [contains('grade_terpilih.enum')],
      );
    });

    test('null dan bawaan strict/error setara, ke dua arah', () {
      final sesudah = skema(tambahGradeTanpaKualitas(validator()))
        ..['validationLevel'] = 'strict'
        ..['validationAction'] = 'error';

      expect(bedaSelainGradeTanpaKualitas(skema(validator()), sesudah), isEmpty);
      final sebelum = skema(validator())
        ..['validationLevel'] = 'strict'
        ..['validationAction'] = 'error';
      expect(
        bedaSelainGradeTanpaKualitas(
            sebelum, skema(tambahGradeTanpaKualitas(validator()))),
        isEmpty,
      );
    });

    test('level atau aksi selain bawaan tetap dilaporkan', () {
      final sesudah = skema(tambahGradeTanpaKualitas(validator()))
        ..['validationLevel'] = 'moderate'
        ..['validationAction'] = 'warn';

      expect(bedaSelainGradeTanpaKualitas(skema(validator()), sesudah), [
        contains('validationLevel'),
        contains('validationAction'),
      ]);
    });

    test('tidak mengubah skema yang dibandingkan', () {
      final sesudah = skema(tambahGradeTanpaKualitas(validator()));
      bedaSelainGradeTanpaKualitas(skema(validator()), sesudah);

      expect(
        sesudah['validator'][r'$jsonSchema']['properties']['grade_terpilih']['enum'],
        ['A', 'B', 'C', '-'],
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
