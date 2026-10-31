import 'preview_frame_stub.dart'
    if (dart.library.js_interop) 'preview_frame_web.dart';

export 'preview_frame_platform.dart';

final DocumentPreviewFramePlatform documentPreviewFrame =
    createDocumentPreviewFrame();
