import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/resource_model.dart';
import '../../services/resource_service.dart';
import '../../widgets/common_widgets.dart';
import 'share_resource_screen.dart';
import 'notes_screen.dart';

// ══════════════════════════════════════════════════════════════════
//   RESOURCES SCREEN  (3 tabs: Files & Links | Shared With Me | Notes)
// ══════════════════════════════════════════════════════════════════

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with SingleTickerProviderStateMixin {
  final _service = ResourceService();
  late TabController _tabController;

  List<ResourceModel> _resources   = [];
  List<ResourceModel> _sharedWithMe = [];
  bool _loadingResources  = true;
  bool _loadingShared     = true;
  String? _activeFilter;           // null = "all"

  static const _filters = ['all', 'pdf', 'ppt', 'image', 'video', 'link', 'document'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load "shared with me" lazily when that tab is first opened
    _tabController.addListener(() {
      if (_tabController.index == 1 &&
          _sharedWithMe.isEmpty &&
          !_loadingShared) {
        _loadShared();
      }
    });

    _loadResources();
    _loadShared();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    setState(() => _loadingResources = true);
    final data = await _service.getResources();
    if (mounted) setState(() { _resources = data; _loadingResources = false; });
  }

  Future<void> _loadShared() async {
    setState(() => _loadingShared = true);
    final data = await _service.getSharedWithMe();
    if (mounted) setState(() { _sharedWithMe = data; _loadingShared = false; });
  }

  Future<void> _reloadAll() async {
    await Future.wait([_loadResources(), _loadShared()]);
  }

  List<ResourceModel> _applyFilter(List<ResourceModel> list) {
    if (_activeFilter == null || _activeFilter == 'all') return list;
    return list.where((r) => r.resourceType == _activeFilter).toList();
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [

        // ── Header ────────────────────────────────────────────────
        FadeInDown(
          duration: const Duration(milliseconds: 450),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 0),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Resources',
                        style: GoogleFonts.sora(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text('Files, links & department notes',
                        style: GoogleFonts.sora(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8))),
                  ]),
                  // Add / share button
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const ShareResourceScreen()));
                      await _reloadAll();
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.55),
                labelStyle: GoogleFonts.sora(
                    fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.sora(fontSize: 12),
                tabs: const [
                  Tab(text: 'Files & Links'),
                  Tab(text: 'Shared With Me'),
                  Tab(text: 'Notes'),
                ],
              ),
            ]),
          ),
        ),

        // ── Tab content ───────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [

              // ── Tab 1: Files & Links ────────────────────────────
              _ResourceListView(
                resources: _applyFilter(_resources),
                isLoading: _loadingResources,
                filters: _filters,
                activeFilter: _activeFilter,
                showDelete: true,
                emptyTitle: 'No resources yet',
                emptySubtitle: 'Tap + to share a file or link',
                emptyActionLabel: 'Share Resource',
                onFilterChanged: (f) =>
                    setState(() => _activeFilter = f == 'all' ? null : f),
                onRefresh: _loadResources,
                onEmptyAction: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ShareResourceScreen()));
                  await _reloadAll();
                },
                service: _service,
                onDeleted: _loadResources,
              ),

              // ── Tab 2: Shared With Me ───────────────────────────
              _ResourceListView(
                resources: _applyFilter(_sharedWithMe),
                isLoading: _loadingShared,
                filters: _filters,
                activeFilter: _activeFilter,
                showDelete: false,
                emptyTitle: 'Nothing shared with you yet',
                emptySubtitle:
                    'Resources shared directly with you or your groups appear here',
                onFilterChanged: (f) =>
                    setState(() => _activeFilter = f == 'all' ? null : f),
                onRefresh: _loadShared,
                service: _service,
              ),

              // ── Tab 3: Notes ────────────────────────────────────
              const NotesTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//   RESOURCE LIST VIEW  (shared between tab 1 and tab 2)
// ══════════════════════════════════════════════════════════════════

class _ResourceListView extends StatelessWidget {
  final List<ResourceModel> resources;
  final bool isLoading;
  final List<String> filters;
  final String? activeFilter;
  final bool showDelete;
  final String emptyTitle;
  final String emptySubtitle;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final void Function(String) onFilterChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback? onDeleted;
  final ResourceService service;

  const _ResourceListView({
    required this.resources,
    required this.isLoading,
    required this.filters,
    required this.activeFilter,
    required this.showDelete,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.emptyActionLabel,
    this.onEmptyAction,
    required this.onFilterChanged,
    required this.onRefresh,
    this.onDeleted,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      // ── Filter chips ─────────────────────────────────────────
      SizedBox(
        height: 52,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: filters.length,
          itemBuilder: (_, i) {
            final f        = filters[i];
            final isActive = (activeFilter ?? 'all') == f;
            return GestureDetector(
              onTap: () => onFilterChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive
                          ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  f == 'all' ? 'All' : f.toUpperCase(),
                  style: GoogleFonts.sora(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ),

      // ── List / empty / loading ───────────────────────────────
      Expanded(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppColors.primary))
            : resources.isEmpty
                ? EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    actionLabel: emptyActionLabel,
                    onAction: onEmptyAction,
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: resources.length,
                      itemBuilder: (_, i) => FadeInUp(
                        duration: const Duration(milliseconds: 380),
                        delay: Duration(milliseconds: i * 45),
                        child: _ResourceCard(
                          resource: resources[i],
                          service: service,
                          showDelete: showDelete,
                          onDeleted: onDeleted,
                        ),
                      ),
                    ),
                  ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//   RESOURCE CARD
// ══════════════════════════════════════════════════════════════════

class _ResourceCard extends StatefulWidget {
  final ResourceModel resource;
  final ResourceService service;
  final bool showDelete;
  final VoidCallback? onDeleted;

  // ignore: prefer_const_constructors_in_immutables
  _ResourceCard({
    required this.resource,
    required this.service,
    required this.showDelete,
    this.onDeleted,
  });

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> {
  bool   _isDownloading    = false;
  double _downloadProgress = 0;

  // ── Open link or download file ──────────────────────────────────

  Future<void> _handleAction() async {
    final r = widget.resource;

    if (r.isLink) {
      final uri = Uri.tryParse(r.linkUrl ?? '');
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not open link', isError: true);
      }
      return;
    }

    // Download file
    setState(() { _isDownloading = true; _downloadProgress = 0; });

    final result = await widget.service.downloadAndOpenFile(
      resourceId: r.id,
      fileName:   r.fileName ?? '${r.title}.bin',
      onProgress: (received, total) {
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      },
    );

    if (!mounted) return;
    setState(() => _isDownloading = false);

    if (result['success'] != true) {
      _showSnack(result['message'] ?? 'Download failed', isError: true);
    }
  }

  // ── Confirm delete ──────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Resource',
            style: Theme.of(context).textTheme.headlineSmall),
        content: Text(
            'Remove "${widget.resource.title}"? This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete',
                  style: GoogleFonts.sora(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      final deleted =
          await widget.service.deleteResource(widget.resource.id);
      if (deleted && mounted) widget.onDeleted?.call();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.resource;
    final dt     = DateTime.tryParse(r.createdAt)?.toLocal();
    final dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [

        // Type icon box
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
              color: r.typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(r.typeIcon, color: r.typeColor, size: 24),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              Text(r.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              const SizedBox(height: 4),

              // Type badge + size + date
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Badge(label: r.typeLabel, color: r.typeColor),
                  if (r.fileSizeLabel.isNotEmpty)
                    Text(r.fileSizeLabel,
                        style: GoogleFonts.sora(
                            fontSize: 11, color: AppColors.textHint)),
                  Text(dateStr,
                      style: GoogleFonts.sora(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),

              // Uploader
              if (r.uploader != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  _MiniAvatar(
                    avatarUrl: r.uploader!.avatarUrl,
                    initials:  r.uploader!.initials,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(r.uploader!.fullName,
                        style: GoogleFonts.sora(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],

              // Download count
              if (r.downloadCount > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.download_rounded,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 3),
                  Text('${r.downloadCount} downloads',
                      style: GoogleFonts.sora(
                          fontSize: 11, color: AppColors.textHint)),
                ]),
              ],

              // Tags
              if (r.tagList.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(spacing: 5, children: r.tagList.take(3).map((t) =>
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('#$t',
                        style: GoogleFonts.sora(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  )
                ).toList()),
              ],

              // Download progress bar
              if (_isDownloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _downloadProgress > 0
                        ? _downloadProgress : null,
                    color: AppColors.primary,
                    backgroundColor:
                        AppColors.primary.withOpacity(0.1),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Action buttons
        Column(mainAxisSize: MainAxisSize.min, children: [

          // Open / download
          GestureDetector(
            onTap: _isDownloading ? null : _handleAction,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(10)),
              child: _isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary))
                  : Icon(
                      r.isLink
                          ? Icons.open_in_new_rounded
                          : Icons.download_rounded,
                      color: AppColors.primary, size: 18),
            ),
          ),

          // Delete (only shown when showDelete = true)
          if (widget.showDelete) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _confirmDelete,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error, size: 18),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//   SMALL HELPERS
// ══════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: GoogleFonts.sora(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

class _MiniAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String  initials;

  const _MiniAvatar({this.avatarUrl, required this.initials});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 9,
        backgroundColor: AppColors.primary.withOpacity(0.12),
        backgroundImage:
            avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null
            ? Text(initials,
                style: GoogleFonts.sora(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary))
            : null,
      );
}