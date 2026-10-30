import 'package:announcements/announcements.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnnouncementTemplateForm extends StatelessWidget {
  const AnnouncementTemplateForm({
    super.key,
    required this.templates,
    required this.selectedTemplate,
    required this.onTemplateChanged,
    required this.customTitle,
    required this.onCustomTitleSaved,
    required this.customDescription,
    required this.onCustomDescriptionChanged,
    required this.onCustomDescriptionSaved,
    required this.varControllers,
    required this.onVarChanged,
    required this.interpolatedMessage,
  });

  final List<AnnouncementTitle> templates;
  final AnnouncementTitle? selectedTemplate;
  final ValueChanged<AnnouncementTitle?> onTemplateChanged;
  final String customTitle;
  final FormFieldSetter<String> onCustomTitleSaved;
  final String customDescription;
  final ValueChanged<String> onCustomDescriptionChanged;
  final FormFieldSetter<String> onCustomDescriptionSaved;
  final Map<String, TextEditingController> varControllers;
  final VoidCallback onVarChanged;
  final String interpolatedMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<AnnouncementTitle>(
          initialValue: selectedTemplate,
          decoration: const InputDecoration(
            labelText: 'Announcement Template *',
            border: OutlineInputBorder(),
          ),
          items: templates.map((t) {
            return DropdownMenuItem(value: t, child: Text(t.title));
          }).toList(),
          onChanged: onTemplateChanged,
          validator: (val) => val == null ? 'Please select a template' : null,
        ),
        if (selectedTemplate != null && selectedTemplate!.title == 'Custom') ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: customTitle,
            decoration: const InputDecoration(
              labelText: 'Custom Title *',
              border: OutlineInputBorder(),
            ),
            onSaved: onCustomTitleSaved,
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: customDescription,
            decoration: const InputDecoration(
              labelText: 'Announcement Message *',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            onChanged: onCustomDescriptionChanged,
            onSaved: onCustomDescriptionSaved,
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
          ),
        ],
        if (selectedTemplate != null &&
            selectedTemplate!.title != 'Custom' &&
            selectedTemplate!.vars.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Template Variables',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...selectedTemplate!.vars.map((v) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: varControllers[v],
                decoration: InputDecoration(
                  labelText: '$v *',
                  border: const OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-Z0-9\s!@#\$&*;,:/-]'),
                  ),
                ],
                onChanged: (_) => onVarChanged(),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Preview:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  interpolatedMessage,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
