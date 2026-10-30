class Section {
  const Section({required this.id, required this.name});

  factory Section.fromJson(Map<String, dynamic> json) =>
      Section(id: json['Id'] as int? ?? 0, name: json['Name'] as String? ?? '');

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'Id': id, 'Name': name};
}

class Standards {
  const Standards({
    required this.id,
    required this.name,
    this.sections = const <Section>[],
    this.standardType,
  });

  factory Standards.fromJson(Map<String, dynamic> json) => Standards(
    id: json['Id'] as int? ?? 0,
    name: json['Name'] as String? ?? '',
    standardType: json['StandardType'] as String?,
    sections: json['Sections'] is List
        ? (json['Sections'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Section.fromJson)
              .toList()
        : const <Section>[],
  );

  final int id;
  final String name;
  final String? standardType;
  final List<Section> sections;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'StandardType': standardType,
    'Sections': sections.map((x) => x.toJson()).toList(),
  };
}
