import 'package:flutter_test/flutter_test.dart';
import 'package:icueadmin/models/assigned_entities.dart';

void main() {
  group('AssignedEntities JSON parsing', () {
    test('parses valid JSON response with classes and sections', () {
      final json = {
        'err': false,
        'message': 'Success',
        'data': [
          {
            'Classes': [
              {
                'ClassId': 101,
                'Standard': 'Grade 10',
                'StandardType': 'STUDENT',
                'Sections': ['A', 'B'],
              },
            ],
          },
        ],
      };

      final result = AssignedEntities.fromJson(json);
      expect(result.err, isFalse);
      expect(result.message, equals('Success'));
      expect(result.data, isNotNull);
      expect(result.data!.length, equals(1));
      expect(result.data!.first.classes.length, equals(1));
      final entityClass = result.data!.first.classes.first;
      expect(entityClass.classId, equals(101));
      expect(entityClass.standard, equals('Grade 10'));
      expect(entityClass.standardType, equals('STUDENT'));
      expect(entityClass.sections, equals(['A', 'B']));
    });

    test('handles empty string "" for Classes without crashing', () {
      final json = {
        'err': false,
        'message': 'Success',
        'data': [
          {'Classes': ''},
        ],
      };

      final result = AssignedEntities.fromJson(json);
      expect(result.data, isNotNull);
      expect(result.data!.first.classes, isEmpty);
    });

    test('handles null or invalid types for data, Classes, and Sections', () {
      final json = {
        'err': null,
        'message': null,
        'data': [
          {'Classes': null},
          {
            'Classes': [
              {
                'ClassId': null,
                'Standard': null,
                'StandardType': null,
                'Sections': '',
              },
            ],
          },
        ],
      };

      final result = AssignedEntities.fromJson(json);
      expect(result.err, isFalse);
      expect(result.message, equals(''));
      expect(result.data!.length, equals(2));
      expect(result.data![0].classes, isEmpty);

      final entityClass = result.data![1].classes.first;
      expect(entityClass.classId, equals(0));
      expect(entityClass.standard, equals(''));
      expect(entityClass.sections, isEmpty);
    });
  });
}
