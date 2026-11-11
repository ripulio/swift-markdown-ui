import Foundation

enum StyleRevisionID {
  private static let lock = NSLock()
  private static var counter: UInt64 = 1000

  static func next() -> UInt64 {
    self.lock.lock()
    defer { self.lock.unlock() }
    self.counter &+= 1
    return self.counter
  }
}
