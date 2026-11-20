// Releases icue_sdk (and optionally bus_tracking_core) to the private Cloudsmith
// registry in one command: bumps versions, writes the changelog, updates the
// docs, validates, publishes. See sdks/icue_sdk/RELEASING.md.
//
//   dart tool/release.dart beta [--patch|--minor|--major] [-m "note"]... [--core patch|minor|major]
//   dart tool/release.dart stable [-m "note"]... [--core ...]
//   add --dry-run to do everything except upload; all edits are then undone.
//
// beta: next beta of the current version (0.2.0-beta.2 -> 0.2.0-beta.3), or with
//       --patch/--minor/--major the first beta of the next version
//       (0.2.0-beta.2 --minor -> 0.3.0-beta.1; stable 0.2.0 needs the flag).
// stable: promotes the current beta (0.2.0-beta.3 -> 0.2.0).
// The SDK docs HTML lives in the icue-website repo (../icue-website/public).
// Release notes come from -m, or from a "## Unreleased" section in CHANGELOG.md.
import 'dart:io';

const coreDir = 'packages/bus_tracking_core';
const sdkDir = 'sdks/icue_sdk';
const registry = 'https://dart.cloudsmith.io/icue/icue-sdk/';

late final String root;
final originals = <String, String>{};

Never die(String message) {
  stderr.writeln('ERROR: $message');
  _restore();
  exit(1);
}

String _path(String relative) =>
    relative.startsWith('/') ? relative : '$root/$relative';

String read(String relative) => File(_path(relative)).readAsStringSync();

/// Rewrites a file, remembering its original text so a failed or dry run can
/// put it back exactly.
void edit(
  String relative,
  String Function(String text) change, {
  bool allowNoop = false,
}) {
  final text = read(relative);
  final updated = change(text);
  if (updated == text) {
    if (allowNoop) return;
    die('Nothing to update in $relative.');
  }
  originals.putIfAbsent(relative, () => text);
  File(_path(relative)).writeAsStringSync(updated);
}

void _restore() {
  originals.forEach((relative, text) {
    File(_path(relative)).writeAsStringSync(text);
  });
  originals.clear();
}

class Version {
  const Version(this.major, this.minor, this.patch, [this.beta]);

  static Version? tryParse(String text) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-beta\.([1-9]\d*))?$')
        .firstMatch(text);
    if (match == null) return null;
    return Version(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4] == null ? null : int.parse(match[4]!),
    );
  }

  final int major;
  final int minor;
  final int patch;
  final int? beta;

  Version bump(String level) => switch (level) {
    'major' => Version(major + 1, 0, 0),
    'minor' => Version(major, minor + 1, 0),
    'patch' => Version(major, minor, patch + 1),
    _ => die('Unknown level "$level" (use patch, minor or major).'),
  };

  Version get stable => Version(major, minor, patch);

  Version withBeta(int number) => Version(major, minor, patch, number);

  @override
  String toString() =>
      '$major.$minor.$patch${beta == null ? '' : '-beta.$beta'}';
}

Version currentVersion(String dir) {
  final text = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(read('$dir/pubspec.yaml'))?[1];
  return Version.tryParse(text ?? '') ??
      die(
        'Cannot read a version like X.Y.Z or X.Y.Z-beta.N from $dir/pubspec.yaml.',
      );
}

String setPubspecVersion(String text, Version version) => text.replaceFirst(
  RegExp(r'^version:\s*\S+', multiLine: true),
  'version: $version',
);

/// Release notes: -m lines, else the "## Unreleased" section of the SDK changelog.
List<String> releaseNotes(List<String> messages) {
  if (messages.isNotEmpty) {
    return [
      for (final message in messages)
        message.trimLeft().startsWith('-') ? message : '- $message',
    ];
  }
  final match = RegExp(
    r'^## Unreleased[ \t]*\n(.*?)(?=^## |\z)',
    multiLine: true,
    dotAll: true,
  ).firstMatch(read('$sdkDir/CHANGELOG.md'));
  final lines = (match?[1] ?? '')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    die(
      'No release notes. Pass -m "what changed" or write them under "## Unreleased" in $sdkDir/CHANGELOG.md.',
    );
  }
  return lines;
}

String addChangelog(String text, Version version, List<String> notes) {
  final withoutUnreleased = text.replaceFirst(
    RegExp(
      r'^## Unreleased[ \t]*\n.*?(?=^## |\z)',
      multiLine: true,
      dotAll: true,
    ),
    '',
  );
  return '## $version\n\n${notes.join('\n')}\n\n$withoutUnreleased';
}

Future<int> run(List<String> command, {required String dir}) async {
  stdout.writeln('\$ ${command.join(' ')}  (in $dir)');
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: _path(dir),
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

/// `dart pub publish --dry-run` exits non-zero on mere warnings (our tree is
/// intentionally dirty); only a real validation error should stop the release.
Future<void> publishDryRun(String dir) async {
  final result = await Process.run('dart', [
    'pub',
    'publish',
    '--dry-run',
  ], workingDirectory: _path(dir));
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  final output = '${result.stdout}${result.stderr}';
  if (result.exitCode != 0 && output.contains("can't be published yet")) {
    die('dart pub publish --dry-run failed in $dir.');
  }
}

/// The SDK docs live in the icue-website repo (single source), expected next to
/// this repo; override with ICUE_WEBSITE_DOCS_DIR.
final docsDir =
    Platform.environment['ICUE_WEBSITE_DOCS_DIR'] ?? '../icue-website/public';
String get liveDocs => '$docsDir/icue-sdk-docs.html';
String get betaDocs => '$docsDir/icue-sdk-beta-docs.html';

/// The version a docs page declares in its structured data ("v0.1.0").
String? docsVersion(String relative) =>
    RegExp(r'"softwareVersion":\s*"v([^"]+)"').firstMatch(read(relative))?[1];

/// Swaps the versions shown in the two hand-written HTML docs. Only exact
/// version strings are replaced; the page content stays manual.
void updateDocs(Version next) {
  if (!File(_path(liveDocs)).existsSync() ||
      !File(_path(betaDocs)).existsSync()) {
    stdout.writeln(
      'NOTE: SDK docs not found in $docsDir; update icue-sdk-docs.html and '
      'icue-sdk-beta-docs.html in icue-website by hand (or set ICUE_WEBSITE_DOCS_DIR).',
    );
    return;
  }
  if (next.beta != null) {
    final old = docsVersion(betaDocs);
    if (old == null || old == '$next') return;
    final oldVersion = Version.tryParse(old);
    for (final file in [liveDocs, betaDocs]) {
      edit(file, (text) {
        var updated = text.replaceAll(old, '$next');
        // Titles and meta tags use the short form: "v0.2".
        if (file == betaDocs &&
            oldVersion != null &&
            (oldVersion.major != next.major ||
                oldVersion.minor != next.minor)) {
          updated = updated.replaceAll(
            RegExp('\\bv${oldVersion.major}\\.${oldVersion.minor}(?![\\d.])'),
            'v${next.major}.${next.minor}',
          );
        }
        return updated;
      }, allowNoop: true);
    }
  } else {
    final old = docsVersion(liveDocs);
    if (old == null || old == '$next') return;
    // Not followed by "-beta" or more digits, so "0.2.0-beta.3" is left alone.
    final pattern = RegExp('(?<![\\d.])${RegExp.escape(old)}(?![\\d.]|-)');
    for (final file in [liveDocs, betaDocs]) {
      edit(file, (text) => text.replaceAll(pattern, '$next'), allowNoop: true);
    }
  }
}

/// Prints what this release changed in each edited file.
Future<void> showEdits() async {
  final temp = Directory.systemTemp.createTempSync('release_');
  var index = 0;
  for (final entry in originals.entries) {
    final before = File('${temp.path}/${index++}')
      ..writeAsStringSync(entry.value);
    final result = await Process.run('diff', [
      '-u',
      '--label',
      'a/${entry.key}',
      '--label',
      'b/${entry.key}',
      before.path,
      _path(entry.key),
    ]);
    stdout.write(result.stdout);
  }
  temp.deleteSync(recursive: true);
}

Future<void> check(String dir) async {
  stdout.writeln('\n--- Checking $dir');
  if (await run(['flutter', 'analyze', '--no-fatal-infos'], dir: dir) != 0) {
    die('flutter analyze failed in $dir.');
  }
  if (await run(['flutter', 'test'], dir: dir) != 0) {
    die('flutter test failed in $dir.');
  }
  await publishDryRun(dir);
}

Future<void> main(List<String> args) async {
  root = File.fromUri(Platform.script).parent.parent.path;

  String? channel;
  String? level;
  String? coreLevel;
  var dryRun = false;
  final messages = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case 'beta' || 'stable':
        channel = args[i];
      case '--patch' || '--minor' || '--major':
        level = args[i].substring(2);
      case '--core':
        coreLevel = i + 1 < args.length
            ? args[++i]
            : die('--core needs patch, minor or major.');
      case '-m' || '--message':
        messages.add(i + 1 < args.length ? args[++i] : die('-m needs text.'));
      case '--dry-run':
        dryRun = true;
      default:
        die(
          'Unknown argument "${args[i]}". See the header of tool/release.dart.',
        );
    }
  }
  if (channel == null) die('Say what to release: beta or stable.');

  final current = currentVersion(sdkDir);
  final Version next;
  if (channel == 'stable') {
    if (current.beta == null) {
      die('$current is already stable. Start a beta first.');
    }
    if (level != null) die('stable promotes the current beta; drop --$level.');
    next = current.stable;
  } else if (current.beta != null && level == null) {
    next = current.withBeta(current.beta! + 1);
  } else if (level != null) {
    next = current.stable.bump(level).withBeta(1);
  } else {
    die(
      '$current is stable: say which beta to start with --patch, --minor or --major.',
    );
  }

  final notes = releaseNotes(messages);
  final coreCurrent = currentVersion(coreDir);
  if (coreLevel != null && coreCurrent.beta != null) {
    die('bus_tracking_core must be a stable version (found $coreCurrent).');
  }
  final coreNext = coreLevel == null ? null : coreCurrent.bump(coreLevel);

  stdout.writeln(
    'icue_sdk $current -> $next (${next.beta == null ? 'stable' : 'beta'})',
  );
  stdout.writeln(
    coreNext == null
        ? 'bus_tracking_core $coreCurrent: not published (use --core patch|minor|major)'
        : 'bus_tracking_core $coreCurrent -> $coreNext',
  );
  stdout.writeln('Notes:\n${notes.join('\n')}\n');

  var published = false;
  try {
    // --- icue_sdk files
    edit('$sdkDir/pubspec.yaml', (text) => setPubspecVersion(text, next));
    edit(
      '$sdkDir/lib/src/version.dart',
      (text) => text.replaceFirst(
        RegExp(r"icueSdkVersion = '[^']*'"),
        "icueSdkVersion = '$next'",
      ),
    );
    edit('$sdkDir/CHANGELOG.md', (text) => addChangelog(text, next, notes));
    edit('$sdkDir/README.md', (text) {
      var updated = text.replaceFirst(
        RegExp(r'badge/version-.*?-(orange|blue)\.svg'),
        'badge/version-${next.toString().replaceAll('-', '--')}-${next.beta == null ? 'blue' : 'orange'}.svg',
      );
      updated = next.beta == null
          ? updated.replaceFirst(
              RegExp(r'version: \^\d+\.\d+\.\d+'),
              'version: ^$next',
            )
          : updated.replaceFirst(
              RegExp(r'version: \d+\.\d+\.\d+-beta\.\d+'),
              'version: $next',
            );
      return updated;
    });

    updateDocs(next);

    // --- bus_tracking_core files
    if (coreNext != null) {
      edit(
        '$coreDir/pubspec.yaml',
        (text) => setPubspecVersion(text, coreNext),
      );
      edit(
        '$coreDir/CHANGELOG.md',
        (text) => addChangelog(text, coreNext, notes),
      );
      edit(
        '$sdkDir/pubspec.yaml',
        (text) => text.replaceFirstMapped(
          RegExp(r'(bus_tracking_core:\n\s+hosted: \S+\n\s+version: )\^[\d.]+'),
          (match) => '${match[1]}^$coreNext',
        ),
      );
    }

    await run(['dart', 'pub', 'get'], dir: '.');
    if (coreNext != null) await check(coreDir);
    await check(sdkDir);

    if (dryRun) {
      await showEdits();
      stdout.writeln(
        '\nDry run complete. Nothing was uploaded; all edits undone.',
      );
      return;
    }
    if (stdin.hasTerminal) {
      stdout.write('Publish to $registry (permanent)? [y/N] ');
      if (stdin.readLineSync()?.toLowerCase() != 'y') {
        die('Cancelled; all edits undone.');
      }
    }

    if (coreNext != null) {
      if (await run(['dart', 'pub', 'publish', '--force'], dir: coreDir) != 0) {
        die('Publishing bus_tracking_core failed.');
      }
      published = true;
    }
    if (await run(['dart', 'pub', 'publish', '--force'], dir: sdkDir) != 0) {
      if (published) {
        originals.clear(); // core is out; keep its version bump on disk
        stderr.writeln(
          'bus_tracking_core $coreNext was published but icue_sdk failed. Edits kept; fix and rerun without --core.',
        );
        exit(1);
      }
      die('Publishing icue_sdk failed.');
    }
    published = true;
    originals.clear();
    stdout.writeln(
      '\nPublished icue_sdk $next. Review and commit the changes (git diff), '
      'and commit the docs in icue-website if they changed.',
    );
  } finally {
    if (!published) _restore();
  }
}
