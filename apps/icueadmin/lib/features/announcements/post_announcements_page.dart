import 'package:announcements/announcements.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icueadmin/analytics/app_events.dart';
import 'package:icueadmin/features/announcements/widgets/announcement_template_form.dart';
import 'package:icueadmin/features/announcements/widgets/preview_announcement_dialog.dart';
import 'package:icueadmin/features/announcements/widgets/select_points_dialog.dart';
import 'package:icueadmin/features/announcements/widgets/select_routes_dialog.dart';
import 'package:icueadmin/routing/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:routes/routes.dart';

enum AnnouncementTarget {
  entireFleet('Entire Fleet'),
  selectedRoutes('Selected Routes'),
  singleRoutePoints('Effected parents for single route');

  const AnnouncementTarget(this.label);
  final String label;
}

class PostAnnouncementsPage extends StatefulWidget {
  const PostAnnouncementsPage({super.key});

  @override
  State<PostAnnouncementsPage> createState() => _PostAnnouncementsPageState();
}

class _PostAnnouncementsPageState extends State<PostAnnouncementsPage> {
  final _formKey = GlobalKey<FormState>();

  RouteMode _mode = RouteMode.pickup;
  AnnouncementTarget _target = AnnouncementTarget.entireFleet;

  List<int> _selectedRouteIds = <int>[];
  int? _singleRouteId;
  List<String> _selectedPointNames = <String>[];
  List<int> _selectedStudentIds = <int>[];

  AnnouncementTitle? _selectedTitleTemplate;
  String _customTitle = '';
  String _customDescription = '';
  final Map<String, TextEditingController> _varControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnnouncementsProvider>().fetchAnnouncementTitles();
      context.read<RoutesProvider>().fetchRoutes(RouteMode.pickup);
    });
  }

  @override
  void dispose() {
    for (final controller in _varControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onModeChanged(RouteMode? newMode) {
    if (newMode == null || newMode == _mode) return;
    setState(() {
      _mode = newMode;
      _selectedRouteIds.clear();
      _singleRouteId = null;
      _selectedPointNames.clear();
      _selectedStudentIds.clear();
    });
    context.read<RoutesProvider>().fetchRoutes(newMode);
  }

  void _onTargetChanged(AnnouncementTarget? target) {
    if (target == null) return;
    setState(() {
      _target = target;
      _selectedRouteIds.clear();
      _singleRouteId = null;
      _selectedPointNames.clear();
      _selectedStudentIds.clear();
    });
  }

  void _onTemplateChanged(AnnouncementTitle? template) {
    setState(() {
      _selectedTitleTemplate = template;
      _varControllers.clear();
      if (template != null) {
        for (final v in template.vars) {
          _varControllers[v] = TextEditingController();
        }
      }
    });
  }

  String _getInterpolatedMessage() {
    if (_selectedTitleTemplate == null) return '';
    if (_selectedTitleTemplate!.title == 'Custom') return _customDescription;

    var text =
        '${_selectedTitleTemplate!.descHeader} ${_selectedTitleTemplate!.descBody} ${_selectedTitleTemplate!.descFooter}'
            .trim();
    for (final v in _selectedTitleTemplate!.vars) {
      final value = _varControllers[v]?.text.trim() ?? '';
      text = text.replaceAll('[$v]', value.isEmpty ? '[$v]' : value);
    }
    return text;
  }

  Future<void> _pickRoutes(List<Routee> routes) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => SelectRoutesDialog(
        availableRoutes: routes,
        initialSelectedRouteIds: _selectedRouteIds,
      ),
    );
    if (result != null) {
      setState(() => _selectedRouteIds = result);
    }
  }

  Future<void> _pickPoints(List<RoutePoint> points) async {
    final result = await showDialog<SelectPointsResult>(
      context: context,
      builder: (ctx) => SelectPointsDialog(
        availablePoints: points,
        initialSelectedNames: _selectedPointNames,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedPointNames = result.pointNames;
        _selectedStudentIds = result.studentIds;
      });
    }
  }

  Future<void> _submitAnnouncement(List<Routee> routes) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final title = _selectedTitleTemplate?.title == 'Custom'
        ? _customTitle.trim()
        : _selectedTitleTemplate!.title;

    final description = _getInterpolatedMessage();

    List<int> targetRoutes = [];
    List<int> targetStudents = [];

    if (_target == AnnouncementTarget.entireFleet) {
      targetRoutes = routes.map((r) => r.id).toList();
      targetStudents = routes
          .expand((r) => r.points)
          .expand((p) => p.studentIds)
          .toList();
    } else if (_target == AnnouncementTarget.selectedRoutes) {
      if (_selectedRouteIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one route')),
        );
        return;
      }
      targetRoutes = _selectedRouteIds;
      final selectedRoutesList = routes.where(
        (r) => _selectedRouteIds.contains(r.id),
      );
      targetStudents = selectedRoutesList
          .expand((r) => r.points)
          .expand((p) => p.studentIds)
          .toList();
    } else {
      if (_singleRouteId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a route')));
        return;
      }
      if (_selectedPointNames.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one stop point'),
          ),
        );
        return;
      }
      targetRoutes = [_singleRouteId!];
      targetStudents = _selectedStudentIds;
    }

    final modeLabel = _mode == RouteMode.pickup ? 'Pickup' : 'Drop';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => PreviewAnnouncementDialog(
        title: title,
        description: description,
        mode: modeLabel,
        routesCount: targetRoutes.length,
        pointsCount: _target == AnnouncementTarget.singleRoutePoints
            ? _selectedPointNames.length
            : null,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );

    if (confirmed != true || !mounted) return;

    final req = CreateAnnouncementRequest(
      title: title,
      description: description,
      mode: modeLabel,
      routes: targetRoutes,
      points: _selectedPointNames.isNotEmpty ? _selectedPointNames : null,
      studentIds: targetStudents.isNotEmpty ? targetStudents : null,
    );

    final success = await context
        .read<AnnouncementsProvider>()
        .postAnnouncement(req);

    if (!mounted) return;

    if (success) {
      track(AppEvents.announcementPosted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement broadcast sent successfully!'),
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AnnouncementsProvider>().errorMessage ??
                'Failed to broadcast announcement.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final annProvider = context.watch<AnnouncementsProvider>();
    final routeProvider = context.watch<RoutesProvider>();
    final routes = routeProvider.routes;

    final selectedRoute = _singleRouteId != null
        ? routes.firstWhere(
            (r) => r.id == _singleRouteId,
            orElse: () =>
                const Routee(id: 0, routeNo: '', mode: RouteMode.pickup),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Announcement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View History',
            onPressed: () => context.push(AppRoutes.announcements),
          ),
        ],
      ),
      body: annProvider.isLoading && annProvider.announcementTitles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<AnnouncementTarget>(
                    initialValue: _target,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Scope *',
                      border: OutlineInputBorder(),
                    ),
                    items: AnnouncementTarget.values.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t.label));
                    }).toList(),
                    onChanged: _onTargetChanged,
                  ),
                  if (_target == AnnouncementTarget.entireFleet) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: This message will be sent to parents across the entire fleet.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RouteMode>(
                    initialValue: _mode,
                    decoration: const InputDecoration(
                      labelText: 'Shift Mode *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RouteMode.pickup,
                        child: Text('Pickup'),
                      ),
                      DropdownMenuItem(
                        value: RouteMode.drop,
                        child: Text('Drop'),
                      ),
                    ],
                    onChanged: _onModeChanged,
                  ),
                  if (_target == AnnouncementTarget.selectedRoutes) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _pickRoutes(routes),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Target Routes *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                        child: Text(
                          _selectedRouteIds.isEmpty
                              ? 'Tap to select routes'
                              : '${_selectedRouteIds.length} routes selected',
                          style: TextStyle(
                            color: _selectedRouteIds.isEmpty
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_target == AnnouncementTarget.singleRoutePoints) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _singleRouteId,
                      decoration: const InputDecoration(
                        labelText: 'Select Route *',
                        border: OutlineInputBorder(),
                      ),
                      items: routes.map((r) {
                        return DropdownMenuItem(
                          value: r.id,
                          child: Text('Route ${r.routeNo}'),
                        );
                      }).toList(),
                      onChanged: (id) {
                        setState(() {
                          _singleRouteId = id;
                          _selectedPointNames.clear();
                          _selectedStudentIds.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: selectedRoute != null
                          ? () => _pickPoints(selectedRoute.points)
                          : null,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Select Stop Points *',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          enabled: selectedRoute != null,
                        ),
                        child: Text(
                          _selectedPointNames.isEmpty
                              ? (selectedRoute == null
                                    ? 'Select a route first'
                                    : 'Tap to select stops')
                              : '${_selectedPointNames.length} stops selected (${_selectedStudentIds.length} students)',
                          style: TextStyle(
                            color: _selectedPointNames.isEmpty
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AnnouncementTemplateForm(
                    templates: annProvider.announcementTitles,
                    selectedTemplate: _selectedTitleTemplate,
                    onTemplateChanged: _onTemplateChanged,
                    customTitle: _customTitle,
                    onCustomTitleSaved: (val) => _customTitle = val ?? '',
                    customDescription: _customDescription,
                    onCustomDescriptionChanged: (val) =>
                        setState(() => _customDescription = val),
                    onCustomDescriptionSaved: (val) =>
                        _customDescription = val ?? '',
                    varControllers: _varControllers,
                    onVarChanged: () => setState(() {}),
                    interpolatedMessage: _getInterpolatedMessage(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: annProvider.isLoading
                        ? null
                        : () => _submitAnnouncement(routes),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Preview & Broadcast',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
