import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

class DetailScreen extends ConsumerWidget {
  final ExpenseEntity expense;

  const DetailScreen({super.key, required this.expense});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(expenseProvider.notifier)
                  .deleteExpense(expense.id, expense.isSynced);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getImageProvider() {
    if (expense.localImagePath != null) {
      final file = File(expense.localImagePath!);
      if (file.existsSync()) return FileImage(file);
    }
    if (expense.remoteImageUrl != null && expense.remoteImageUrl!.isNotEmpty) {
      return NetworkImage(expense.remoteImageUrl!);
    }
    return null;
  }

  void _openImageViewer(BuildContext context, ImageProvider imageProvider) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return _GlassImageViewer(
          imageProvider: imageProvider,
          animation: anim1,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    );
  }

  Widget _buildImage(BuildContext context) {
    final imageProvider = _getImageProvider();

    if (imageProvider != null) {
      return GestureDetector(
        onTap: () => _openImageViewer(context, imageProvider),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Image(
              image: imageProvider,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 250,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Tap to zoom',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox(
      height: 250,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('No receipt image', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.grey[100],
            child: _buildImage(context),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        expense.category,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: expense.isSynced
                              ? Colors.green[50]
                              : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          expense.isSynced ? 'Synced' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: expense.isSynced
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    NumberFormat.currency(symbol: '\u20B9', decimalDigits: 2)
                        .format(expense.amount),
                    style:
                        Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                  const SizedBox(height: 16),
                  _detailRow(
                    Icons.calendar_today,
                    'Date',
                    DateFormat('MMM dd, yyyy').format(expense.date),
                  ),
                  const SizedBox(height: 12),
                  if (expense.note != null && expense.note!.isNotEmpty)
                    _detailRow(Icons.notes, 'Note', expense.note!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _GlassImageViewer extends StatefulWidget {
  final ImageProvider imageProvider;
  final Animation<double> animation;

  const _GlassImageViewer({
    required this.imageProvider,
    required this.animation,
  });

  @override
  State<_GlassImageViewer> createState() => _GlassImageViewerState();
}

class _GlassImageViewerState extends State<_GlassImageViewer> {
  final _transformController = TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(() {
      final scale = _transformController.value.getMaxScaleOnAxis();
      if (scale != _currentScale) {
        setState(() => _currentScale = scale);
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  bool get _isZoomed => _currentScale > 1.05;

  // blur increases as you zoom in
  double get _blurAmount {
    final base = 15.0 * widget.animation.value;
    final zoomFactor = (_currentScale - 1.0).clamp(0.0, 3.0);
    return base + (zoomFactor * 5);
  }

  // background gets darker as you zoom
  double get _overlayOpacity {
    final base = 0.6 * widget.animation.value;
    final zoomFactor = (_currentScale - 1.0).clamp(0.0, 2.0) * 0.1;
    return (base + zoomFactor).clamp(0.0, 0.85);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _isZoomed ? null : () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // frosted glass — blur changes with zoom level
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _blurAmount,
                sigmaY: _blurAmount,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: _overlayOpacity),
              ),
            ),
            // fullscreen zoomable image — no Center, no constraints
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 1.0,
              maxScale: 5.0,
              panEnabled: _isZoomed,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Image(
                  image: widget.imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // close button
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
