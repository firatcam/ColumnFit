import Cocoa

let application = NSApplication.shared
application.setActivationPolicy(.accessory)          // menu bar only, no Dock icon
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
