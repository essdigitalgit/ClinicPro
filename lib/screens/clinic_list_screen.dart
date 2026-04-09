import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/clinic_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/clinic_card.dart';
import 'add_clinic_screen.dart';
import 'clinic_dashboard_screen.dart';

/// Clinics tab — searchable list of clinics.
class ClinicListScreen extends StatefulWidget {
  const ClinicListScreen({super.key});

  @override
  State<ClinicListScreen> createState() => _ClinicListScreenState();
}

class _ClinicListScreenState extends State<ClinicListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicProvider>().loadClinics();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Clinics'),
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => context.read<ClinicProvider>().loadClinics(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<ClinicProvider>(
        builder: (context, provider, _) {
          final filtered = _query.isEmpty
              ? provider.clinics
              : provider.clinics
                  .where((c) =>
                      c.name.toLowerCase().contains(_query) ||
                      c.address.toLowerCase().contains(_query))
                  .toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _query = v.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: 'Search clinics…',
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              if (!provider.loadingClinics && provider.clinics.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                    child: Text(
                      '${filtered.length} clinic${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textTertiary),
                    ),
                  ),
                ),
              Expanded(
                child: provider.loadingClinics
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? _EmptyState(hasQuery: _query.isNotEmpty)
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 6, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => ClinicCard(
                              clinic: filtered[i],
                              onTap: () {
                                final p = context.read<ClinicProvider>();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ClinicDashboardScreen(clinic: filtered[i]),
                                  ),
                                ).then((_) => p.loadClinics());
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddClinicScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Clinic'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;

  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.local_hospital_outlined,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No clinics found' : 'No clinics yet',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Tap the button below to add your first clinic',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
