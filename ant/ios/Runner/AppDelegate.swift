import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "bodyperfect/external_links",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "openDirections" {
          guard
            let args = call.arguments as? [String: Any],
            let branch = args["branch"] as? String
          else {
            result(false)
            return
          }

          let destination = self.destinationFor(branch: branch)
          let encodedDestination = destination.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
          ) ?? destination

          DispatchQueue.main.async {
            let googleUrl = URL(
              string: "comgooglemaps://?daddr=\(encodedDestination)&directionsmode=driving"
            )
            if let googleUrl = googleUrl {
              UIApplication.shared.open(googleUrl, options: [:]) { opened in
                if opened {
                  result(true)
                  return
                }

                self.openAppleMaps(destination: encodedDestination, result: result)
              }
            } else {
              self.openAppleMaps(destination: encodedDestination, result: result)
            }
          }
          return
        }

        guard call.method == "openUrl" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard
          let args = call.arguments as? [String: Any],
          let rawUrl = args["url"] as? String,
          let url = URL(string: rawUrl)
        else {
          result(false)
          return
        }

        DispatchQueue.main.async {
          UIApplication.shared.open(url, options: [:]) { opened in
            result(opened)
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openAppleMaps(destination: String, result: @escaping FlutterResult) {
    guard let appleUrl = URL(string: "http://maps.apple.com/?daddr=\(destination)&dirflg=d") else {
      result(false)
      return
    }

    UIApplication.shared.open(appleUrl, options: [:]) { opened in
      result(opened)
    }
  }

  private func destinationFor(branch: String) -> String {
    let normalized = branch
      .uppercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")

    switch normalized {
    case "MARINA", "DUBAIMARINA":
      return "Body Perfect Clinic Marina Dubai"
    case "BURJUMAN", "KARAMA", "BURDUBAI":
      return "Body Perfect Clinic BurJuman Karama Dubai"
    default:
      return "Body Perfect Clinic Dubai"
    }
  }
}
