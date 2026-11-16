import Foundation
import UIKit
import EventKit
import EventKitUI
import MessageUI
import UserNotifications

struct IOSPhoneRequest: Decodable {
  struct Owner: Decodable { let sessionId: String; let callId: String }
  struct Action: Decodable {
    let kind: String
    let url: String?
    let title: String?
    let text: String?
    let begin: String?
    let end: String?
    let allDay: Bool?
    let location: String?
    let description: String?
    let number: String?
    let destination: String?
    let mode: String?
    // The browser tools.
    let ref: String?
    let epoch: Int?
    let key: String?
    let direction: String?
    let maxBytes: Int?
    // The phone runner's tools.
    let method: String?
    let params: String?
  }
  let v: Int
  let runId: String
  let id: String
  let owner: Owner
  let action: Action
  let expiresAt: Double
}
struct IOSPhoneOutcome {
  let text: String
  let isError: Bool
  /// A JPEG, for a tool whose answer is a picture.
  var image: Data?
  static func failure(_ text: String) -> Self { Self(text: text, isError: true) }
  static func success(_ text: String) -> Self { Self(text: text, isError: false) }
}

@MainActor
final class IOSPhoneApproval: UIViewController, UIScrollViewDelegate {
  private let heading: String
  private let detail: String
  private let allowTitle: String
  private let denyTitle: String
  private let answer: (Bool) -> Void
  private let preview: Data?
  private let notifications: NotificationCenter
  private let mayReveal: @MainActor () -> Bool
  private var contentStack: UIStackView?
  private var headingView: UILabel?
  private var detailView: UITextView?
  private var previewImageView: UIImageView?
  private var decodedPreview: UIImage?
  private var contentVisible = false
  private var lifecycleAllowsContent = true
  init(heading: String = AppLanguage.words("Allow this phone action?", "允许这一次手机动作？"), detail: String,
    allow: String = AppLanguage.words("Allow once", "允许一次"), deny: String = AppLanguage.words("Decline", "拒绝"),
       preview: Data? = nil, notifications: NotificationCenter = .default,
       mayReveal: (@MainActor () -> Bool)? = nil, answer: @escaping (Bool) -> Void) {
    self.heading = heading; self.detail = detail; self.allowTitle = allow; self.denyTitle = deny; self.answer = answer
    self.preview = preview
    self.notifications = notifications
    self.mayReveal = mayReveal ?? {
      UIApplication.shared.applicationState == .active && UIApplication.shared.isProtectedDataAvailable
    }
    super.init(nibName: nil, bundle: nil)
    modalPresentationStyle = .pageSheet
    isModalInPresentation = true
    // Selector notifications run synchronously on UIKit's lifecycle thread.
    // Do not enqueue a Task/main.async: the app-switcher snapshot may follow
    // immediately after the lifecycle callback returns.
    for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification,
                 UIApplication.protectedDataWillBecomeUnavailableNotification] {
      notifications.addObserver(self, selector: #selector(redactContent(_:)), name: name, object: nil)
    }
    for name in [UIApplication.didBecomeActiveNotification, UIApplication.protectedDataDidBecomeAvailableNotification] {
      notifications.addObserver(self, selector: #selector(restoreContentIfActive(_:)), name: name, object: nil)
    }
    for name in [UIScene.willDeactivateNotification, UIScene.didEnterBackgroundNotification] {
      notifications.addObserver(self, selector: #selector(redactSceneContent(_:)), name: name, object: nil)
    }
    notifications.addObserver(self, selector: #selector(restoreSceneContentIfActive(_:)),
      name: UIScene.didActivateNotification, object: nil)
    // On iOS 9+, selector registration does not require manual removal after
    // deallocation: NotificationCenter cleans stale entries on later delivery.
    // There is no observer block retaining this controller (iOS 15+ target).
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let title = UILabel()
    title.text = heading
    title.numberOfLines = 0
    title.font = .preferredFont(forTextStyle: .headline)
    headingView = title
    let text = UITextView()
    text.isEditable = false
    text.isSelectable = true
    text.text = detail
    text.font = .preferredFont(forTextStyle: .body)
    detailView = text
    let deny = UIButton(type: .system)
    deny.setTitle(denyTitle, for: .normal)
    deny.addAction(UIAction { [weak self] _ in self?.choose(false) }, for: .touchUpInside)
    let allow = UIButton(type: .system)
    allow.setTitle(allowTitle, for: .normal)
    allow.addAction(UIAction { [weak self] _ in self?.choose(true) }, for: .touchUpInside)
    let buttons = UIStackView(arrangedSubviews: [deny, allow])
    buttons.distribution = .fillEqually
    var rows: [UIView] = [title]
    if let preview, preview.count <= 880 * 1024, let image = UIImage(data: preview) {
      let zoom = UIScrollView()
      let picture = UIImageView(image: image)
      picture.contentMode = .scaleAspectFit
      picture.frame = CGRect(x: 0, y: 0, width: max(1, view.bounds.width - 40), height: 220)
      zoom.addSubview(picture); zoom.contentSize = picture.bounds.size
      zoom.minimumZoomScale = 1; zoom.maximumZoomScale = 8; zoom.delegate = self
      zoom.heightAnchor.constraint(equalToConstant: 220).isActive = true
      zoom.accessibilityLabel = AppLanguage.words("Numbered screenshot from the last observation; zoom to check it, not a live view", "上次观察的标号截图，可缩放核对；不是实时画面")
      decodedPreview = image
      previewImageView = picture; rows.append(zoom)
    }
    rows += [text, buttons]
    let stack = UIStackView(arrangedSubviews: rows)
    stack.axis = .vertical; stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    contentStack = stack
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      buttons.heightAnchor.constraint(equalToConstant: 48),
    ])
    refreshVisibility()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refreshVisibility()
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    refreshVisibility()
  }
  private var mayShowContentNow: Bool {
    guard mayReveal() else { return false }
    if let scene = viewIfLoaded?.window?.windowScene {
      return scene.activationState == .foregroundActive
    }
    return true
  }
  private func refreshVisibility() { setContentVisible(lifecycleAllowsContent && mayShowContentNow) }
  private func setContentVisible(_ visible: Bool) {
    contentVisible = visible
    guard isViewLoaded else { return }
    UIView.performWithoutAnimation {
      if !visible { view.endEditing(true) }
      contentStack?.isHidden = !visible
      view.accessibilityElementsHidden = !visible
      view.isUserInteractionEnabled = visible
      // Remove sensitive content from the displayed views as well as hiding
      // their common container. The original approved values remain private
      // in this controller for return to the same sheet; this is not erasure.
      headingView?.text = visible ? heading : nil
      detailView?.isSelectable = visible
      detailView?.text = visible ? detail : nil
      previewImageView?.image = visible ? decodedPreview : nil
    }
  }
  private func choose(_ allowed: Bool) {
    guard contentVisible, mayShowContentNow else { setContentVisible(false); return }
    answer(allowed)
  }
  @objc private func redactContent(_ notification: Notification) {
    lifecycleAllowsContent = false
    setContentVisible(false)
  }
  @objc private func restoreContentIfActive(_ notification: Notification) {
    if mayShowContentNow { lifecycleAllowsContent = true }
    refreshVisibility()
  }
  private func concernsThisScene(_ notification: Notification) -> Bool {
    guard let ownScene = viewIfLoaded?.window?.windowScene else { return true }
    return (notification.object as? UIScene) === ownScene
  }
  @objc private func redactSceneContent(_ notification: Notification) {
    guard concernsThisScene(notification) else { return }
    redactContent(notification)
  }
  @objc private func restoreSceneContentIfActive(_ notification: Notification) {
    guard concernsThisScene(notification) else { return }
    restoreContentIfActive(notification)
  }
  func viewForZooming(in scrollView: UIScrollView) -> UIView? { previewImageView }
}

@MainActor
final class IOSPhoneActions: NSObject, EKEventEditViewDelegate, MFMessageComposeViewControllerDelegate {
  private let presenter: () -> UIViewController?
  private var requestId: String?
  private var confirmationID: UUID?
  private var confirmationAnswered = false
  private var modal: UIViewController?
  private var answer: ((IOSPhoneOutcome) -> Void)?
  private var calendarStore: EKEventStore?
  init(presenter: @escaping () -> UIViewController?) { self.presenter = presenter }

  func cancel(_ id: String) {
    guard requestId == id else { return }
    requestId = nil
    confirmationID = nil
    confirmationAnswered = true
    calendarStore = nil
    finish(.failure(AppLanguage.words("The original task was cancelled or the engine changed; this old confirmation can no longer run.", "原任务已取消或引擎已更换，旧确认不能再执行。")))
  }
  private func finish(_ value: IOSPhoneOutcome) {
    let callback = answer
    answer = nil
    let old = modal; modal = nil
    if let old, old.presentingViewController != nil {
      old.dismiss(animated: true) { callback?(value) }
    } else { callback?(value) }
  }
  private func present(_ controller: UIViewController) async -> IOSPhoneOutcome {
    guard let host = presenter(), host.viewIfLoaded?.window != nil, host.presentedViewController == nil else {
      return .failure(AppLanguage.words("The confirmation screen is unavailable right now; come back to DSH Go and have the user start again.", "确认界面当前不可用，请回到 DSH Go 后由用户重新发起。"))
    }
    return await withCheckedContinuation { continuation in
      modal = controller
      answer = { continuation.resume(returning: $0) }
      host.present(controller, animated: true)
    }
  }
  private var foreground: Bool {
    UIApplication.shared.applicationState == .active && UIApplication.shared.isProtectedDataAvailable
  }
  func run(_ request: IOSPhoneRequest, current: @escaping () -> Bool,
           authorize: @escaping () async -> Bool, validate: @escaping () async -> Bool) async -> IOSPhoneOutcome {
    guard foreground, current(), request.expiresAt > Date().timeIntervalSince1970 * 1000 else {
      return .failure(AppLanguage.words("Unlock the phone and open DSH Go first; background or expired actions are not performed.", "请先解锁并打开 DSH Go；后台或已过期的动作不执行。"))
    }
    requestId = request.id
    let confirmation = UUID(); confirmationID = confirmation; confirmationAnswered = false
    defer { if confirmationID == confirmation { confirmationID = nil; requestId = nil; calendarStore = nil } }
    let detail: String
    do { detail = try describe(request.action) } catch { return .failure(AppLanguage.words("The phone action arguments are invalid or iOS does not support it.", "手机动作参数无效或 iOS 不支持。")) }
    let controller = IOSPhoneApproval(detail: detail) { [weak self] allowed in
      guard let self, self.requestId == request.id, self.confirmationID == confirmation,
        !self.confirmationAnswered else { return }
      self.confirmationAnswered = true
      self.finish(allowed ? .success("allowed-once") : .failure(AppLanguage.words("The user declined this step; do not retry the same action automatically.", "用户拒绝了这一步；不要自动重试同一个动作。")))
    }
    let expiry = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 30_000_000_000)
      guard !Task.isCancelled, let self, self.requestId == request.id, self.modal === controller else { return }
      self.finish(.failure(AppLanguage.words("The user did not choose within the confirmation time; no action was performed.", "用户未在确认时间内选择；未执行动作。")))
    }
    let choice = await present(controller)
    expiry.cancel()
    guard !choice.isError else { return choice }
    // The Node-side invocation must still own this exact request AFTER the real tap.
    guard requestId == request.id, confirmationID == confirmation, current(), foreground, await authorize(),
      requestId == request.id, confirmationID == confirmation, current(), foreground else {
      return .failure(AppLanguage.words("The original task for this confirmation has ended; no action was performed.", "确认对应的原任务已经结束，未执行动作。"))
    }
    return await perform(request.action, id: request.id, validate: validate)
  }
  /// The same real sheet, for a tool that decides what happens after the answer itself.
  func confirm(
    _ request: IOSPhoneRequest, title: String, detail: String,
    allow: String = AppLanguage.words("Allow once", "允许一次"), deny: String = AppLanguage.words("Decline", "拒绝"),
    waitsForever: Bool = false, preview: Data? = nil
  ) async -> Bool {
    guard foreground else { return false }
    requestId = request.id
    let confirmation = UUID(); confirmationID = confirmation; confirmationAnswered = false
    defer { if confirmationID == confirmation { confirmationID = nil; requestId = nil } }
    let controller = IOSPhoneApproval(heading: title, detail: detail, allow: allow, deny: deny, preview: preview) { [weak self] allowed in
      guard let self, self.requestId == request.id, self.confirmationID == confirmation,
        !self.confirmationAnswered else { return }
      self.confirmationAnswered = true
      self.finish(allowed ? .success("allowed-once") : .failure("declined"))
    }
    let expiry = Task { [weak self] in
      if waitsForever { return }
      try? await Task.sleep(nanoseconds: 30_000_000_000)
      guard !Task.isCancelled, let self, self.requestId == request.id, self.modal === controller else { return }
      self.finish(.failure("timed-out"))
    }
    let choice = await present(controller)
    expiry.cancel()
    return !choice.isError && requestId == request.id && confirmationID == confirmation && foreground
  }
  private func required(_ value: String?, max: Int = 8192) throws -> String {
    guard let value, !value.isEmpty, value.utf8.count <= max, !value.contains("\0") else { throw CocoaError(.coderInvalidValue) }
    return value
  }
  private func safeURL(_ value: String?) throws -> URL {
    guard let url = URL(string: try required(value, max: 2048)),
      ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
      url.user == nil, url.password == nil else { throw CocoaError(.coderInvalidValue) }
    return url
  }
  private func phoneNumber(_ value: String?) throws -> String {
    let value = try required(value, max: 100)
    guard value.range(of: #"^[+0-9 ()-]+$"#, options: .regularExpression) != nil,
      value.range(of: "[0-9]", options: .regularExpression) != nil else { throw CocoaError(.coderInvalidValue) }
    return value
  }
  private func date(_ value: String) -> Date? {
    let value = value.replacingOccurrences(of: " ", with: "T")
    if let instant = ISO8601DateFormatter().date(from: value) { return instant }
    for format in ["yyyy-MM-dd'T'HH:mm:ssXXX", "yyyy-MM-dd'T'HH:mmXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.timeZone = .current
      formatter.dateFormat = format
      formatter.isLenient = false
      if let result = formatter.date(from: value) { return result }
    }
    return nil
  }
  private func calendarDates(_ a: IOSPhoneRequest.Action) throws -> (Date, Date, Bool) {
    let beginText = try required(a.begin, max: 100)
    guard let begin = date(beginText) else { throw CocoaError(.coderInvalidValue) }
    let allDay = a.allDay ?? (beginText.count == 10)
    let end: Date
    if let endText = a.end {
      guard let parsed = date(endText) else { throw CocoaError(.coderInvalidValue) }; end = parsed
    } else { end = begin.addingTimeInterval(allDay ? 86400 : 3600) }
    guard end >= begin else { throw CocoaError(.coderInvalidValue) }
    return (begin, end, allDay)
  }
  private func describe(_ a: IOSPhoneRequest.Action) throws -> String {
    switch a.kind {
    case "open": return AppLanguage.words(
      "Open URL (only asks the system to open it; this does not mean the page operation is done):\n\(try safeURL(a.url).absoluteString)",
      "打开网址（只请求系统打开，不代表已完成网页中的操作）：\n\(try safeURL(a.url).absoluteString)")
    case "clipboard-get": return AppLanguage.words(
      "Read the current clipboard text and send it to this model conversation. The clipboard may contain private information; the system may also ask for paste permission.",
      "读取当前剪贴板文字并发送给本次模型会话。剪贴板可能含私人信息；系统还可能询问粘贴权限。")
    case "clipboard-set":
      guard let value = a.text, value.utf8.count <= 8192, !value.contains("\0") else { throw CocoaError(.coderInvalidValue) }
      return AppLanguage.words("Replace the clipboard with the following full text:\n\(value)", "用以下全文替换剪贴板：\n\(value)")
    case "notify": return AppLanguage.words(
      "Post a local notification from this app:\nTitle: \(try required(a.title, max: 256))\nBody: \(try required(a.text))\nTapping the notification only opens the app; it does not approve anything else.",
      "发布本 App 的本地通知：\n标题：\(try required(a.title, max: 256))\n正文：\(try required(a.text))\n点通知只打开 App，不批准其他操作。")
    case "dial": return AppLanguage.words(
      "Open the system dial confirmation: \(try phoneNumber(a.number))\nThe system may ask again to confirm the call; it is not confirmed automatically.",
      "打开系统拨号确认：\(try phoneNumber(a.number))\n系统可能再要求确认呼叫，不自动确认。")
    case "sms-draft":
      let recipient = try a.number.map { try phoneNumber($0) } ?? AppLanguage.words("chosen by the user", "由用户选择")
      return AppLanguage.words(
        "Open an SMS draft; the user taps send in the end:\nRecipient: \(recipient)\nFull text: \(try required(a.text))",
        "打开短信草稿，最终由用户点发送：\n收件人：\(recipient)\n全文：\(try required(a.text))")
    case "share": return AppLanguage.words(
      "Open the system share sheet; the user chooses the target and completes the share:\n\(try required(a.text))",
      "打开系统分享面板，由用户选择目标并完成分享：\n\(try required(a.text))")
    case "settings": return AppLanguage.words(
      "Open this app's system settings page in DSH Go; no settings will be changed.",
      "打开 DSH Go 本 App 的系统设置页；不会更改任何设置。")
    case "navigate":
      guard ["drive", "walk", "transit"].contains(a.mode ?? "") else { throw CocoaError(.coderInvalidValue) }
      return AppLanguage.words(
        "Open a directions request in Apple Maps; the user checks the destination and starts navigation:\nDestination: \(try required(a.destination, max: 1024))\nMode: \(a.mode!)",
        "在 Apple Maps 打开路线请求，由用户核对目的地并开始导航：\n目的地：\(try required(a.destination, max: 1024))\n方式：\(a.mode!)")
    case "calendar":
      let (begin, end, allDay) = try calendarDates(a)
      if let location = a.location { _ = try required(location, max: 1024) }
      if let description = a.description { _ = try required(description) }
      return AppLanguage.words(
        "Open the system calendar editor for the user to review and save:\nTitle: \(try required(a.title, max: 256))\nStart: \(begin)\nEnd: \(end)\nAll day: \(allDay)\nLocation: \(a.location ?? "")\nNotes: \(a.description ?? "")",
        "打开系统日程编辑器，由用户检查并保存：\n标题：\(try required(a.title, max: 256))\n开始：\(begin)\n结束：\(end)\n全天：\(allDay)\n地点：\(a.location ?? "")\n备注：\(a.description ?? "")")
    default: throw CocoaError(.coderInvalidValue)
    }
  }
  private func open(_ url: URL) async -> IOSPhoneOutcome {
    let accepted = await withCheckedContinuation { continuation in
      UIApplication.shared.open(url, options: [:]) { continuation.resume(returning: $0) }
    }
    return accepted
      ? .success(AppLanguage.words("The system accepted the open request; this does not mean the operation in the target app is done.", "系统已接受打开请求；不表示已完成目标 App 中的操作。"))
      : .failure(AppLanguage.words("The system cannot open that target.", "系统无法打开该目标。"))
  }
  private func perform(_ a: IOSPhoneRequest.Action, id: String, validate: () async -> Bool) async -> IOSPhoneOutcome {
    do {
      switch a.kind {
      case "open": return await open(try safeURL(a.url))
      case "settings": return await open(URL(string: UIApplication.openSettingsURLString)!)
      case "dial":
        let value = try phoneNumber(a.number).replacingOccurrences(of: "[ ()-]", with: "", options: .regularExpression)
        return await open(URL(string: "tel:" + value)!)
      case "clipboard-set": UIPasteboard.general.string = a.text!; return .success(AppLanguage.words("Written to the clipboard.", "已写入剪贴板。"))
      case "clipboard-get":
        let value = UIPasteboard.general.string ?? ""
        guard value.utf8.count <= 8192 else { return .failure(AppLanguage.words("The clipboard exceeds 8192 UTF-8 bytes; it was not sent to the model.", "剪贴板超过 8192 UTF-8 字节，本次未发送给模型。")) }
        return .success(value)
      case "notify":
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return .failure(AppLanguage.words("The user did not grant notification permission.", "用户未授予通知权限。")) }
        guard requestId == id, foreground, await validate(), requestId == id, foreground else {
          return .failure(AppLanguage.words("The original task was cancelled, expired, or the app went to the background.", "原任务已取消、已过期或 App 已进入后台。"))
        }
        let content = UNMutableNotificationContent(); content.title = a.title!; content.body = a.text!
        // No category/action identifiers: a notification tap is navigation, never authority.
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        return .success(AppLanguage.words("Local notification submitted; whether it is shown depends on the system notification settings.", "已提交本地通知；是否显示由系统通知设置决定。"))
      case "navigate":
        var components = URLComponents(string: "https://maps.apple.com/")!
        let flag = ["drive": "d", "walk": "w", "transit": "r"][a.mode!]!
        components.queryItems = [URLQueryItem(name: "daddr", value: a.destination!), URLQueryItem(name: "dirflg", value: flag)]
        return await open(components.url!)
      case "share":
        let controller = UIActivityViewController(activityItems: [a.text!], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = presenter()?.view
        controller.completionWithItemsHandler = { [weak self, weak controller] _, completed, _, _ in
          guard let self, let controller, self.modal === controller, self.requestId == id else { return }
          self.finish(completed
            ? .success(AppLanguage.words("The user completed the system share.", "用户已完成系统分享操作。"))
            : .failure(AppLanguage.words("The user cancelled the share.", "用户取消了分享。")))
        }
        return await present(controller)
      case "sms-draft":
        guard MFMessageComposeViewController.canSendText() else { return .failure(AppLanguage.words("This device cannot send SMS right now.", "此设备当前不能发送短信。")) }
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = self; controller.body = a.text!
        controller.recipients = a.number.map { [$0] }
        return await present(controller)
      case "calendar":
        let store = EKEventStore(); calendarStore = store
        if #available(iOS 17.0, *) {
          // iOS 17+ EventKitUI's editor requires no broad calendar access.
        } else {
          let granted = await withCheckedContinuation { continuation in
            store.requestAccess(to: .event) { allowed, _ in continuation.resume(returning: allowed) }
          }
          guard granted else { return .failure(AppLanguage.words("The user did not grant the calendar permission older iOS requires.", "用户未授予旧版 iOS 所需的日历权限。")) }
        }
        guard requestId == id, foreground, await validate(), requestId == id, foreground else {
          return .failure(AppLanguage.words("The original task was cancelled, expired, or the app went to the background.", "原任务已取消、已过期或 App 已进入后台。"))
        }
        let (begin, end, allDay) = try calendarDates(a)
        let event = EKEvent(eventStore: store)
        event.title = a.title!; event.startDate = begin; event.endDate = end; event.isAllDay = allDay
        event.location = a.location; event.notes = a.description
        let controller = EKEventEditViewController()
        controller.eventStore = store; controller.event = event; controller.editViewDelegate = self
        return await present(controller)
      default: return .failure(AppLanguage.words("iOS does not support this phone action.", "iOS 不支持该手机动作。"))
      }
    } catch { return .failure(AppLanguage.words("The system did not complete the phone action; ask the user to check, and do not retry automatically.", "系统未完成手机动作；请用户检查，不要自动重试。")) }
  }
  func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    guard modal === controller else { return }
    finish(action == .saved
      ? .success(AppLanguage.words("The user saved the event in the system editor.", "用户已在系统编辑器保存日程。"))
      : .failure(AppLanguage.words("The user cancelled editing the event.", "用户取消了日程编辑。")))
  }
  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    guard modal === controller else { return }
    finish(result == .sent
      ? .success(AppLanguage.words("The system reports the SMS was sent; delivery is not guaranteed.", "系统报告短信已发送；不保证已送达。"))
      : .failure(AppLanguage.words("The SMS draft was cancelled or sending failed.", "短信草稿已取消或发送失败。")))
  }
}
