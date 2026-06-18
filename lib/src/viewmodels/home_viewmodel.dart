import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';

class HomeViewModel extends GetxController {
  final DownloadService downloadService;

  HomeViewModel({required this.downloadService});

  // Text controller for URL input
  final urlController = TextEditingController();

  // Reactive states
  final urlText = ''.obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  // The item currently being displayed on the video preview screen
  final activePreviewItem = Rxn<DownloadItem>();

  // The item currently downloading
  final currentDownload = Rxn<DownloadItem>();

  // The download history list
  final downloadHistory = <DownloadItem>[].obs;

  // Stream subscription tracking
  StreamSubscription<double>? _downloadSubscription;

  @override
  void onInit() {
    super.onInit();
    urlController.addListener(() {
      urlText.value = urlController.text;
      if (errorMessage.value != null) {
        errorMessage.value = null;
      }
    });
  }

  @override
  void onClose() {
    urlController.dispose();
    _downloadSubscription?.cancel();
    super.onClose();
  }

  /// Clears the input field
  void clearInput() {
    urlController.clear();
  }

  /// Pastes text from clipboard
  Future<void> pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      urlController.text = clipboardData.text!;
    } else {
      Get.snackbar(
        'Clipboard Empty',
        'No text found in clipboard',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  /// Triggers the URL analysis and navigates to the Preview screen
  Future<void> startDownloadFlow() async {
    final url = urlController.text.trim();

    if (url.isEmpty) {
      errorMessage.value = 'Please enter or paste a TikTok or Instagram URL';
      return;
    }

    if (!downloadService.isValidUrl(url)) {
      errorMessage.value = 'Please enter a valid TikTok or Instagram URL';
      return;
    }

    errorMessage.value = null;
    isLoading.value = true;

    try {
      final downloadItem = await downloadService.fetchMetadata(url);
      activePreviewItem.value = downloadItem;
      isLoading.value = false;
      clearInput();
      Get.toNamed('/preview');
    } catch (e) {
      isLoading.value = false;
      errorMessage.value = e.toString().replaceAll('Exception: ', '');
      activePreviewItem.value = null;
    }
  }

  /// Initiates the download and redirects to the Downloading Screen
  void startBackgroundDownload(String quality) {
    final previewItem = activePreviewItem.value;
    if (previewItem == null) return;

    // Validate quality option exists
    if (!previewItem.qualityOptions.containsKey(quality)) {
      Get.snackbar(
        'Not Available',
        'This quality option is not available for this video.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange.withValues(alpha: 0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    // Cancel any ongoing downloads first
    _downloadSubscription?.cancel();

    final downloadItem = previewItem.copyWith(
      status: DownloadStatus.downloading,
      progress: 0.0,
    );

    currentDownload.value = downloadItem;

    // Navigate to the Downloading page
    Get.toNamed('/downloading');

    // Start listening to real progress updates
    _downloadSubscription = downloadService
        .downloadFile(downloadItem, quality)
        .listen(
      (progress) {
        if (currentDownload.value != null) {
          currentDownload.value = currentDownload.value!.copyWith(
            progress: progress,
          );
        }
      },
      onError: (err) {
        _handleDownloadFailure(err.toString());
      },
      onDone: () {
        _handleDownloadSuccess();
      },
      cancelOnError: true,
    );
  }

  /// Cancels the active download and returns to the Preview screen
  void cancelDownload() {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    currentDownload.value = null;

    Get.back();

    Get.snackbar(
      'Cancelled',
      'Download has been cancelled',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange.withValues(alpha: 0.8),
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _handleDownloadSuccess() {
    if (currentDownload.value != null) {
      final completedItem = currentDownload.value!.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
      );

      _downloadSubscription?.cancel();
      _downloadSubscription = null;

      downloadHistory.insert(0, completedItem);

      Future.delayed(const Duration(milliseconds: 800), () {
        currentDownload.value = null;
        Get.offAllNamed('/');

        Get.snackbar(
          '✅ Download Complete',
          'Saved to your Gallery → GlowLoad album',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withValues(alpha: 0.9),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
      });
    }
  }

  void _handleDownloadFailure(String error) {
    if (currentDownload.value != null) {
      final failedItem = currentDownload.value!.copyWith(
        status: DownloadStatus.failed,
      );

      _downloadSubscription?.cancel();
      _downloadSubscription = null;

      downloadHistory.insert(0, failedItem);
      currentDownload.value = null;

      Get.back();

      Get.snackbar(
        '❌ Download Failed',
        error.replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withValues(alpha: 0.8),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
      );
    }
  }

  /// Deletes an item from history
  void deleteFromHistory(String id) {
    downloadHistory.removeWhere((item) => item.id == id);
  }
}
