import Flutter
import Foundation
import UIKit
import ReadiumShared

class ReadiumReaderViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private weak var registrar: FlutterPluginRegistrar?

  init(registrar: FlutterPluginRegistrar?) {
    self.registrar = registrar
    super.init()
  }

  @MainActor func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        // Check if current publication is PDF
        if let publication = getCurrentPublication(),
           publication.conforms(to: .pdf) {
            return PdfReaderView(
                frame: frame,
                viewIdentifier: viewId,
                arguments: args,
                registrar: registrar!)
        }

        // Default to EPUB reader
        return ReadiumReaderView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            registrar: registrar!)
    }

  // Undocumented, but boilerplate function required for creationParams to not silently become nil!
  // https://github.com/flutter/flutter/issues/28124
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}
