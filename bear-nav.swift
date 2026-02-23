import AppKit
import SQLite3

// MARK: - Direction

enum Direction: String {
    case next, previous
}

let direction: Direction = CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "previous" ? .previous : .next

// MARK: - Accessibility: read the current note title from Bear's UI

func getCurrentNoteTitle() -> String? {
    let bearApp = NSWorkspace.shared.runningApplications.first {
        $0.bundleIdentifier == "net.shinyfrog.bear"
    }
    guard let pid = bearApp?.processIdentifier else { return nil }

    let app = AXUIElementCreateApplication(pid)

    var windowRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
          let window = windowRef else { return nil }

    let win = window as! AXUIElement

    // Walk the UI tree: window → splitter group → group → static text
    guard let splitterGroup = findChild(of: win, role: "AXSplitGroup"),
          let editorGroup = findChild(of: splitterGroup, role: "AXGroup"),
          let titleElement = findChild(of: editorGroup, role: "AXStaticText") else {
        return nil
    }

    var valueRef: CFTypeRef?
    AXUIElementCopyAttributeValue(titleElement, kAXValueAttribute as CFString, &valueRef)
    return valueRef as? String
}

func findChild(of element: AXUIElement, role targetRole: String) -> AXUIElement? {
    var childrenRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
          let children = childrenRef as? [AXUIElement] else { return nil }

    for child in children {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String, role == targetRole {
            return child
        }
    }
    return nil
}

// MARK: - SQLite: find the adjacent daily note

func findAdjacentDailyNote(currentTitle: String, direction: Direction) -> String? {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let dbPath = "\(home)/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite"

    var db: OpaquePointer?
    guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_close(db) }

    let op = direction == .next ? ">" : "<"
    let order = direction == .next ? "ASC" : "DESC"
    let sql = """
        SELECT ZTITLE FROM ZSFNOTE
        WHERE ZTITLE \(op) ?1
        AND ZTITLE GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
        AND ZTRASHED = 0
        ORDER BY ZTITLE \(order)
        LIMIT 1
        """

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }

    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(stmt, 1, currentTitle, -1, SQLITE_TRANSIENT)

    if sqlite3_step(stmt) == SQLITE_ROW, let cStr = sqlite3_column_text(stmt, 0) {
        return String(cString: cStr)
    }
    return nil
}

// MARK: - Main

guard let currentTitle = getCurrentNoteTitle() else {
    fputs("Error: Could not read current note title. Is Bear running?\n", stderr)
    exit(1)
}

guard let target = findAdjacentDailyNote(currentTitle: currentTitle, direction: direction) else {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    task.arguments = ["-e", "display notification \"No \(direction.rawValue) daily note found\""]
    try? task.run()
    task.waitUntilExit()
    exit(0)
}

let encoded = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
let url = URL(string: "bear://x-callback-url/open-note?title=\(encoded)")!
NSWorkspace.shared.open(url)
