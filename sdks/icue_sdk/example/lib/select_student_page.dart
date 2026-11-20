import 'package:flutter/material.dart';
import 'package:icue_example/firebase_options.dart';
import 'package:icue_sdk/icue_sdk.dart';

import 'school_config.dart';
import 'session_manager.dart';
import 'student_dashboard_page.dart';

/// Screen allowing the user to select a school and student, mimicking a Sign-in flow.
/// The iCue SDK is initialized dynamically when the user signs in with a student.
class SelectStudentPage extends StatefulWidget {
  const SelectStudentPage({super.key});

  @override
  State<SelectStudentPage> createState() => _SelectStudentPageState();
}

class _SelectStudentPageState extends State<SelectStudentPage> {
  late final List<SchoolConfig> _schools;
  late SchoolConfig _selectedSchool;
  bool _isSigningIn = false;
  String? _signingInStudentId;
  final TextEditingController _customStudentIdController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _schools = List.from(defaultPreconfiguredSchools);
    _selectedSchool = _schools.first;
    _loadCustomSchools();
  }

  Future<void> _loadCustomSchools() async {
    final custom = await SessionManager.getCustomSchools();
    if (custom.isNotEmpty && mounted) {
      setState(() {
        for (final s in custom) {
          if (!_schools.any((existing) => existing.id == s.id)) {
            _schools.add(s);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _customStudentIdController.dispose();
    super.dispose();
  }

  Future<void> _signInAsStudent(String studentId) async {
    final trimmedId = studentId.trim();
    if (trimmedId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Student Identification Number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
      _signingInStudentId = trimmedId;
    });

    try {
      final sdkConfig = _selectedSchool.toSdkConfig(
        firebaseOptions: const IcueFirebaseOptions(
          android: DefaultFirebaseOptions.android,
          ios: DefaultFirebaseOptions.ios,
        ),
      );

      // Initialize SDK dynamically on sign-in (auto-handles new setup or configuration changes)
      await IcueSdk.init(sdkConfig);

      await IcueSdk.setIdentificationNo(trimmedId);

      // Persist session locally
      await SessionManager.saveSession(
        school: _selectedSchool,
        studentId: trimmedId,
      );

      final session = UserSession(
        school: _selectedSchool,
        studentId: trimmedId,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => StudentDashboardPage(session: session),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _signingInStudentId = null;
        });
      }
    }
  }

  void _showAddCustomSchoolDialog() {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final apiUserController = TextEditingController();
    final studentIdsController = TextEditingController();
    var selectedEnv = IcueEnvironment.dev;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.school, color: Color(0xFF13967E)),
                SizedBox(width: 8),
                Text('Add Custom School', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configure school credentials to initialize the SDK upon sign-in.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'School Name *',
                      hintText: 'e.g. Cambridge Academy',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiUserController,
                    decoration: const InputDecoration(
                      labelText: 'ICUE_API_USER *',
                      hintText: 'e.g. bchaitanya',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'ICUE_API_KEY *',
                      hintText: 'e.g. c1828895-c520-df06-...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: studentIdsController,
                    decoration: const InputDecoration(
                      labelText: 'ICUE_IDENTIFICATION_NO *',
                      hintText: 'e.g. UT1234000, TNX250153',
                      helperText: 'Comma-separated student IDs',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Environment',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<IcueEnvironment>(
                    segments: const [
                      ButtonSegment(
                        value: IcueEnvironment.dev,
                        label: Text('Dev'),
                        icon: Icon(Icons.developer_mode, size: 16),
                      ),
                      ButtonSegment(
                        value: IcueEnvironment.prod,
                        label: Text('Prod'),
                        icon: Icon(Icons.cloud_done, size: 16),
                      ),
                    ],
                    selected: {selectedEnv},
                    onSelectionChanged: (newSelection) {
                      setDialogState(() {
                        selectedEnv = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final apiKey = apiKeyController.text.trim();
                  final apiUser = apiUserController.text.trim();
                  final studentIdsRaw = studentIdsController.text.trim();

                  if (name.isEmpty || apiKey.isEmpty || apiUser.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all required fields'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final studentIds = studentIdsRaw
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();

                  final newSchool = SchoolConfig(
                    id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    apiKey: apiKey,
                    apiUser: apiUser,
                    studentIds: studentIds,
                    env: selectedEnv,
                  );

                  await SessionManager.saveCustomSchool(newSchool);

                  setState(() {
                    _schools.add(newSchool);
                    _selectedSchool = newSchool;
                  });

                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                },
                child: const Text('Save & Select'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '••••••••';
    return '${apiKey.substring(0, 4)}••••••••${apiKey.substring(apiKey.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Student'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Custom School',
            onPressed: _showAddCustomSchoolDialog,
          ),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. School Selector Dropdown Section
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.apartment_rounded, color: primary, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Select School',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SchoolConfig>(
                        isExpanded: true,
                        value: _selectedSchool,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _schools.map((SchoolConfig school) {
                          final isDev = school.env == IcueEnvironment.dev;
                          return DropdownMenuItem<SchoolConfig>(
                            value: school,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    school.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDev
                                        ? Colors.purple.shade50
                                        : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDev
                                          ? Colors.purple.shade200
                                          : Colors.teal.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    isDev ? 'DEV' : 'PROD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDev
                                          ? Colors.purple.shade700
                                          : Colors.teal.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (SchoolConfig? newSchool) {
                          if (newSchool != null) {
                            setState(() {
                              _selectedSchool = newSchool;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. School Details Card
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF13967E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'School Credentials',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildConfigRow(
                    icon: Icons.school_outlined,
                    label: 'School',
                    value: _selectedSchool.name,
                  ),
                  const SizedBox(height: 6),
                  _buildConfigRow(
                    icon: Icons.person_outline,
                    label: 'API User',
                    value: _selectedSchool.apiUser,
                  ),
                  const SizedBox(height: 6),
                  _buildConfigRow(
                    icon: Icons.key_outlined,
                    label: 'API Key',
                    value: _maskApiKey(_selectedSchool.apiKey),
                  ),
                  const SizedBox(height: 6),
                  _buildConfigRow(
                    icon: Icons.language_outlined,
                    label: 'Environment',
                    value: _selectedSchool.env == IcueEnvironment.dev
                        ? 'Dev (itraxpro.com)'
                        : 'Prod (icuepro.com)',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Students Header
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Select Student to Sign In (${_selectedSchool.studentIds.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Student Cards
          if (_selectedSchool.studentIds.isEmpty)
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No student IDs configured for this school.\nEnter a student ID below to sign in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            for (final idNo in _selectedSchool.studentIds)
              Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  onTap: _isSigningIn ? null : () => _signInAsStudent(idNo),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Student: $idNo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Theme.of(context).primaryColorDark,
                    ),
                  ),
                  subtitle: Text(
                    _selectedSchool.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  trailing: _isSigningIn && _signingInStudentId == idNo
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 11,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                ),
              ),

          const SizedBox(height: 16),

          // 5. Custom Student ID Sign-In
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sign In with Custom Student ID',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter any student ID under the active school configuration.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customStudentIdController,
                          decoration: InputDecoration(
                            hintText: 'Enter Student ID (e.g. UT1234000)',
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              size: 20,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onSubmitted: (value) => _signInAsStudent(value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _isSigningIn
                            ? null
                            : () => _signInAsStudent(
                                _customStudentIdController.text,
                              ),
                        icon:
                            _isSigningIn &&
                                _signingInStudentId ==
                                    _customStudentIdController.text.trim()
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.login, size: 16),
                        label: const Text('Sign In'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
