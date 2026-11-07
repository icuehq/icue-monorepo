import 'package:admin_ui/admin_ui.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:school_library/school_library.dart';
import 'package:school_library/src/ui/catalogue/widgets/book_form_validators.dart';

/// A row of equal-width fields on wide screens, stacked on phones.
class _FieldRow extends StatelessWidget {
  const _FieldRow(this.fields);

  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      return Column(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            if (index > 0) const SizedBox(height: 14),
            fields[index],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) const SizedBox(width: 14),
          Expanded(child: fields[index]),
        ],
      ],
    );
  }
}

class BookBasicSection extends StatelessWidget {
  const BookBasicSection({
    required this.title,
    required this.subtitle,
    required this.authors,
    required this.categoryId,
    required this.categories,
    required this.categoryLabel,
    required this.onCategoryChanged,
    super.key,
  });

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController authors;
  final String? categoryId;
  final List<LibraryCategory> categories;
  final String Function(LibraryCategory category) categoryLabel;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Basic information',
    icon: Icons.auto_stories_outlined,
    children: [
      AppTextField(
        controller: title,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        validator: BookValidators.title,
        label: 'Title *',
        hintText: 'e.g. To Kill a Mockingbird',
        icon: Icons.title_rounded,
      ),
      AppTextField(
        controller: subtitle,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        label: 'Subtitle',
        hintText: 'e.g. A Novel',
        icon: Icons.subtitles_outlined,
      ),
      _FieldRow([
        AppTextField(
          controller: authors,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: BookValidators.authors,
          label: 'Authors *',
          hintText: 'e.g. Harper Lee, J.K. Rowling',
          icon: Icons.people_outline_rounded,
          helperText: 'Comma-separated, up to 10',
        ),
        AppDropdown<String>(
          value: categoryId,
          items: [
            for (final category in categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(categoryLabel(category)),
              ),
          ],
          onChanged: onCategoryChanged,
          validator: (value) => value == null ? 'Select a category' : null,
          label: 'Category *',
          icon: Icons.category_outlined,
        ),
      ]),
    ],
  );
}

class BookIdentificationSection extends StatelessWidget {
  const BookIdentificationSection({required this.shelf, super.key});

  final TextEditingController shelf;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Location',
    icon: Icons.location_on_outlined,
    children: [
      AppTextField(
        controller: shelf,
        textInputAction: TextInputAction.next,
        inputFormatters: [LengthLimitingTextInputFormatter(50)],
        label: 'Shelf / Book location',
        hintText: 'e.g. Shelf A-3, Rack 2',
        icon: Icons.location_on_outlined,
        helperText: 'Where this book is kept; new copies start here',
      ),
    ],
  );
}

class BookPublicationSection extends StatelessWidget {
  const BookPublicationSection({
    required this.publisher,
    required this.edition,
    required this.year,
    required this.pages,
    required this.language,
    super.key,
  });

  final TextEditingController publisher;
  final TextEditingController edition;
  final TextEditingController year;
  final TextEditingController pages;
  final TextEditingController language;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Publication details',
    icon: Icons.menu_book_outlined,
    children: [
      _FieldRow([
        AppTextField(
          controller: publisher,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          label: 'Publisher',
          hintText: 'e.g. Penguin Random House',
          icon: Icons.business_outlined,
        ),
        AppTextField(
          controller: edition,
          maxLength: 50,
          textInputAction: TextInputAction.next,
          label: 'Edition',
          hintText: 'e.g. 2nd Edition or Revised',
          icon: Icons.bookmark_border_rounded,
        ),
      ]),
      _FieldRow([
        AppTextField(
          controller: year,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          validator: BookValidators.year,
          label: 'Publication year',
          hintText: 'YYYY',
          icon: Icons.calendar_today_outlined,
        ),
        AppTextField(
          controller: pages,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: BookValidators.pages,
          label: 'Pages',
          hintText: 'e.g. 320',
          icon: Icons.format_list_numbered_rounded,
        ),
        AppTextField(
          controller: language,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          label: 'Language',
          hintText: 'e.g. English, Hindi',
          icon: Icons.translate_rounded,
        ),
      ]),
    ],
  );
}

class BookDescriptionSection extends StatelessWidget {
  const BookDescriptionSection({
    required this.keywords,
    required this.description,
    super.key,
  });

  final TextEditingController keywords;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) => FormSectionCard(
    title: 'Description & tags',
    icon: Icons.notes_rounded,
    children: [
      AppTextField(
        controller: keywords,
        textInputAction: TextInputAction.next,
        validator: BookValidators.keywords,
        label: 'Keywords / Search tags',
        hintText: 'e.g. Classic, Fiction, Historical',
        icon: Icons.sell_outlined,
        helperText: 'Comma-separated keywords for catalogue search',
      ),
      AppTextField(
        controller: description,
        minLines: 3,
        maxLines: 5,
        maxLength: 2000,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        label: 'Description',
        hintText: 'Brief summary or notes about the book',
        icon: Icons.notes_rounded,
      ),
    ],
  );
}
