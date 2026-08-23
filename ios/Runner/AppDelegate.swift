import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Escopo de segurança das pastas escolhidas pelo UIDocumentPicker
    // (file_picker.getDirectoryPath, usado no download em lote do cofre).
    // O file_picker 8.3.7 NÃO faz startAccessingSecurityScopedResource na
    // URL devolvida — sem o escopo, gravar numa pasta fora do sandbox do
    // app falha com EPERM; sem o stop, o app vaza recurso do kernel e pode
    // perder a capacidade de adicionar locais ao sandbox até reiniciar.
    let channel = FlutterMethodChannel(
      name: "bmo/security_scoped",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "startAccessing":
        guard let path = call.arguments as? String else {
          result(false)
          return
        }
        // Dentro do container do app a URL não é security-scoped: acesso
        // direto (fallback pré-iOS 13 do file_picker).
        if path.hasPrefix(NSHomeDirectory()) {
          result(true)
          return
        }
        let url = URL(fileURLWithPath: path)
        result(url.startAccessingSecurityScopedResource())
      case "stopAccessing":
        guard let path = call.arguments as? String else {
          result(nil)
          return
        }
        if !path.hasPrefix(NSHomeDirectory()) {
          let url = URL(fileURLWithPath: path)
          url.stopAccessingSecurityScopedResource()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Recarga SOB DEMANDA do widget: chamada pelo app não consome o
    // orçamento diário do WidgetKit (só o refresh automático da timeline
    // consome). O Dart dispara quando uma luz muda via WebSocket (debounce)
    // e quando o app vai pro background. Na web é no-op (canal inexistente).
    let widgetChannel = FlutterMethodChannel(
      name: "bmo/widget_reload",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    widgetChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "reloadTimelines":
        // Runner roda com deployment 13.0; WidgetCenter é iOS 14+.
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
