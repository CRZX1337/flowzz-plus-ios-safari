import SafariServices
import os.log

/// Handles messages sent from the extension's JavaScript with
/// `browser.runtime.sendNativeMessage("application.id", { ... })`.
///
/// The placeholder implementation echoes the payload back to JavaScript.
/// FreeMilk replaces the body with whatever the flowzz+ port needs — for
/// example cache lookups or shared storage — and keeps the class name, because
/// `NSExtensionPrincipalClass` in Info.plist points at it.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey]

        os_log("flowzz+ extension received a native message: %@", String(describing: message))

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["echo": message ?? NSNull()]]

        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
