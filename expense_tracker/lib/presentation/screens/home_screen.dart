import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../core/di.dart';
import '../providers/expense_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/expense_card.dart';
import '../widgets/summary_bar.dart';
import '../widgets/empty_state.dart';
import 'capture_screen.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _picker = ImagePicker();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late final StreamSubscription _connectivitySub;
  late final Timer _syncTimer;
  Timer? _debounce;

  String? _selectedCategory;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final notifier = ref.read(expenseProvider.notifier);
      await notifier.initialLoad();
      notifier.loadSummary();
      notifier.syncAll();
    });

    // sync when wifi comes back
    _connectivitySub = DI().connectivityRepo.onConnectivityChanged.listen((isConnected) {
      if (isConnected) {
        ref.read(expenseProvider.notifier).syncAll();
      }
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        ref.read(expenseProvider.notifier).syncAll();
      }
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final pixels = _scrollController.position.pixels;
    final max = _scrollController.position.maxScrollExtent;
    if (pixels >= max - 200) {
      ref.read(expenseProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _syncTimer.cancel();
    _connectivitySub.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _applyCurrentFilters();
    });
  }

  void _applyCurrentFilters() {
    final query = _searchController.text.trim();
    ref.read(expenseProvider.notifier).applyFilter(
          category: _selectedCategory,
          query: query.isEmpty ? null : query,
        );
  }

  void _onCategorySelected(String? category) {
    setState(() => _selectedCategory = category);
    _applyCurrentFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _showSearch = false;
      _selectedCategory = null;
      _searchController.clear();
    });
    _debounce?.cancel();
    ref.read(expenseProvider.notifier).clearFilters();
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaptureScreen(imageFile: File(picked.path)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera access denied. Please enable it in settings.'),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Capture Receipt',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to capture receipt'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library)),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // only watch isLoading for the scaffold-level loading state
    final isLoading = ref.watch(
      expenseProvider.select((s) => s.isLoading),
    );
    final hasActiveFilter = ref.watch(
      expenseProvider.select((s) => s.hasActiveFilter),
    );

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by note...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontWeight: FontWeight.normal),
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              if (_showSearch) {
                _clearAllFilters();
              } else {
                setState(() => _showSearch = true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await ref.read(expenseProvider.notifier).syncAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Synced successfully'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // summary watches its own data via select()
          const SummaryBar(),
          // category chips — only depends on local _selectedCategory
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategory == null,
                    onSelected: (_) => _onCategorySelected(null),
                  ),
                ),
                ...AppConstants.categories.map((cat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) {
                          _onCategorySelected(selected ? cat : null);
                        },
                      ),
                    )),
              ],
            ),
          ),
          if (hasActiveFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Filtered results',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // expense list — isolated Consumer so only rebuilds when expenses change
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _ExpenseList(scrollController: _scrollController),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImageSourceDialog,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capture'),
      ),
    );
  }
}

// separate widget — only watches expenses list, not summary
class _ExpenseList extends ConsumerWidget {
  final ScrollController scrollController;
  const _ExpenseList({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(
      expenseProvider.select((s) => s.expenses),
    );
    final hasMore = ref.watch(
      expenseProvider.select((s) => s.hasMore),
    );
    final hasActiveFilter = ref.watch(
      expenseProvider.select((s) => s.hasActiveFilter),
    );


    if (expenses.isEmpty) {
      return hasActiveFilter
          ? const Center(
              child: Text(
                'No expenses match your filter',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : const EmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(expenseProvider.notifier).syncAll();
      },
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: expenses.length + (hasMore && !hasActiveFilter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == expenses.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final expense = expenses[index];
          return ExpenseCard(
            expense: expense,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScreen(expense: expense),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
