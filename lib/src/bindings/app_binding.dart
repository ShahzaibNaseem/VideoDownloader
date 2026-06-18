import 'package:get/get.dart';
import '../services/download_service.dart';
import '../viewmodels/home_viewmodel.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // Inject DownloadService (lazy loaded, singleton)
    Get.lazyPut<DownloadService>(() => DownloadService(), fenix: true);
    
    // Inject HomeViewModel (lazy loaded)
    Get.lazyPut<HomeViewModel>(() => HomeViewModel(downloadService: Get.find<DownloadService>()));
  }
}
