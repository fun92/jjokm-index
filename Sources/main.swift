import Cocoa

struct Memo: Codable {
    var title: String
    var text: String
    var fontSize: Double?

    var effectiveFontSize: CGFloat {
        CGFloat(fontSize ?? 24)
    }
}

final class EdgePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class BubbleButton: NSButton {
    var onClick: (() -> Void)?
    var onDrag: ((CGFloat) -> Void)?
    private var startPoint: NSPoint = .zero
    private var didDrag = false

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        let point = event.locationInWindow
        let deltaY = point.y - startPoint.y
        guard abs(deltaY) > 1 else { return }
        didDrag = true
        onDrag?(deltaY)
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onClick?()
        }
    }
}

final class MemoStore {
    private let url: URL
    private(set) var memos: [Memo]

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("JjokkomIndex", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        url = folder.appendingPathComponent("memos.json")

        if
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Memo].self, from: data),
            !decoded.isEmpty
        {
            memos = decoded
        } else {
            memos = [
                Memo(title: "메모", text: "모니터 오른쪽에 쪼꼼 숨어 있다가\n\n필요할 때 톡 열리는 쪼꼼 인덱스입니다.", fontSize: 16),
                Memo(title: "할 일", text: "", fontSize: 16),
                Memo(title: "링크", text: "", fontSize: 16)
            ]
        }

        var changed = false
        for index in memos.indices {
            if memos[index].fontSize == nil || (memos[index].fontSize ?? 16) > 18 {
                memos[index].fontSize = 16
                changed = true
            }
        }
        if changed { save() }
    }

    func update(index: Int, text: String) {
        guard memos.indices.contains(index) else { return }
        memos[index].text = text
        save()
    }

    func updateTitle(index: Int, title: String) {
        guard memos.indices.contains(index) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        memos[index].title = trimmed.isEmpty ? "메모" : trimmed
        save()
    }

    func addMemo() -> Int {
        memos.append(Memo(title: "새 메모", text: "", fontSize: 16))
        save()
        return memos.count - 1
    }

    func updateFontSize(index: Int, size: CGFloat) {
        guard memos.indices.contains(index) else { return }
        memos[index].fontSize = Double(size)
        save()
    }

    func deleteMemo(index: Int) -> Int {
        guard memos.indices.contains(index) else { return 0 }
        if memos.count == 1 {
            memos[0] = Memo(title: "메모", text: "", fontSize: 16)
            save()
            return 0
        }

        memos.remove(at: index)
        save()
        return min(index, memos.count - 1)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(memos) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    private let closedWidth: CGFloat = 56
    private let openWidth: CGFloat = 420
    private let panelHeight: CGFloat = 280
    private let bubbleSize: CGFloat = 42

    private let store = MemoStore()
    private var selectedIndex = 0
    private var isOpen = false
    private var justLaunched = true
    private var side = UserDefaults.standard.string(forKey: "edgeSide") == "left" ? "left" : "right"
    private var isPinned = UserDefaults.standard.bool(forKey: "memoPinned")

    private var statusItem: NSStatusItem!
    private var loginItemMenuItem: NSMenuItem!
    private var sideMenuItem: NSMenuItem!
    private var pinMenuItem: NSMenuItem!
    private var panel: EdgePanel!
    private var root: NSView!
    private var paper: NSView!
    private var closeButton: NSButton!
    private var tabStack: NSStackView!
    private var bubbleButton: BubbleButton!
    private var titleField: NSTextField!
    private var sizeLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var statusLabel: NSTextField!
    private var sizeSlider: NSSlider!
    private var textScroll: NSScrollView!
    private var textView: NSTextView!
    private var selectedTextColor = NSColor(red: 0.13, green: 0.11, blue: 0.08, alpha: 1)
    private var tabButtons: [NSButton] = []
    private var tabWidthConstraints: [NSLayoutConstraint] = []
    private var hoverTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildWindow()
        buildStatusItem()
        renderTabs()
        selectMemo(0)
        close(animated: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startHoverReveal()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.justLaunched = false
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "💛"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "쪼꼼 열기", action: #selector(openFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "접기", action: #selector(closeFromMenu), keyEquivalent: ""))
        pinMenuItem = NSMenuItem(title: "", action: #selector(togglePin), keyEquivalent: "")
        menu.addItem(pinMenuItem)
        sideMenuItem = NSMenuItem(title: "", action: #selector(toggleSide), keyEquivalent: "")
        menu.addItem(sideMenuItem)
        loginItemMenuItem = NSMenuItem(title: "", action: #selector(toggleLoginItem), keyEquivalent: "")
        menu.addItem(loginItemMenuItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        updateStatusMenuItems()
    }

    private func buildWindow() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let savedY = UserDefaults.standard.object(forKey: "bubbleY") as? CGFloat
        let initialY = savedY ?? (screen.midY - bubbleSize / 2)
        let frame = NSRect(
            x: windowX(width: closedWidth, screen: screen),
            y: min(max(initialY, screen.minY + 10), screen.maxY - bubbleSize - 10),
            width: closedWidth,
            height: bubbleSize
        )

        panel = EdgePanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = isPinned ? .statusBar : .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        root = NSView(frame: NSRect(origin: .zero, size: frame.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = root

        bubbleButton = BubbleButton(title: "💛", target: nil, action: nil)
        bubbleButton.onClick = { [weak self] in self?.togglePanel() }
        bubbleButton.onDrag = { [weak self] deltaY in self?.moveBubble(by: deltaY) }
        bubbleButton.isBordered = false
        bubbleButton.font = .systemFont(ofSize: 21)
        bubbleButton.wantsLayer = true
        bubbleButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
        bubbleButton.layer?.cornerRadius = bubbleSize / 2
        bubbleButton.layer?.borderWidth = 1
        bubbleButton.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        bubbleButton.layer?.shadowColor = NSColor.black.cgColor
        bubbleButton.layer?.shadowOpacity = 0.20
        bubbleButton.layer?.shadowRadius = 10
        bubbleButton.layer?.shadowOffset = NSSize(width: -2, height: -2)
        bubbleButton.autoresizingMask = [.minYMargin]
        root.addSubview(bubbleButton)

        paper = NSView(frame: NSRect(x: 0, y: 0, width: openWidth, height: panelHeight))
        paper.wantsLayer = true
        paper.layer?.backgroundColor = NSColor(red: 1.0, green: 0.95, blue: 0.47, alpha: 0.96).cgColor
        paper.layer?.cornerRadius = 14
        paper.layer?.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
        paper.layer?.shadowColor = NSColor.black.cgColor
        paper.layer?.shadowOpacity = 0.13
        paper.layer?.shadowRadius = 16
        paper.layer?.shadowOffset = NSSize(width: -4, height: -2)
        root.addSubview(paper)

        closeButton = plainButton(collapseSymbol(), action: #selector(togglePanel), fontSize: 22)
        closeButton.frame = NSRect(x: 18, y: panelHeight - 35, width: 24, height: 26)
        paper.addSubview(closeButton)

        let addButton = capsuleButton("추가", action: #selector(addMemo))
        addButton.frame = NSRect(x: openWidth - 116, y: panelHeight - 34, width: 42, height: 24)
        paper.addSubview(addButton)

        let deleteButton = capsuleButton("삭제", action: #selector(deleteMemo))
        deleteButton.frame = NSRect(x: openWidth - 70, y: panelHeight - 34, width: 42, height: 24)
        paper.addSubview(deleteButton)

        let quitButton = plainButton("×", action: #selector(quitApp), fontSize: 18)
        quitButton.frame = NSRect(x: openWidth - 27, y: panelHeight - 33, width: 20, height: 24)
        paper.addSubview(quitButton)

        titleField = NSTextField(frame: NSRect(x: 58, y: panelHeight - 62, width: openWidth - 132, height: 28))
        titleField.isBordered = false
        titleField.backgroundColor = .clear
        titleField.alignment = .center
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)
        titleField.textColor = NSColor(red: 0.13, green: 0.11, blue: 0.08, alpha: 1)
        titleField.target = self
        titleField.action = #selector(titleChanged)
        paper.addSubview(titleField)

        let toolbarDock = NSView(frame: NSRect(x: 28, y: 14, width: openWidth - 56, height: 40))
        toolbarDock.wantsLayer = true
        toolbarDock.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.26).cgColor
        toolbarDock.layer?.cornerRadius = 16
        toolbarDock.layer?.borderWidth = 1
        toolbarDock.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
        paper.addSubview(toolbarDock)

        let toolbarItems: [(String, Selector, CGFloat)] = [
            ("B", #selector(bold), 32),
            ("I", #selector(italic), 32),
            ("U", #selector(underline), 32),
            ("•", #selector(bullet), 32),
            ("🎨", #selector(colorText), 34),
            ("Aa", #selector(toggleSizeSlider), 38)
        ]
        var toolbarX: CGFloat = 42
        for item in toolbarItems {
            let fontSize: CGFloat
            if item.0 == "🎨" {
                fontSize = 13
            } else if item.0 == "Aa" {
                fontSize = 13
            } else {
                fontSize = 14
            }
            let button = softButton(item.0, action: item.1, fontSize: fontSize)
            button.frame = NSRect(x: toolbarX, y: 20, width: item.2, height: 25)
            paper.addSubview(button)
            toolbarX += item.2 + 5
        }

        sizeLabel = NSTextField(labelWithString: "24")
        sizeLabel.alignment = .center
        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        sizeLabel.textColor = NSColor.black.withAlphaComponent(0.55)
        sizeLabel.frame = NSRect(x: toolbarX + 3, y: 25, width: 24, height: 16)
        paper.addSubview(sizeLabel)

        sizeSlider = NSSlider(value: 16, minValue: 11, maxValue: 26, target: self, action: #selector(fontSizeSliderChanged(_:)))
        sizeSlider.frame = NSRect(x: max(36, toolbarX - 72), y: 54, width: 128, height: 18)
        sizeSlider.numberOfTickMarks = 0
        sizeSlider.isContinuous = true
        sizeSlider.isHidden = true
        paper.addSubview(sizeSlider)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.alignment = .right
        statusLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        statusLabel.textColor = NSColor.black.withAlphaComponent(0.45)
        statusLabel.frame = NSRect(x: openWidth - 92, y: 25, width: 42, height: 16)
        paper.addSubview(statusLabel)

        versionLabel = NSTextField(labelWithString: "v1.2")
        versionLabel.alignment = .right
        versionLabel.font = .monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        versionLabel.textColor = NSColor.black.withAlphaComponent(0.45)
        versionLabel.frame = NSRect(x: openWidth - 42, y: 25, width: 32, height: 16)
        paper.addSubview(versionLabel)

        textScroll = NSScrollView(frame: NSRect(x: 36, y: 62, width: openWidth - 72, height: panelHeight - 166))
        textScroll.drawsBackground = false
        textScroll.hasVerticalScroller = true
        textScroll.borderType = .noBorder

        textView = NSTextView(frame: textScroll.bounds)
        textView.drawsBackground = false
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = NSColor(red: 0.13, green: 0.11, blue: 0.08, alpha: 1)
        textView.insertionPointColor = .black
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textScroll.documentView = textView
        paper.addSubview(textScroll)

        tabStack = NSStackView(frame: NSRect(x: 36, y: panelHeight - 96, width: openWidth - 72, height: 26))
        tabStack.orientation = .horizontal
        tabStack.spacing = 5
        tabStack.distribution = .fill
        paper.addSubview(tabStack)
    }

    private func renderTabs() {
        tabStack.arrangedSubviews.forEach { view in
            tabStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        tabWidthConstraints = []
        tabButtons = store.memos.enumerated().map { index, memo in
            let button = NSButton(title: memo.title, target: self, action: #selector(tabClicked(_:)))
            button.tag = index
            button.isBordered = false
            button.font = .systemFont(ofSize: 11, weight: .semibold)
            button.contentTintColor = .black
            button.wantsLayer = true
            button.layer?.backgroundColor = tabColor(index: index).cgColor
            button.layer?.cornerRadius = 12
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.18).cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            let width = button.widthAnchor.constraint(equalToConstant: 56)
            width.isActive = true
            tabWidthConstraints.append(width)
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
            tabStack.addArrangedSubview(button)
            return button
        }
        refreshSelectedTab()
    }

    private func selectMemo(_ index: Int) {
        guard store.memos.indices.contains(index) else { return }
        selectedIndex = index
        titleField.stringValue = store.memos[index].title
        textView.string = store.memos[index].text
        applyMemoFontSize(store.memos[index].effectiveFontSize)
        refreshSelectedTab()
    }

    private func refreshSelectedTab() {
        for button in tabButtons {
            let isSelected = button.tag == selectedIndex
            button.alphaValue = isSelected ? 1 : 0.74
            button.layer?.borderWidth = isSelected ? 2 : 1
            button.layer?.shadowOpacity = isSelected ? 0.16 : 0
            button.layer?.shadowRadius = isSelected ? 6 : 0
            button.layer?.shadowOffset = NSSize(width: -2, height: -1)
            button.font = .systemFont(ofSize: isSelected ? 12 : 11, weight: isSelected ? .bold : .semibold)
            button.layer?.backgroundColor = (isSelected ? selectedTabColor(index: button.tag) : tabColor(index: button.tag)).cgColor
        }

        let availableWidth = openWidth - 72
        let collapsedWidth: CGFloat = 58
        let spacing = CGFloat(max(0, store.memos.count - 1)) * tabStack.spacing
        let selectedWidth = min(160, max(104, availableWidth - spacing - collapsedWidth * CGFloat(max(0, store.memos.count - 1))))
        for (index, constraint) in tabWidthConstraints.enumerated() {
            constraint.constant = index == selectedIndex ? selectedWidth : collapsedWidth
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            tabStack.layoutSubtreeIfNeeded()
        }
    }

    @objc private func tabClicked(_ sender: NSButton) {
        selectMemo(sender.tag)
        if isOpen {
            textView.window?.makeFirstResponder(textView)
        } else {
            open()
        }
    }

    @objc private func togglePanel() {
        isOpen ? close(animated: true) : open()
    }

    @objc private func statusItemClicked() {
        openFromMenu()
    }

    @objc private func openFromMenu() {
        open()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeFromMenu() {
        close(animated: true)
    }

    @objc private func togglePin() {
        isPinned.toggle()
        UserDefaults.standard.set(isPinned, forKey: "memoPinned")
        panel.level = isPinned ? .statusBar : .floating
        if isPinned {
            openFromMenu()
        }
        updateStatusMenuItems()
    }

    @objc private func toggleSide() {
        side = side == "right" ? "left" : "right"
        UserDefaults.standard.set(side, forKey: "edgeSide")
        closeButton.title = collapseSymbol()
        resize(to: isOpen ? openWidth : closedWidth, animated: true)
        updateStatusMenuItems()
    }

    @objc private func toggleLoginItem() {
        setLoginItem(enabled: !isLoginItemEnabled())
        updateStatusMenuItems()
    }

    @objc private func addMemo() {
        let index = store.addMemo()
        renderTabs()
        selectMemo(index)
        showStatus("추가됨")
        open()
    }

    @objc private func deleteMemo() {
        let nextIndex = store.deleteMemo(index: selectedIndex)
        renderTabs()
        selectMemo(nextIndex)
        showStatus("삭제됨")
        open()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func titleChanged() {
        store.updateTitle(index: selectedIndex, title: titleField.stringValue)
        renderTabs()
        showStatus("제목 저장")
    }

    func textDidChange(_ notification: Notification) {
        store.update(index: selectedIndex, text: textView.string)
        showStatus("저장됨")
    }

    private func open() {
        isOpen = true
        resize(to: openWidth, animated: true)
        textView.window?.makeFirstResponder(textView)
    }

    private func close(animated: Bool) {
        isOpen = false
        if animated {
            closeWithoutMovingLauncher()
            return
        }
        resize(to: closedWidth, animated: animated)
    }

    private func closeWithoutMovingLauncher() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            paper.animator().alphaValue = 0
            tabStack.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.resize(to: self.closedWidth, animated: false)
            self.paper.alphaValue = 1
            self.tabStack.alphaValue = 1
        }
    }

    private func resize(to width: CGFloat, animated: Bool) {
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = isOpen ? panelHeight : bubbleSize
        let anchorTop = min(max(panel.frame.maxY, screen.minY + bubbleSize + 10), screen.maxY - 10)
        let desiredY = min(max(anchorTop - height, screen.minY + 10), screen.maxY - height - 10)
        let newFrame = NSRect(x: windowX(width: width, screen: screen), y: desiredY, width: width, height: height)

        if animated && !isOpen {
            prepareAnchoredBubbleForClosing()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
                bubbleButton.animator().frame = bubbleFrame(for: bubbleSize)
            } completionHandler: { [weak self] in
                guard let self else { return }
                self.root.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
                self.layoutContent(for: width, height: height)
                self.updateBubbleVisibility(animated: false)
            }
            return
        }

        root.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        layoutContent(for: width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
        }
        updateBubbleVisibility(animated: false)
    }

    private func layoutContent(for width: CGFloat, height: CGFloat) {
        closeButton?.title = collapseSymbol()
        if isOpen {
            paper.isHidden = false
            tabStack.isHidden = false
            bubbleButton.isHidden = true
            paper.frame.origin = .zero
            tabStack.frame.origin.x = 36
            tabStack.frame.origin.y = panelHeight - 96
        } else {
            paper.isHidden = true
            tabStack.isHidden = true
            bubbleButton.isHidden = false
            bubbleButton.frame = bubbleFrame(for: height)
        }
    }

    private func prepareAnchoredBubbleForClosing() {
        paper.isHidden = true
        tabStack.isHidden = true
        bubbleButton.isHidden = false
        bubbleButton.frame = bubbleFrame(for: panel.frame.height)
    }

    private func bubbleFrame(for height: CGFloat) -> NSRect {
        NSRect(x: 8, y: max(0, height - bubbleSize), width: bubbleSize, height: bubbleSize)
    }

    private func startHoverReveal() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateBubbleVisibility(animated: true)
        }
        RunLoop.main.add(hoverTimer!, forMode: .common)
        updateBubbleVisibility(animated: false)
    }

    private func updateBubbleVisibility(animated: Bool) {
        guard !isOpen else {
            root.alphaValue = 1
            return
        }

        guard !justLaunched else {
            root.alphaValue = 1
            return
        }

        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let nearEdge = side == "right" ? mouse.x >= screen.maxX - 90 : mouse.x <= screen.minX + 90
        let nearBubbleY = mouse.y >= frame.minY - 80 && mouse.y <= frame.maxY + 80
        let targetAlpha: CGFloat = nearEdge && nearBubbleY ? 1.0 : 0.22

        guard abs(root.alphaValue - targetAlpha) > 0.02 else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                root.animator().alphaValue = targetAlpha
            }
        } else {
            root.alphaValue = targetAlpha
        }
    }

    private func moveBubble(by deltaY: CGFloat) {
        guard !isOpen else { return }
        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var frame = panel.frame
        frame.origin.y = min(max(frame.origin.y + deltaY, screen.minY + 10), screen.maxY - frame.height - 10)
        panel.setFrame(frame, display: true)
        UserDefaults.standard.set(frame.origin.y, forKey: "bubbleY")
    }

    private func windowX(width: CGFloat, screen: NSRect) -> CGFloat {
        side == "right" ? screen.maxX - width - 8 : screen.minX + 8
    }

    private func collapseSymbol() -> String {
        side == "right" ? "›" : "‹"
    }

    private func updateStatusMenuItems() {
        pinMenuItem?.title = isPinned ? "메모 고정 끄기" : "메모 고정 켜기"
        sideMenuItem?.title = side == "right" ? "왼쪽으로 이동" : "오른쪽으로 이동"
        loginItemMenuItem?.title = isLoginItemEnabled() ? "로그인 시 자동 열기 끄기" : "로그인 시 자동 열기 켜기"
    }

    private func loginPlistURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/app.jjokkom.index.login.plist")
    }

    private func isLoginItemEnabled() -> Bool {
        FileManager.default.fileExists(atPath: loginPlistURL().path)
    }

    private func setLoginItem(enabled: Bool) {
        let plist = loginPlistURL()
        if enabled {
            let bundlePath = Bundle.main.bundlePath
            let contents = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>Label</key>
              <string>app.jjokkom.index.login</string>
              <key>ProgramArguments</key>
              <array>
                <string>/usr/bin/open</string>
                <string>\(bundlePath)</string>
              </array>
              <key>RunAtLoad</key>
              <true/>
            </dict>
            </plist>
            """
            try? FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? contents.write(to: plist, atomically: true, encoding: .utf8)
            _ = shellLaunchctl(["unload", plist.path])
            _ = shellLaunchctl(["load", plist.path])
        } else {
            _ = shellLaunchctl(["unload", plist.path])
            try? FileManager.default.removeItem(at: plist)
        }
    }

    private func shellLaunchctl(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @objc private func bold() {
        toggleFontTrait(.boldFontMask)
        textView.window?.makeFirstResponder(textView)
    }

    @objc private func italic() {
        toggleFontTrait(.italicFontMask)
        textView.window?.makeFirstResponder(textView)
    }

    @objc private func underline() {
        toggleUnderline()
        textView.window?.makeFirstResponder(textView)
    }

    @objc private func bullet() {
        let range = textView.selectedRange()
        let insert = range.length == 0 ? "• " : "\n• "
        textView.insertText(insert, replacementRange: range)
        showStatus("글머리")
    }

    @objc private func colorText() {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(applySelectedColor(_:)))
        panel.color = selectedTextColor
        panel.makeKeyAndOrderFront(nil)
        showStatus("색 선택")
    }

    @objc private func applySelectedColor(_ sender: NSColorPanel) {
        selectedTextColor = sender.color
        let range = textView.selectedRange()
        if range.length == 0 {
            textView.typingAttributes[.foregroundColor] = selectedTextColor
        } else {
            textView.textStorage?.addAttribute(.foregroundColor, value: selectedTextColor, range: range)
        }
        showStatus("색 적용")
        textView.window?.makeFirstResponder(textView)
    }

    @objc private func decreaseFontSize() {
        adjustFontSize(by: -2)
    }

    @objc private func increaseFontSize() {
        adjustFontSize(by: 2)
    }

    @objc private func toggleSizeSlider() {
        sizeSlider.doubleValue = Double(store.memos[selectedIndex].effectiveFontSize)
        sizeSlider.isHidden.toggle()
        if !sizeSlider.isHidden {
            showStatus("")
        }
    }

    @objc private func fontSizeSliderChanged(_ sender: NSSlider) {
        let next = CGFloat(round(sender.doubleValue))
        store.updateFontSize(index: selectedIndex, size: next)
        applyMemoFontSize(next)
    }

    private func adjustFontSize(by delta: CGFloat) {
        let current = store.memos[selectedIndex].effectiveFontSize
        let next = min(26, max(11, current + delta))
        store.updateFontSize(index: selectedIndex, size: next)
        applyMemoFontSize(next)
        showStatus("")
        textView.window?.makeFirstResponder(textView)
    }

    private func applyMemoFontSize(_ size: CGFloat) {
        let font = NSFont.systemFont(ofSize: size, weight: .regular)
        textView.font = font
        textView.typingAttributes[.font] = font
        if let textStorage = textView.textStorage {
            let range = NSRange(location: 0, length: (textView.string as NSString).length)
            textStorage.beginEditing()
            textStorage.addAttributes([
                .font: font,
                .foregroundColor: NSColor(red: 0.13, green: 0.11, blue: 0.08, alpha: 1)
            ], range: range)
            textStorage.endEditing()
        }
        sizeLabel.stringValue = "\(Int(size))"
        textView.needsDisplay = true
    }

    private func showStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        let range = textView.selectedRange()
        let manager = NSFontManager.shared

        if range.length == 0 {
            let currentFont = textView.typingAttributes[.font] as? NSFont ?? textView.font ?? .systemFont(ofSize: 16)
            let traits = manager.traits(of: currentFont)
            textView.typingAttributes[.font] = traits.contains(trait)
                ? manager.convert(currentFont, toNotHaveTrait: trait)
                : manager.convert(currentFont, toHaveTrait: trait)
            return
        }

        var shouldRemove = false
        textView.textStorage?.enumerateAttribute(.font, in: range) { value, _, stop in
            let font = value as? NSFont ?? textView.font ?? .systemFont(ofSize: 16)
            if manager.traits(of: font).contains(trait) {
                shouldRemove = true
                stop.pointee = true
            }
        }

        textView.textStorage?.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let font = value as? NSFont ?? textView.font ?? .systemFont(ofSize: 16)
            let converted = shouldRemove
                ? manager.convert(font, toNotHaveTrait: trait)
                : manager.convert(font, toHaveTrait: trait)
            textView.textStorage?.addAttribute(.font, value: converted, range: subrange)
        }
    }

    private func toggleUnderline() {
        let range = textView.selectedRange()
        if range.length == 0 {
            let current = textView.typingAttributes[.underlineStyle] as? Int ?? 0
            if current == 0 {
                textView.typingAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                textView.typingAttributes.removeValue(forKey: .underlineStyle)
            }
            return
        }

        var shouldRemove = false
        textView.textStorage?.enumerateAttribute(.underlineStyle, in: range) { value, _, stop in
            if (value as? Int ?? 0) != 0 {
                shouldRemove = true
                stop.pointee = true
            }
        }

        if shouldRemove {
            textView.textStorage?.removeAttribute(.underlineStyle, range: range)
        } else {
            textView.textStorage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
    }

    private func plainButton(_ title: String, action: Selector, fontSize: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: fontSize, weight: .medium)
        button.contentTintColor = NSColor.black.withAlphaComponent(0.58)
        return button
    }

    private func capsuleButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = true
        button.bezelStyle = .regularSquare
        button.font = .systemFont(ofSize: title.count > 1 ? 11 : 14, weight: title == "B" ? .bold : .semibold)
        button.contentTintColor = NSColor.black.withAlphaComponent(0.76)
        return button
    }

    private func softButton(_ title: String, action: Selector, fontSize: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        let weight: NSFont.Weight = title == "B" ? .bold : .semibold
        button.font = .systemFont(ofSize: fontSize, weight: weight)
        button.contentTintColor = NSColor.black.withAlphaComponent(0.75)
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.48).cgColor
        button.layer?.cornerRadius = 10
        button.layer?.borderWidth = 1
        button.layer?.borderColor = NSColor.white.withAlphaComponent(0.45).cgColor
        return button
    }

    private func labelPill(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.alignment = .center
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = NSColor(red: 0.25, green: 0.19, blue: 0.02, alpha: 1)
        label.wantsLayer = true
        label.layer?.backgroundColor = NSColor(red: 1.0, green: 0.83, blue: 0.13, alpha: 1).cgColor
        label.layer?.cornerRadius = 14
        label.setFrameSize(NSSize(width: 70, height: 28))
        return label
    }

    private func verticalTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "메모" : trimmed).map(String.init).joined(separator: "\n")
    }

    private func tabColor(index: Int) -> NSColor {
        let colors = [
            NSColor(red: 1.0, green: 0.86, blue: 0.92, alpha: 0.82),
            NSColor(red: 0.84, green: 0.93, blue: 1.0, alpha: 0.82),
            NSColor(red: 0.84, green: 1.0, blue: 0.90, alpha: 0.82),
            NSColor(red: 1.0, green: 0.90, blue: 0.72, alpha: 0.82)
        ]
        return colors[index % colors.count]
    }

    private func selectedTabColor(index: Int) -> NSColor {
        let colors = [
            NSColor(red: 1.0, green: 0.74, blue: 0.84, alpha: 0.96),
            NSColor(red: 0.72, green: 0.88, blue: 1.0, alpha: 0.96),
            NSColor(red: 0.72, green: 0.96, blue: 0.80, alpha: 0.96),
            NSColor(red: 1.0, green: 0.82, blue: 0.56, alpha: 0.96)
        ]
        return colors[index % colors.count]
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
