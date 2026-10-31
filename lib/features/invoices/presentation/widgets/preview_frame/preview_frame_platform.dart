import 'package:flutter/widgets.dart';

abstract class DocumentPreviewFramePlatform {
  Widget buildFrame({
    required BuildContext context,
    required String? htmlContent,
    required bool isThermal,
    required bool isLoading,
  });

  Future<void> printDocument(String? htmlContent);
}
