// Generates Dart and TypeScript contracts from contracts/*.yaml.
//   dart run tool/gen_contracts.dart          write the generated files
//   dart run tool/gen_contracts.dart --check  exit 1 if they are stale
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'contract_models.dart';

const _dartOut = 'packages/icue_firebase/lib/src/contracts.g.dart';
const _tsOut = 'firebase/functions/src/shared/contracts.ts';
const _primitives = {'string', 'int', 'double', 'bool', 'timestamp'};

void main(List<String> args) {
  final files =
      Directory('contracts')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final roots = <YamlMap>[];
  final collections = <String>[];
  final enums = <String, _Enum>{};
  final constants = <String, _Constant>{};
  final documents = <String, _Document>{};

  void add<T>(Map<String, T> into, String name, T value) {
    if (into.containsKey(name)) _fail('Duplicate "$name"');
    into[name] = value;
  }

  for (final file in files) {
    final root = loadYaml(file.readAsStringSync()) as YamlMap? ?? YamlMap();
    roots.add(root);
    for (final name in (root['collections'] as YamlList? ?? [])) {
      if (collections.contains(name)) _fail('Duplicate collection "$name"');
      collections.add('$name');
    }
    (root['enums'] as YamlMap? ?? YamlMap()).forEach((name, body) {
      add(enums, '$name', _Enum('$name', body as YamlMap));
    });
    (root['constants'] as YamlMap? ?? YamlMap()).forEach((name, body) {
      add(constants, '$name', _Constant('$name', body as YamlMap));
    });
    (root['documents'] as YamlMap? ?? YamlMap()).forEach((name, body) {
      add(documents, '$name', _Document('$name', body as YamlMap));
    });
  }

  for (final constant in constants.values) {
    final owner =
        enums[constant.enumName] ??
        _fail('${constant.name}: unknown enum "${constant.enumName}"');
    for (final value in constant.values) {
      if (!owner.values.contains(value)) {
        _fail('${constant.name}: "$value" is not in ${owner.name}');
      }
    }
  }
  for (final document in documents.values) {
    final collection = document.collection;
    if (collection != null && !collections.contains(collection)) {
      _fail('${document.name}: unknown collection "$collection"');
    }
    for (final field in document.fields) {
      final base = field.baseType;
      if (!_primitives.contains(base) &&
          !enums.containsKey(base) &&
          !documents.containsKey(base)) {
        _fail('${document.name}.${field.key}: unknown type "${field.type}"');
      }
    }
  }

  final documentKeys = {
    for (final document in documents.values)
      document.name: {for (final field in document.fields) field.key},
  };
  final generated = {
    _dartOut: formatDart(
      _dartOut,
      _dart(collections, enums, constants, documents),
    ),
    _tsOut: _ts(collections, enums, constants, documents),
  };
  for (final root in roots) {
    for (final MapEntry(:key, :value) in generateModels(
      root,
      documentKeys,
      enums.keys.toSet(),
    ).entries) {
      generated[key] = formatDart(key, value);
    }
  }
  if (args.contains('--check')) {
    final stale = [
      for (final MapEntry(:key, :value) in generated.entries)
        if (!File(key).existsSync() || File(key).readAsStringSync() != value)
          key,
    ];
    if (stale.isNotEmpty) {
      stderr.writeln(
        'Stale: ${stale.join(', ')}. Run `melos run gen:contracts`.',
      );
      exit(1);
    }
    return;
  }
  for (final MapEntry(:key, :value) in generated.entries) {
    File(key).writeAsStringSync(value);
  }
}

Never _fail(String message) {
  stderr.writeln('contracts: $message');
  exit(1);
}

const _reserved = {
  'new',
  'default',
  'class',
  'enum',
  'in',
  'is',
  'null',
  'true',
  'false',
};

/// `snake_case` to `camelCase`; a Dart reserved word gets a `Value` suffix (`new` -> `newValue`).
String _camel(String snake) {
  final name = snake.replaceAllMapped(
    RegExp('_([a-z0-9])'),
    (match) => match[1]!.toUpperCase(),
  );
  return _reserved.contains(name) ? '${name}Value' : name;
}

String _doc(String? text, [String indent = '']) => text == null
    ? ''
    : '${text.trim().split('\n').map((line) => '$indent/// $line').join('\n')}\n';

class _Enum {
  _Enum(this.name, YamlMap body)
    : doc = body['doc'] as String?,
      values = [for (final value in body['values'] as YamlList) '$value'];
  final String name;
  final String? doc;
  final List<String> values;
}

class _Constant {
  _Constant(this.name, YamlMap body)
    : doc = body['doc'] as String?,
      enumName = body['enum'] as String,
      values = [for (final value in body['values'] as YamlList) '$value'];
  final String name;
  final String? doc;
  final String enumName;
  final List<String> values;
}

class _Field {
  _Field(this.key, String declared)
    : optional = declared.endsWith('?'),
      type = declared.replaceFirst(RegExp(r'\?$'), '');
  final String key;
  final String type;
  final bool optional;

  /// `list<Line>` and `map<Line>` are checked by their element type.
  String get baseType =>
      RegExp(r'^(?:list|map)<(.+)>$').firstMatch(type)?[1] ?? type;

  String get ts {
    final base = switch (baseType) {
      'string' => 'string',
      'int' || 'double' => 'number',
      'bool' => 'boolean',
      'timestamp' => 'Timestamp',
      final other => other,
    };
    final full = switch (type.split('<').first) {
      'list' => '$base[]',
      'map' => 'Record<string, $base>',
      _ => base,
    };
    return optional ? '$full | null' : full;
  }
}

class _Document {
  _Document(this.name, YamlMap body)
    : doc = body['doc'] as String?,
      collection = body['collection'] as String?,
      fields = [
        for (final MapEntry(:key, :value)
            in (body['fields'] as YamlMap).entries)
          _Field('$key', '$value'),
      ];
  final String name;
  final String? doc;
  final String? collection;
  final List<_Field> fields;
}

const _header =
    'GENERATED by tool/gen_contracts.dart from contracts/*.yaml. Do not edit.';

String _dart(
  List<String> collections,
  Map<String, _Enum> enums,
  Map<String, _Constant> constants,
  Map<String, _Document> documents,
) {
  final out = StringBuffer('// $_header\n\n');
  if (collections.isNotEmpty) {
    out.writeln(
      '/// Collections under `orgs/{orgId}/zones/{zoneId}/branches/{branchId}/`.',
    );
    out.writeln('abstract final class Collections {');
    for (final name in collections) {
      out.writeln("  static const $name = '$name';");
    }
    out.writeln('}\n');
  }
  for (final item in enums.values) {
    out.write(_doc(item.doc));
    out.writeln('abstract final class ${item.name} {');
    for (final value in item.values) {
      out.writeln("  static const ${_camel(value)} = '$value';");
    }
    final names = item.values.map(_camel).join(', ');
    out.writeln('  static const values = [$names];');
    out.writeln('}\n');
  }
  for (final item in constants.values) {
    out.write(_doc(item.doc));
    final names = item.values
        .map((value) => '${item.enumName}.${_camel(value)}')
        .join(', ');
    out.writeln('const ${item.name} = [$names];\n');
  }
  for (final item in documents.values) {
    out.write(_doc(item.doc));
    out.writeln('abstract final class ${item.name}Fields {');
    for (final field in item.fields) {
      out.writeln("  static const ${field.key} = '${field.key}';");
    }
    out.writeln('}\n');
  }
  return '${out.toString().trimRight()}\n';
}

String _ts(
  List<String> collections,
  Map<String, _Enum> enums,
  Map<String, _Constant> constants,
  Map<String, _Document> documents,
) {
  final out = StringBuffer('// $_header\n\n');
  if (documents.values.any(
    (item) => item.fields.any((f) => f.baseType == 'timestamp'),
  )) {
    out.writeln("import type { Timestamp } from 'firebase-admin/firestore';\n");
  }
  if (collections.isNotEmpty) {
    out.writeln(
      '/** Collections under `orgs/{orgId}/zones/{zoneId}/branches/{branchId}/`. */',
    );
    out.writeln('export const Collections = {');
    for (final name in collections) {
      out.writeln("  $name: '$name',");
    }
    out.writeln('} as const;\n');
  }
  for (final item in enums.values) {
    out.write(_tsDoc(item.doc));
    out.writeln('export const ${item.name} = {');
    for (final value in item.values) {
      out.writeln("  ${_camel(value)}: '$value',");
    }
    out.writeln('} as const;');
    out.writeln(
      'export type ${item.name} = (typeof ${item.name})[keyof typeof ${item.name}];\n',
    );
  }
  for (final item in constants.values) {
    out.write(_tsDoc(item.doc));
    final names = item.values
        .map((value) => '${item.enumName}.${_camel(value)}')
        .join(', ');
    out.writeln('export const ${item.name} = [$names] as const;\n');
  }
  for (final item in documents.values) {
    out.write(_tsDoc(item.doc));
    out.writeln('export interface ${item.name} {');
    for (final field in item.fields) {
      out.writeln('  ${field.key}${field.optional ? '?' : ''}: ${field.ts};');
    }
    out.writeln('}\n');
  }
  return '${out.toString().trimRight()}\n';
}

String _tsDoc(String? text) => text == null ? '' : '/** ${text.trim()} */\n';
