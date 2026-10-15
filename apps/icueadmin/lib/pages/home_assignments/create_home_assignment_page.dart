import 'dart:developer';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/user_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_assignment_provider.dart';
import '../../services/hive_service.dart';
import '../../utils/app_utils.dart';

class CreateHomeAssignmentPage extends StatefulWidget {
  const CreateHomeAssignmentPage({
    super.key,
    this.initialClassId,
    this.initialSection,
  });

  final int? initialClassId;
  final String? initialSection;

  @override
  State<CreateHomeAssignmentPage> createState() =>
      _CreateHomeAssignmentPageState();
}

class _CreateHomeAssignmentPageState extends State<CreateHomeAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _attachmentsFieldKey = GlobalKey<FormFieldState<List<PlatformFile>>>();
  final _workController = TextEditingController();
  final _subjectCustomController = TextEditingController();

  int? _selectedClassId;
  String? _selectedStandard;
  String? _selectedSection;
  int? _selectedSubjectId;
  String? _selectedSubjectName;
  DateTime _submissionDate = DateTime.now().add(const Duration(days: 1));

  final List<PlatformFile> _attachedFiles = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initClassesAndDefaults();
  }

  @override
  void dispose() {
    _workController.dispose();
    _subjectCustomController.dispose();
    super.dispose();
  }

  void _initClassesAndDefaults() {
    final availableClasses = _getAvailableClasses();
    if (availableClasses.isNotEmpty) {
      if (widget.initialClassId != null) {
        final matched = availableClasses.firstWhereOrNull(
          (c) => c.classId == widget.initialClassId,
        );
        if (matched != null) {
          _selectedClassId = matched.classId;
          _selectedStandard = matched.standard;
          if (widget.initialSection != null &&
              matched.sections.contains(widget.initialSection)) {
            _selectedSection = widget.initialSection;
          } else if (matched.sections.isNotEmpty) {
            _selectedSection = matched.sections.first;
          }
        }
      }

      if (_selectedClassId == null) {
        final first = availableClasses.first;
        _selectedClassId = first.classId;
        _selectedStandard = first.standard;
        if (first.sections.isNotEmpty) {
          _selectedSection = first.sections.first;
        }
      }
    }

    _updateSubjectsForCurrentSelection();
  }

  List<_ClassSelectionOption> _getAvailableClasses() {
    final user = HiveService.currentUser;
    final authProvider = context.read<AuthProvider>();

    final Map<int, _ClassSelectionOption> map = {};

    // 1. Check user.classes
    if (user?.classes is List && (user!.classes as List).isNotEmpty) {
      for (final c in user.classes as List) {
        if (c is UserClass && c.classId != 0) {
          if (!map.containsKey(c.classId)) {
            map[c.classId] = _ClassSelectionOption(
              classId: c.classId,
              standard: c.standard,
              sections: List<String>.from(c.sections),
              subjectInfo: c.subjectInfo != null
                  ? List<SubjectInfo>.from(c.subjectInfo!)
                  : null,
            );
          } else {
            final existing = map[c.classId]!;
            for (final sec in c.sections) {
              if (!existing.sections.contains(sec)) {
                existing.sections.add(sec);
              }
            }
          }
        }
      }
    }

    // 2. Check authProvider.assignedEntityClasses
    if (map.isEmpty && authProvider.assignedEntityClasses.isNotEmpty) {
      for (final c in authProvider.assignedEntityClasses) {
        if (c.classId != 0) {
          map[c.classId] = _ClassSelectionOption(
            classId: c.classId,
            standard: c.standard,
            sections: List<String>.from(c.sections),
          );
        }
      }
    }

    return map.values.toList();
  }

  List<Subject> _getAvailableSubjects() {
    if (_selectedClassId == null) return [];
    final classes = _getAvailableClasses();
    final selected = classes.firstWhereOrNull(
      (c) => c.classId == _selectedClassId,
    );
    if (selected == null || selected.subjectInfo == null) return [];

    final subjectsMap = <int, Subject>{};
    for (final info in selected.subjectInfo!) {
      if (_selectedSection == null || info.section == _selectedSection) {
        for (final s in info.subjects) {
          subjectsMap[s.subjectId] = s;
        }
      }
    }

    return subjectsMap.values.toList();
  }

  void _updateSubjectsForCurrentSelection() {
    final subjects = _getAvailableSubjects();
    if (subjects.isNotEmpty) {
      if (_selectedSubjectId == null ||
          !subjects.any((s) => s.subjectId == _selectedSubjectId)) {
        _selectedSubjectId = subjects.first.subjectId;
        _selectedSubjectName = subjects.first.subject;
      }
    } else {
      _selectedSubjectId = null;
      _selectedSubjectName = null;
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        allowMultiple: true,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (final f in result.files) {
            final alreadyExists = _attachedFiles.any((e) => e.name == f.name);
            if (!alreadyExists) {
              _attachedFiles.add(f);
            }
          }
        });
        _attachmentsFieldKey.currentState?.didChange(_attachedFiles);
        _attachmentsFieldKey.currentState?.validate();
      }
    } catch (e) {
      log('Error picking files: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final platformFile = PlatformFile(
          name: photo.name,
          size: bytes.length,
          bytes: bytes,
          path: photo.path,
        );
        setState(() {
          final alreadyExists = _attachedFiles.any((e) => e.name == photo.name);
          if (!alreadyExists) {
            _attachedFiles.add(platformFile);
          }
        });
        _attachmentsFieldKey.currentState?.didChange(_attachedFiles);
        _attachmentsFieldKey.currentState?.validate();
      }
    } catch (e) {
      log('Error picking gallery image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final platformFile = PlatformFile(
          name: photo.name,
          size: bytes.length,
          bytes: bytes,
          path: photo.path,
        );
        setState(() {
          _attachedFiles.add(platformFile);
        });
        _attachmentsFieldKey.currentState?.didChange(_attachedFiles);
        _attachmentsFieldKey.currentState?.validate();
      }
    } catch (e) {
      log('Error taking photo: $e');
    }
  }

  Future<void> _selectSubmissionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _submissionDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _submissionDate = picked);
    }
  }

  Future<void> _submitHomework() async {
    final formValid = _formKey.currentState!.validate();
    if (!formValid) {
      if (_attachedFiles.isEmpty) {
        AppUtils.showErrorMessage(context, 'Please upload at least one file');
      }
      return;
    }

    if (_selectedClassId == null || _selectedSection == null) {
      AppUtils.showErrorMessage(context, 'Please select Class and Section');
      return;
    }

    final subjects = _getAvailableSubjects();
    int subjectId = _selectedSubjectId ?? 1;
    String subjectName = _selectedSubjectName ?? '';

    if (subjects.isEmpty) {
      subjectName = _subjectCustomController.text.trim();
      if (subjectName.isEmpty) {
        AppUtils.showErrorMessage(context, 'Please specify Subject');
        return;
      }
      subjectId = 1;
    }

    if (_attachedFiles.isEmpty) {
      AppUtils.showErrorMessage(context, 'Please upload at least one file');
      return;
    }

    final provider = context.read<HomeAssignmentProvider>();
    final success = await provider.createHomeWork(
      context: context,
      classId: _selectedClassId!,
      section: _selectedSection!,
      standard: _selectedStandard ?? '',
      subjectId: subjectId,
      subject: subjectName,
      submissionDate: _submissionDate,
      work: _workController.text.trim(),
      platformFiles: _attachedFiles,
    );

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableClasses = _getAvailableClasses();
    final selectedClassObj = availableClasses.firstWhereOrNull(
      (c) => c.classId == _selectedClassId,
    );
    final availableSections = selectedClassObj?.sections ?? [];
    final availableSubjects = _getAvailableSubjects();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Create Home Assignment')),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Consumer<HomeAssignmentProvider>(
            builder: (context, provider, _) {
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: provider.submitting ? null : _submitHomework,
                child: provider.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Publish Assignment',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Target & Schedule
              _buildModernCard(
                icon: Icons.tune_rounded,
                title: 'Target & Schedule',
                theme: theme,
                child: Column(
                  children: [
                    // Row 1: Class & Section side-by-side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Standard / Class
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedClassId,
                            isExpanded: true,
                            decoration: _buildInputDecoration(
                              labelText: 'Class',
                              prefixIcon: Icons.school_outlined,
                              theme: theme,
                            ),
                            items: availableClasses.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.classId,
                                child: Text(
                                  c.standard,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedClassId) {
                                setState(() {
                                  _selectedClassId = val;
                                  final match = availableClasses
                                      .firstWhereOrNull(
                                        (c) => c.classId == val,
                                      );
                                  _selectedStandard = match?.standard;
                                  _selectedSection =
                                      match?.sections.firstOrNull;
                                  _updateSubjectsForCurrentSelection();
                                });
                              }
                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Section
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedSection,
                            isExpanded: true,
                            decoration: _buildInputDecoration(
                              labelText: 'Section',
                              prefixIcon: Icons.groups_outlined,
                              theme: theme,
                            ),
                            items: availableSections.map((sec) {
                              return DropdownMenuItem<String>(
                                value: sec,
                                child: Text(
                                  'Sec $sec',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSection = val;
                                  _updateSubjectsForCurrentSelection();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Row 2: Subject & Submission Date
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject
                        Expanded(
                          child: availableSubjects.isNotEmpty
                              ? DropdownButtonFormField<int>(
                                  initialValue: _selectedSubjectId,
                                  isExpanded: true,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Subject',
                                    prefixIcon: Icons.menu_book_outlined,
                                    theme: theme,
                                  ),
                                  items: availableSubjects.map((s) {
                                    return DropdownMenuItem<int>(
                                      value: s.subjectId,
                                      child: Text(
                                        s.subject,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSubjectId = val;
                                        final match = availableSubjects
                                            .firstWhereOrNull(
                                              (s) => s.subjectId == val,
                                            );
                                        _selectedSubjectName = match?.subject;
                                      });
                                    }
                                  },
                                )
                              : TextFormField(
                                  controller: _subjectCustomController,
                                  decoration: _buildInputDecoration(
                                    labelText: 'Subject Name',
                                    prefixIcon: Icons.menu_book_outlined,
                                    theme: theme,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                        ),

                        const SizedBox(width: 10),

                        // Submission Date
                        Expanded(
                          child: InkWell(
                            onTap: _selectSubmissionDate,
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: _buildInputDecoration(
                                labelText: 'Due Date',
                                prefixIcon: Icons.event_outlined,
                                theme: theme,
                              ),
                              child: Text(
                                DateFormat(
                                  'MM/dd/yyyy',
                                ).format(_submissionDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 2: Homework Content
              _buildModernCard(
                icon: Icons.edit_note_rounded,
                title: 'Homework Content',
                theme: theme,
                child: TextFormField(
                  controller: _workController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText:
                        'Write assignment instructions, textbook page numbers, exercise questions, or reference material...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter homework instructions';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Card 3: Attachments
              _buildModernCard(
                icon: Icons.attach_file_rounded,
                title: 'Attachments',
                theme: theme,
                child: FormField<List<PlatformFile>>(
                  key: _attachmentsFieldKey,
                  initialValue: _attachedFiles,
                  validator: (files) {
                    if (_attachedFiles.isEmpty) {
                      return 'Please upload at least one file';
                    }
                    return null;
                  },
                  builder: (fieldState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action Picker Buttons
                        Row(
                          children: [
                            _buildAttachmentActionButton(
                              icon: Icons.camera_alt_outlined,
                              label: 'Camera',
                              onTap: _takePhoto,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            _buildAttachmentActionButton(
                              icon: Icons.photo_library_outlined,
                              label: 'Gallery',
                              onTap: _pickImageFromGallery,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            _buildAttachmentActionButton(
                              icon: Icons.upload_file_outlined,
                              label: 'PDF / Files',
                              onTap: _pickFiles,
                              theme: theme,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Empty hint or Attached Files list
                        if (_attachedFiles.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: fieldState.hasError
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: fieldState.hasError
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  fieldState.hasError
                                      ? Icons.error_outline_rounded
                                      : Icons.info_outline_rounded,
                                  size: 16,
                                  color: fieldState.hasError
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    fieldState.hasError
                                        ? (fieldState.errorText ??
                                              'Please upload at least one file')
                                        : 'Upload worksheets, photos, or PDF documents (Mandatory)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: fieldState.hasError
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                      fontWeight: fieldState.hasError
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Attached Files (${_attachedFiles.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _attachedFiles.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final file = _attachedFiles[index];
                              final isPdf =
                                  file.extension?.toLowerCase() == 'pdf';
                              final sizeKb = (file.size / 1024).toStringAsFixed(
                                1,
                              );

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Thumbnail / Icon
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isPdf
                                            ? const Color(0xFFFEE2E2)
                                            : theme.primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: !isPdf && file.path != null
                                          ? Image.file(
                                              File(file.path!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Icon(
                                                Icons.image_outlined,
                                                size: 20,
                                                color: theme.primaryColor,
                                              ),
                                            )
                                          : Icon(
                                              isPdf
                                                  ? Icons.picture_as_pdf_rounded
                                                  : Icons.image_rounded,
                                              size: 20,
                                              color: isPdf
                                                  ? const Color(0xFFDC2626)
                                                  : theme.primaryColor,
                                            ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Name & Size
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            file.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            '$sizeKb KB',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Remove Button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      splashRadius: 18,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _attachedFiles.removeAt(index);
                                        });
                                        _attachmentsFieldKey.currentState
                                            ?.didChange(_attachedFiles);
                                        _attachmentsFieldKey.currentState
                                            ?.validate();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: theme.primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    required ThemeData theme,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      prefixIcon: Icon(prefixIcon, size: 18, color: theme.primaryColor),
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
      ),
    );
  }
}

class _ClassSelectionOption {
  _ClassSelectionOption({
    required this.classId,
    required this.standard,
    required this.sections,
    this.subjectInfo,
  });

  final int classId;
  final List<String> sections;
  final String standard;
  final List<SubjectInfo>? subjectInfo;
}
