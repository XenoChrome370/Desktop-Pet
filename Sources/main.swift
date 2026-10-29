import AppKit
import AVFoundation
import UniformTypeIdentifiers

// Interaction and playback design adapted from SunPet (MIT); see LICENSE-SunPet.
struct Clip: Codable {
    let id: Int
    let label: String
    let file: String
    let duration: Double
}

/// Random pool that does not repeat within one cycle.
/// Stores clip.id rather than an index: clips can be unchecked from the rotation,
/// and indices would all shift as soon as the pool changes.
struct ShuffleBag {
    var remaining: [Int] = []
    var last: Int?
    mutating func next(from ids: [Int]) -> Int? {
        guard !ids.isEmpty else { return nil }
        remaining.removeAll { !ids.contains($0) }
        if remaining.isEmpty {
            remaining = ids.shuffled()
            if ids.count > 1, remaining.last == last { remaining.swapAt(0, ids.count - 1) }
        }
        let value = remaining.removeLast()
        last = value
        return value
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class PassiveImage: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
final class PassiveLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Caption bubble shown above the pet.
///
/// On macOS 26 and newer the background is a real Liquid Glass effect
/// (`NSGlassEffectView`); older systems keep the previous translucent black
/// rounded rectangle. The label is centered in both axes by sizing it to the
/// text and centering that frame inside the bubble. NSTextField draws wrapped
/// text from the top of its cell, which is why the old caption sat visibly
/// high in its 34pt box.
final class CaptionBubble: NSView {
    let label = PassiveLabel(labelWithString: "")
    private var glass: NSView?
    private let minimumRadius: CGFloat = 11

    var stringValue: String {
        get { label.stringValue }
        set {
            label.stringValue = newValue
            needsLayout = true
            superview?.needsLayout = true
        }
    }

    /// Width needed to show the caption on one line, capped at `maximum`.
    /// A short Chinese caption should not stretch into a full-width bar.
    func fittingWidth(for maximum: CGFloat) -> CGFloat {
        let size = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: 10_000, height: 100)) ?? .zero
        return min(maximum, max(72, ceil(size.width) + 30))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.usesSingleLineMode = true
        label.cell?.wraps = false
        label.cell?.isScrollable = false
        // A soft shadow keeps the white text legible on light glass.
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        label.shadow = shadow

        if #available(macOS 26.0, *) {
            let effect = NSGlassEffectView()
            effect.style = .regular
            effect.cornerRadius = minimumRadius
            // White text needs a dark tint to stay readable over light wallpapers.
            effect.tintColor = NSColor.black.withAlphaComponent(0.48)
            // Arbitrary subviews have no guaranteed z-order over the glass, so the
            // label must be the glass content view rather than a sibling.
            effect.contentView = label
            addSubview(effect)
            glass = effect
        } else {
            layer?.backgroundColor = NSColor.black.withAlphaComponent(0.76).cgColor
            layer?.cornerRadius = minimumRadius
            addSubview(label)
        }
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Clicks on the caption must reach the pet below it.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        let radius = max(minimumRadius, bounds.height / 2)
        if #available(macOS 26.0, *), let effect = glass as? NSGlassEffectView {
            effect.frame = bounds
            effect.cornerRadius = radius
        } else {
            layer?.cornerRadius = radius
        }

        let horizontalInset: CGFloat = 12
        let verticalInset: CGFloat = 5
        let content = NSRect(x: horizontalInset, y: verticalInset,
                             width: max(1, bounds.width - horizontalInset * 2),
                             height: max(1, bounds.height - verticalInset * 2))
        let needed = label.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: content.width, height: 10_000)) ?? .zero
        let textHeight = min(ceil(max(needed.height, 1)), content.height)
        label.frame = NSRect(x: content.minX,
                             y: content.minY + (content.height - textHeight) / 2,
                             width: content.width, height: textHeight)
    }
}

final class PetView: NSView {
    weak var owner: AppDelegate?
    let face = PassiveImage()
    let caption = CaptionBubble()
    var initialMouse = NSPoint.zero
    var initialWindow = NSPoint.zero
    var dragged = false
    var animationTimer: Timer?
    var phase = 0.0
    var speaking = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        face.imageScaling = .scaleProportionallyUpOrDown
        face.wantsLayer = true
        addSubview(face)
        addSubview(caption)
        toolTip = "Click to play a random clip · Drag to move · Right-click for settings"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("GoodThing Pet. Click to play a random clip, drag to move, right-click for settings.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layout() {
        super.layout()
        face.frame = NSRect(x: 8, y: 8, width: bounds.width - 16, height: bounds.height - 52)
        let maximumCaptionWidth = max(72, bounds.width - 12)
        let captionWidth = caption.fittingWidth(for: maximumCaptionWidth)
        caption.frame = NSRect(x: (bounds.width - captionWidth) / 2, y: bounds.height - 37,
                               width: captionWidth, height: 32)
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        initialMouse = window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        initialWindow = window?.frame.origin ?? .zero
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        let current = window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        let dx = current.x - initialMouse.x, dy = current.y - initialMouse.y
        if hypot(dx, dy) > 4 { dragged = true }
        if dragged { window?.setFrameOrigin(NSPoint(x: initialWindow.x + dx, y: initialWindow.y + dy)) }
    }
    override func mouseUp(with event: NSEvent) {
        if dragged { owner?.savePosition() } else { owner?.playNext() }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = owner?.makeMenu() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    override func accessibilityPerformPress() -> Bool { owner?.playNext(); return true }
    func animate(_ enabled: Bool) {
        speaking = enabled
        animationTimer?.invalidate(); animationTimer = nil
        phase = 0
        face.layer?.transform = CATransform3DIdentity
        guard enabled, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.60
            // Compress vertically by up to 12%, then return to the original height.
            let heightScale = 1.0 - 0.12 * (1.0 - cos(self.phase)) / 2.0
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.face.layer?.transform = CATransform3DMakeScale(1.0, heightScale, 1.0)
            CATransaction.commit()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate {
    var panel: PetPanel!
    var pet: PetView!
    var status: NSStatusItem!
    var player: AVAudioPlayer?
    var clips: [Clip] = []
    var bag = ShuffleBag()
    var lastPlayed: Int?
    var randomMode = true
    var pinnedID: Int?
    /// IDs of clips excluded from the rotation
    var excludedIDs: Set<Int> = []
    var captionWork: DispatchWorkItem?
    var volume: Float = 0.65
    var size: CGFloat = 260
    var imageRatio: CGFloat = 1
    /// The pet face, kept so it can also be drawn in the menu bar.
    var faceImage: NSImage?
    /// Menu bar icon: "face" (default), "text", or "custom".
    var statusIconMode = "face"
    var statusIconPath: String?
    // Companion chain: Shaolan starts → SunPet → FengGe → SunPet.
    // peers is "who I listen to". FengGe listens only to SunPet, and only joins a
    // chain started by Shaolan; see startBridge.
    let bridge = PetBridge(me: .fengge, peers: [.sunpet])
    var bridgeStatus = "Link: listening to SunPet"

    // Machinery for replying. Same logic as the SunPet and Shaolan copies;
    // only the entry condition differs.
    var companionPool: [Clip] = []
    var companionBag: [Clip] = []
    var companionPlayers: [Int: AVAudioPlayer] = [:]
    var companionLead: [Int: TimeInterval] = [:]
    var companionWork: DispatchWorkItem?
    let companionOverlap: TimeInterval = 0.3
    let selfTest = CommandLine.arguments.contains("--self-test")
    /// Link self-test: really play a clip and see whether the other pet replies.
    /// Used to test the channel; not passed during normal use.
    let bridgeTest = CommandLine.arguments.contains("--bridge-test")
    let defaults = UserDefaults.standard
    /// With --trace, print each link hop's time, hop count and overlap to stdout
    /// so the four-step chain timing can be checked.
    let trace = CommandLine.arguments.contains("--trace")
    func traceLog(_ text: String) {
        guard trace else { return }
        print("[FENGGE] \(String(format: "%.3f", Date().timeIntervalSince1970)) \(text)")
        fflush(stdout)
    }
    var resources: URL { Bundle.main.resourceURL! }
    var panelSize: NSSize { NSSize(width: size, height: (size - 16) * imageRatio + 52) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // --dump-state is a diagnostic flag: it creates no window and must not be
        // blocked by the single-instance check.
        let dumpState = CommandLine.arguments.contains("--dump-state")
        if !selfTest && !bridgeTest && !dumpState, let id = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0.processIdentifier != getpid() }
            if !others.isEmpty { NSApp.terminate(nil); return }
        }
        let image: NSImage
        do {
            clips = try JSONDecoder().decode([Clip].self, from: Data(contentsOf: resources.appendingPathComponent("clips.json")))
            guard !clips.isEmpty, let face = NSImage(contentsOf: resources.appendingPathComponent("face.png")), face.size.width > 0 else {
                throw NSError(domain: "Missing assets", code: 1)
            }
            for clip in clips {
                guard FileManager.default.fileExists(atPath: resources.appendingPathComponent("Clips/\(clip.file)").path) else {
                    throw NSError(domain: "Missing audio: \(clip.file)", code: 2)
                }
            }
            image = face
        } catch {
            if selfTest { print("FAIL: \(error)"); exit(1) }
            let alert = NSAlert(); alert.messageText = "Could not load the pet assets"; alert.informativeText = error.localizedDescription
            alert.runModal(); NSApp.terminate(nil); return
        }
        imageRatio = image.size.height / image.size.width
        faceImage = image
        if let mode = defaults.string(forKey: "statusIconMode"), ["face", "text", "custom"].contains(mode) {
            statusIconMode = mode
        }
        statusIconPath = defaults.string(forKey: "statusIconPath")
        if defaults.object(forKey: "volume") != nil { volume = min(max(defaults.float(forKey: "volume"), 0), 1) }
        if defaults.object(forKey: "size") != nil { size = min(max(CGFloat(defaults.double(forKey: "size")), 160), 400) }
        if defaults.object(forKey: "randomMode") != nil { randomMode = defaults.bool(forKey: "randomMode") }
        if defaults.object(forKey: "pinnedID") != nil { pinnedID = defaults.integer(forKey: "pinnedID") }
        // Note: defaults.array returns [Any] holding NSNumber; casting directly to
        // [Int] fails. Read each item with intValue. Learned the hard way: values
        // were written but could not be read back.
        if let raw = defaults.array(forKey: "excludedIDs") {
            excludedIDs = Set(raw.compactMap { entry -> Int? in
                if let number = entry as? NSNumber { return number.intValue }
                if let text = entry as? String { return Int(text) }
                return nil
            })
        }
        if !randomMode && !pinValid() { randomMode = true }
        if CommandLine.arguments.contains("--dump-state") {
            let pin = pinnedID.map { String($0) } ?? "nil"
            print("mode=\(randomMode ? "random" : "fixed") pinned=\(pin) valid=\(pinValid()) excluded=\(excludedIDs.sorted()) clips=\(clips.count) pool=\(clips.count - excludedIDs.count)")
            exit(0)
        }
        panel = PetPanel(contentRect: NSRect(origin: .zero, size: panelSize), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "GoodThing Pet"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        pet = PetView(frame: NSRect(origin: .zero, size: panelSize)); pet.owner = self
        pet.face.image = image; panel.contentView = pet
        restorePosition()
        panel.orderFrontRegardless()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self; status.button?.action = #selector(openStatusMenu)
        applyStatusIcon()
        updateToolTip()
        // All 11 clips are pure reactions and can follow anyone, so no filtering is needed.
        companionPool = clips
        preloadCompanionClips()
        if selfTest { runSelfTest() } else if bridgeTest { startBridge(); runBridgeTest() } else { startBridge(); showCaption("Click me · Right-click", seconds: 5) }
    }

    // MARK: - Companion link

    func runBridgeTest() {
        showCaption("Link self-test: playing in 3 seconds", seconds: 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("peer=\(self.bridge.peerIsRunning) status=\(self.bridgeStatus) clips=\(self.clips.count)")
            fflush(stdout)
            if let first = self.clips.first { self.play(first) }
            print("spoke announced at \(Date().timeIntervalSince1970)")
            fflush(stdout)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { exit(0) }
        }
    }

    func startBridge() {
        // FengGe only replies inside a chain started by Shaolan; that is what root is for:
        //   Shaolan (root=shaolan) → SunPet → FengGe → SunPet
        // When the user clicks FengGe directly, root is fengge, so it answers once and stops
        // instead of dragging FengGe back into the chain.
        bridge.onSpoke = { [weak self] from, duration, _, _, hop, root in
            guard let self else { return }
            let willTake = from == .sunpet && root == .shaolan && hop < 3
            let why = willTake ? "replying" : (hop >= 3 ? "chain is over" : "chain was not started by Shaolan")
            self.traceLog("heard \(from.title) hop=\(hop) root=\(root.title) — \(why)")
            guard from == .sunpet, root == .shaolan else { return }
            self.scheduleCompanion(after: duration, hop: hop, root: root)
        }
        bridge.onPresenceChange = { [weak self] present in
            guard let self else { return }
            self.bridgeStatus = present ? "Link: listening to SunPet" : "Link: SunPet not running"
        }
        bridge.start()
        bridgeStatus = bridge.peerIsRunning ? "Link: listening to SunPet" : "Link: SunPet not running"
    }

    /// Schedule one reply after the previous hop finishes speaking.
    func scheduleCompanion(after duration: TimeInterval, hop: Int, root: PetRole) {
        guard !selfTest else { return }
        // Stop at the fourth hop: Shaolan 0 → SunPet 1 → FengGe 2 → SunPet 3 → stop
        guard hop < 3 else { return }
        companionWork?.cancel()
        guard let clip = takeCompanionClip() else { return }
        let lead = companionLead[clip.id] ?? 0
        // The second hop (SunPet handing back to FengGe) is tightened by 0.1s so the
        // four steps do not drag.
        let overlap = hop == 1 ? max(0.05, companionOverlap - 0.1) : companionOverlap
        let delay = max(0.02, duration - overlap - lead)
        traceLog("scheduled reply hop=\(hop) root=\(root.title) overlap=\(String(format: "%.2f", overlap)) wait=\(String(format: "%.2f", delay)) clip=\(clip.id)")
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Do not stack on top of our own voice; skip this reply if we are still talking.
            guard self.player?.isPlaying != true else { return }
            self.traceLog("speaking hop=\(hop + 1) clip=\(clip.id) \(clip.label)")
            self.playCompanion(clip, hop: hop + 1, root: root)
        }
        companionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func takeCompanionClip() -> Clip? {
        if companionBag.isEmpty { companionBag = companionPool.shuffled() }
        return companionBag.popLast()
    }

    func playCompanion(_ clip: Clip, hop: Int, root: PetRole) {
        // Start from a pre-decoded player to skip the tens of milliseconds spent
        // reading and decoding the file.
        if let ready = companionPlayers[clip.id] {
            player?.stop()
            player = ready
            ready.currentTime = 0
            ready.volume = volume
            if ready.play() {
                lastPlayed = clip.id
                pet.animate(true)
                showCaption(clip.label, seconds: ready.duration + 0.5)
                if !selfTest { bridge.announceSpeaking(clipID: clip.id, duration: ready.duration, label: clip.label, hop: hop, root: root) }
                return
            }
        }
        play(clip, hop: hop, root: root)
    }

    func preloadCompanionClips() {
        for clip in companionPool {
            let url = resources.appendingPathComponent("Clips/\(clip.file)")
            guard let audio = try? AVAudioPlayer(contentsOf: url) else { continue }
            audio.delegate = self
            audio.volume = volume
            audio.prepareToPlay()
            companionPlayers[clip.id] = audio
            companionLead[clip.id] = leadingSilence(of: url)
        }
    }

    /// How much silence this clip has at the start. The threshold is a percentage of
    /// the peak so background noise is not mistaken for speech.
    func leadingSilence(of url: URL) -> TimeInterval {
        guard let file = try? AVAudioFile(forReading: url) else { return 0 }
        let rate = file.processingFormat.sampleRate
        let want = AVAudioFrameCount(min(file.length, AVAudioFramePosition(rate * 0.6)))
        guard want > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: want) else { return 0 }
        do { try file.read(into: buffer) } catch { return 0 }
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var peak: Float = 0
        for i in 0..<count { peak = max(peak, abs(channel[i])) }
        let threshold = max(0.004, peak * 0.06)
        for i in 0..<count where abs(channel[i]) > threshold {
            return Double(i) / rate
        }
        return 0
    }
    func restorePosition() {
        if defaults.object(forKey: "petX") != nil {
            let origin = NSPoint(x: defaults.double(forKey: "petX"), y: defaults.double(forKey: "petY"))
            let rect = NSRect(origin: origin, size: panelSize)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersection(rect).width >= 80 && $0.visibleFrame.intersection(rect).height >= 80 }) {
                panel.setFrameOrigin(origin); return
            }
        }
        placeAtCorner()
    }
    func placeAtCorner() {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - panelSize.width - 32, y: screen.visibleFrame.minY + 24))
    }
    /// After a size change the window can hang off the screen edge. Pull it back
    /// so the pet stays clickable instead of growing out of the display.
    func keepOnScreen() {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        var origin = panel.frame.origin
        origin.x = min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - panelSize.width))
        origin.y = min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - panelSize.height))
        if origin != panel.frame.origin { panel.setFrameOrigin(origin) }
    }
    func savePosition() {
        guard !selfTest, let panel else { return }
        defaults.set(panel.frame.origin.x, forKey: "petX"); defaults.set(panel.frame.origin.y, forKey: "petY")
    }
    @objc func resetPosition() { placeAtCorner(); savePosition() }
    @objc func openStatusMenu() { status.menu = makeMenu(); status.button?.performClick(nil); status.menu = nil }
    func item(_ title: String, _ action: Selector?, tag: Int = 0) -> NSMenuItem {
        let result = NSMenuItem(title: title, action: action, keyEquivalent: "")
        result.target = self; result.tag = tag; return result
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let title = item("GoodThing Pet · \(clips.count) voice clips", nil); title.isEnabled = false; menu.addItem(title)
        let hint = item("Click for random playback · No repeats within a cycle", nil); hint.isEnabled = false; menu.addItem(hint)
        menu.addItem(.separator())
        menu.addItem(item("Play a random clip", #selector(playNext)))
        let choose = item("Choose a clip", nil), choices = NSMenu()
        for clip in clips { choices.addItem(item(String(format: "%02d  %@", clip.id, clip.label), #selector(chooseClip(_:)), tag: clip.id)) }
        choose.submenu = choices; menu.addItem(choose)
        let modeItem = item("Playback mode", nil), modes = NSMenu()
        let rand = item("Random (no repeats per cycle)", #selector(modeRandom)); rand.state = randomMode ? .on : .off; modes.addItem(rand)
        let fix = item(modeTitle(), #selector(modeFixed)); fix.state = randomMode ? .off : .on; modes.addItem(fix)
        modeItem.submenu = modes; menu.addItem(modeItem)
        let filters = item("Rotation playlist", nil), filtersMenu = NSMenu()
        let fhint = item("Uncheck to exclude from random playback", nil); fhint.isEnabled = false; filtersMenu.addItem(fhint); filtersMenu.addItem(.separator())
        // These cannot be ordinary menu items: clicking one closes the whole menu, so
        // unchecking ten clips would mean reopening the menu ten times. Use real
        // NSButton controls (menuItem.view); clicking a control keeps the menu open.
        for clip in clips {
            let box = NSButton(checkboxWithTitle: String(format: "%02d  %@", clip.id, clip.label),
                               target: self, action: #selector(toggleExclusionBox(_:)))
            box.tag = clip.id
            box.state = excludedIDs.contains(clip.id) ? .off : .on
            box.font = .systemFont(ofSize: 12)
            box.sizeToFit()
            let holder = NSMenuItem()
            holder.view = box
            filtersMenu.addItem(holder)
        }
        filtersMenu.addItem(.separator()); filtersMenu.addItem(item("Re-enable all", #selector(enableAllClips)))
        filters.submenu = filtersMenu; menu.addItem(filters)
        menu.addItem(item("Stop playback", #selector(stopPlayback)))
        menu.addItem(.separator())
        let bridgeInfo = item(bridgeStatus, nil); bridgeInfo.isEnabled = false; menu.addItem(bridgeInfo)
        menu.addItem(.separator())
        let volumeItem = item("Volume", nil), volumes = NSMenu()
        for value in [0, 25, 50, 65, 80, 100] {
            let option = item(value == 0 ? "Mute" : "\(value)%", #selector(setVolume(_:)), tag: value)
            option.state = abs(volume - Float(value)/100) < 0.01 ? .on : .off; volumes.addItem(option)
        }
        volumeItem.submenu = volumes; menu.addItem(volumeItem)
        let sizeItem = item("Pet size", nil), sizes = NSMenu()
        for (name, value) in [("Small", 190), ("Medium", 260), ("Large", 340)] {
            let option = item(name, #selector(setSize(_:)), tag: value)
            option.state = Int(size) == value ? .on : .off; sizes.addItem(option)
        }
        sizeItem.submenu = sizes; menu.addItem(sizeItem)
        let iconItem = item("Menu bar picture", nil), icons = NSMenu()
        let faceOption = item("Pet picture", #selector(statusIconFace))
        faceOption.state = statusIconMode == "face" ? .on : .off
        let textOption = item("Text label", #selector(statusIconText))
        textOption.state = statusIconMode == "text" ? .on : .off
        let chooseOption = item("Choose picture…", #selector(chooseStatusIcon))
        chooseOption.state = statusIconMode == "custom" ? .on : .off
        icons.addItem(faceOption); icons.addItem(textOption)
        icons.addItem(.separator()); icons.addItem(chooseOption)
        iconItem.submenu = icons; menu.addItem(iconItem)
        menu.addItem(item("Move back to bottom-right", #selector(resetPosition)))
        menu.addItem(.separator())
        menu.addItem(item("Quit pet", #selector(quit)))
        return menu
    }
    @objc func playNext() {
        // Fixed mode: always play the pinned clip; never rotate.
        if !randomMode, let id = pinnedID, let clip = clips.first(where: { $0.id == id }) { play(clip); return }
        let ids = clips.filter { !excludedIDs.contains($0.id) }.map(\.id)
        guard let id = bag.next(from: ids), let clip = clips.first(where: { $0.id == id }) else { return }
        play(clip)
    }
    func play(_ clip: Clip, hop: Int = 0, root: PetRole? = nil) {
        player?.stop(); pet.animate(false)
        do {
            let audio = try AVAudioPlayer(contentsOf: resources.appendingPathComponent("Clips/\(clip.file)"))
            player = audio; audio.delegate = self; audio.volume = volume; audio.prepareToPlay()
            guard audio.play() else { throw NSError(domain: "Cannot play audio", code: 3) }
            lastPlayed = clip.id; pet.animate(true); showCaption(clip.label, seconds: audio.duration + 0.4)
            if !selfTest { bridge.announceSpeaking(clipID: clip.id, duration: audio.duration, label: clip.label, hop: hop, root: root) }
        } catch { showCaption("This clip cannot play right now", seconds: 4) }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        pet.animate(false)
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === self.player else { return }
        stopPlayback(); showCaption("Audio could not be read", seconds: 4)
    }
    func showCaption(_ text: String, seconds: Double) {
        captionWork?.cancel(); pet.caption.stringValue = text; pet.caption.isHidden = false
        let work = DispatchWorkItem { [weak self] in self?.pet.caption.isHidden = true }
        captionWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
    @objc func chooseClip(_ sender: NSMenuItem) {
        guard let clip = clips.first(where: { $0.id == sender.tag }) else { return }
        if !randomMode { pinnedID = clip.id; defaults.set(clip.id, forKey: "pinnedID"); updateToolTip() }
        play(clip)
    }
    // MARK: - Playback mode and rotation playlist

    func pinValid() -> Bool {
        guard let id = pinnedID else { return false }
        return clips.contains { $0.id == id }
    }
    func modeTitle() -> String {
        guard !randomMode, let id = pinnedID, let clip = clips.first(where: { $0.id == id }) else { return "Repeat one clip" }
        return String(format: "Repeat one clip (%02d %@)", clip.id, clip.label)
    }
    func updateToolTip() {
        let text = randomMode ? "Click to play a random clip · Drag to move · Right-click for settings" : "Click to replay the pinned clip · Drag to move · Right-click for settings"
        pet?.toolTip = text
    }

    // MARK: - Menu bar picture

    var statusIconDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("GoodThingPet", isDirectory: true)
    }

    /// Scale a picture to menu bar size, keep its aspect ratio, and clip it to a
    /// small rounded rectangle so custom pictures look deliberate in the bar.
    /// The icon is rendered into a real bitmap: an NSImage drawing handler has no
    /// bitmap representation until drawn, which some status bar versions ignore.
    /// `headCrop` narrows the pet portrait to the head, which is all that is
    /// recognizable at 18pt.
    func menuBarIcon(from source: NSImage, headCrop: Bool = false) -> NSImage? {
        guard source.size.width > 0, source.size.height > 0 else { return nil }
        let box = NSSize(width: 20, height: 18)
        let sourceRect = headCrop
            ? NSRect(x: source.size.width * 0.22, y: source.size.height * 0.60,
                     width: source.size.width * 0.56, height: source.size.height * 0.40)
            : NSRect(origin: .zero, size: source.size)
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(box.width * scale),
                                            pixelsHigh: Int(box.height * scale),
                                            bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        // The rep must report the point size before the context is created, otherwise
        // the drawing is done in pixel coordinates and the icon lands in a corner.
        bitmap.size = box
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: box).insetBy(dx: 0.5, dy: 0.5),
                     xRadius: 4, yRadius: 4).addClip()
        let fit = min(box.width / sourceRect.width, box.height / sourceRect.height)
        let drawSize = NSSize(width: sourceRect.width * fit, height: sourceRect.height * fit)
        let target = NSRect(x: (box.width - drawSize.width) / 2,
                            y: (box.height - drawSize.height) / 2,
                            width: drawSize.width, height: drawSize.height)
        source.draw(in: target, from: sourceRect, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let icon = NSImage(size: box)
        icon.addRepresentation(bitmap)
        icon.isTemplate = false
        return icon
    }

    func applyStatusIcon() {
        guard let button = status.button else { return }
        var mode = statusIconMode
        if mode == "custom" {
            if let path = statusIconPath, let image = NSImage(contentsOfFile: path), let icon = menuBarIcon(from: image) {
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleProportionallyDown
                button.image = icon
                button.title = ""
            } else {
                // The saved picture was deleted or unreadable; fall back to the pet face.
                mode = "face"
            }
        }
        if mode == "face" {
            if let face = faceImage, let icon = menuBarIcon(from: face, headCrop: true) {
                button.imagePosition = .imageOnly
                button.imageScaling = .scaleProportionallyDown
                button.image = icon
                button.title = ""
            } else {
                button.image = nil
                button.imagePosition = .noImage
                button.title = "GoodThing"
            }
        } else if mode == "text" {
            button.image = nil
            button.imagePosition = .noImage
            button.title = "GoodThing"
        }
        if mode != statusIconMode {
            statusIconMode = mode
            defaults.set(mode, forKey: "statusIconMode")
            if mode != "custom" {
                statusIconPath = nil
                defaults.removeObject(forKey: "statusIconPath")
            }
        }
        button.setAccessibilityLabel("GoodThing Pet")
        button.toolTip = "GoodThing Pet · Click to open settings"
    }

    @objc func statusIconFace() {
        statusIconMode = "face"
        defaults.set(statusIconMode, forKey: "statusIconMode")
        applyStatusIcon()
    }

    @objc func statusIconText() {
        statusIconMode = "text"
        defaults.set(statusIconMode, forKey: "statusIconMode")
        applyStatusIcon()
    }

    @objc func chooseStatusIcon() {
        let picker = NSOpenPanel()
        picker.title = "Choose a menu bar picture"
        picker.message = "The picture is copied into the app's support folder and scaled to fit the menu bar."
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.canChooseFiles = true
        picker.allowedContentTypes = [.image]
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let url = picker.url else { return }
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            showCaption("That picture could not be read", seconds: 3)
            return
        }
        let folder = statusIconDirectory
        let destination = folder.appendingPathComponent("menu-bar.png")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: destination)
        } catch {
            showCaption("Could not save that picture", seconds: 3)
            return
        }
        statusIconPath = destination.path
        statusIconMode = "custom"
        defaults.set(destination.path, forKey: "statusIconPath")
        defaults.set(statusIconMode, forKey: "statusIconMode")
        applyStatusIcon()
        showCaption("Menu bar picture updated", seconds: 2)
    }
    @objc func modeRandom() { setMode(random: true) }
    @objc func modeFixed() { setMode(random: false) }
    func setMode(random: Bool) {
        randomMode = random
        if !random, !pinValid() { pinnedID = (clips.first(where: { $0.id == lastPlayed }) ?? clips.first)?.id }
        defaults.set(random, forKey: "randomMode")
        if let pin = pinnedID { defaults.set(pin, forKey: "pinnedID") }
        updateToolTip()
        if random {
            showCaption("Random play · No repeats per cycle", seconds: 3)
        } else if let clip = clips.first(where: { $0.id == pinnedID }) {
            showCaption(String(format: "Pinned: %02d %@", clip.id, clip.label), seconds: 4)
        }
    }
    /// A checkbox in the menu was clicked. The menu stays open, so several clips can
    /// be unchecked in a row.
    @objc func toggleExclusionBox(_ sender: NSButton) {
        let id = sender.tag
        if excludedIDs.contains(id) {
            excludedIDs.remove(id)
        } else {
            guard excludedIDs.count < clips.count - 1 else {
                sender.state = .on
                NSSound.beep()
                return
            }
            excludedIDs.insert(id)
        }
        defaults.set(Array(excludedIDs), forKey: "excludedIDs")
        bag.remaining.removeAll()
    }

    /// Uncheck a clip: remove it from the random rotation. Keep at least one clip,
    /// otherwise random play has nothing to play.
    @objc func toggleExclusion(_ sender: NSMenuItem) {
        let id = sender.tag
        if excludedIDs.contains(id) {
            excludedIDs.remove(id)
        } else {
            guard excludedIDs.count < clips.count - 1 else {
                showCaption("Keep at least one clip in the rotation", seconds: 3)
                return
            }
            excludedIDs.insert(id)
        }
        defaults.set(Array(excludedIDs), forKey: "excludedIDs")
        showCaption("\(clips.count - excludedIDs.count) clips in rotation", seconds: 2)
    }
    @objc func enableAllClips() {
        excludedIDs.removeAll()
        defaults.set([Int](), forKey: "excludedIDs")
        showCaption("All clips restored to rotation", seconds: 2)
    }

    @objc func stopPlayback() {
        companionWork?.cancel(); companionWork = nil
        player?.stop(); pet.animate(false); captionWork?.cancel(); pet.caption.isHidden = true
    }
    @objc func setVolume(_ sender: NSMenuItem) {
        volume = Float(sender.tag) / 100; player?.volume = volume; defaults.set(volume, forKey: "volume")
    }
    @objc func setSize(_ sender: NSMenuItem) {
        size = CGFloat(sender.tag); panel.setContentSize(panelSize)
        pet.needsLayout = true
        keepOnScreen()
        defaults.set(Double(size), forKey: "size"); savePosition()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { bridge.stop(); companionWork?.cancel(); savePosition(); player?.stop(); pet?.animate(false) }

    func runSelfTest() {
        var failures: [String] = []
        func check(_ valid: Bool, _ name: String) { print("\(valid ? "OK" : "FAIL") \(name)"); if !valid { failures.append(name) } }
        check(!panel.isOpaque && panel.backgroundColor == .clear && panel.level == .floating, "transparent floating window")
        check(!panel.canBecomeKey && !panel.canBecomeMain, "does not steal keyboard focus")
        if let data = pet.face.image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) {
            check(bitmap.hasAlpha && (bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1) < 0.1, "original image transparency")
        } else { check(false, "image decoding") }
        for clip in clips {
            do {
                let audio = try AVAudioPlayer(contentsOf: resources.appendingPathComponent("Clips/\(clip.file)"))
                check(audio.duration > 0.25 && abs(audio.duration - clip.duration) < 0.15, "audio \(clip.id): \(clip.label), \(audio.duration)s")
            } catch { check(false, "audio \(clip.id)") }
        }
        var testBag = ShuffleBag(), previous: Int?
        let allIDs = clips.map(\.id)
        var randomOK = true
        for _ in 0..<100 {
            var cycle: [Int] = []
            for _ in clips {
                let id = testBag.next(from: allIDs)!
                if clips.count > 1 && previous == id { randomOK = false }
                previous = id; cycle.append(id)
            }
            if Set(cycle).count != clips.count { randomOK = false }
        }
        check(randomOK, "100 shuffle rounds: no repeats within a round or at boundary")
        volume = 0
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        pet.mouseDown(with: event); pet.mouseUp(with: event)
        check(player?.isPlaying == true && pet.speaking, "mouse click starts playback and animation")
        let previousPlayer = player
        playNext()
        check(previousPlayer?.isPlaying == false && player?.isPlaying == true, "new click replaces previous audio")
        let beforeDrag = lastPlayed
        pet.mouseDown(with: event)
        let drag = NSEvent.mouseEvent(with: .leftMouseDragged, location: NSPoint(x: 30, y: 20), modifierFlags: [], timestamp: 1, windowNumber: panel.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        pet.mouseDragged(with: drag); pet.mouseUp(with: drag)
        check(pet.dragged && lastPlayed == beforeDrag, "drag moves without playing a new clip")

        // Fixed mode: every trigger must play the pinned clip; it must not drift to another one.
        let savedMode = randomMode, savedPin = pinnedID, savedExcluded = excludedIDs
        randomMode = false
        pinnedID = clips.count > 2 ? clips[2].id : clips.first?.id
        var pinnedOK = true
        for _ in 0..<6 {
            playNext()
            if lastPlayed != pinnedID { pinnedOK = false }
        }
        check(pinnedOK, "fixed mode always replays the pinned clip")

        // Exclusion: unchecked clips must never show up in random play.
        randomMode = true
        excludedIDs = Set(clips.prefix(2).map(\.id))
        var excludedOK = true
        for _ in 0..<40 {
            playNext()
            if let id = lastPlayed, excludedIDs.contains(id) { excludedOK = false }
        }
        check(excludedOK, "excluded clips never play in random mode")

        randomMode = savedMode; pinnedID = savedPin; excludedIDs = savedExcluded
        check(makeMenu().items.first(where: { $0.title == "Choose a clip" })?.submenu?.items.count == clips.count, "all clips in context menu")
        // The rotation list must use real controls (menuItem.view); ordinary menu items
        // close the menu on click, so several could not be toggled in a row.
        let filterBoxes = makeMenu().items.first(where: { $0.title == "Rotation playlist" })?.submenu?.items.compactMap { $0.view as? NSButton } ?? []
        check(filterBoxes.count == clips.count && filterBoxes.allSatisfy { !$0.title.isEmpty && $0.action != nil }, "rotation list uses real checkboxes")
        check(faceImage != nil && menuBarIcon(from: faceImage!, headCrop: true)?.representations.contains { $0.pixelsWide > 0 } == true, "menu bar picture renders")
        let iconOptions = makeMenu().items.first(where: { $0.title == "Menu bar picture" })?.submenu?.items.filter { !$0.isSeparatorItem } ?? []
        check(iconOptions.count == 3, "menu bar picture offers face, text and custom")
        showCaption(clips[0].label, seconds: 3)
        pet.layoutSubtreeIfNeeded()
        let bubble = pet.caption
        bubble.layoutSubtreeIfNeeded()
        check(!bubble.isHidden && abs(bubble.label.frame.midY - bubble.bounds.midY) < 1.0, "caption text is vertically centered")
        check(bubble.hitTest(NSPoint(x: bubble.bounds.midX, y: bubble.bounds.midY)) == nil, "caption does not block pet clicks")
        stopPlayback()
        check(player?.isPlaying == false && !pet.speaking && pet.caption.isHidden, "stop clears audio, animation and caption")
        if let i = CommandLine.arguments.firstIndex(of: "--preview"), i + 1 < CommandLine.arguments.count {
            showCaption(clips[0].label, seconds: 5)
            pet.layoutSubtreeIfNeeded()
            if let bitmap = pet.bitmapImageRepForCachingDisplay(in: pet.bounds) {
                pet.cacheDisplay(in: pet.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
        }
        print(failures.isEmpty ? "PASS" : "FAIL: \(failures)"); fflush(stdout)
        exit(failures.isEmpty ? 0 : 1)
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
