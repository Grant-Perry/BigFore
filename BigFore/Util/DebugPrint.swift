//
import Foundation
import os.log
import Synchronization

enum DebugConfig {
	  /// Change this to focus debug output on specific areas
	  ///
	  /// Examples:
	  /// - `.none` - No debug output (production)
	  /// - `.all` - Everything (verbose)
	  /// - `.globalRefresh` - Only global refresh logs
	  /// - `[.keyboard, .selection]` - Multiple specific areas
	  ///
	  ///
	  ///  DO NOT DELETE:  the DebugMode is HERE ─────┐
	  ///                                           │
	  ///                         ┌──────────┘
	  ///                         ▼
   nonisolated static let activeMode = Mutex(DebugMode.none) // [.keyboard, .selection]

	  /// Reset all iteration counters (useful for testing)
   nonisolated static func resetIterations() {
	  debugPrintState.withLock { state in
		 state.iterations.removeAll()
	  }
   }
}

   /// Debug mode flags - combine multiple modes to focus on specific areas
struct DebugMode: OptionSet, Sendable {
   let rawValue: Int

	  // MARK: debugMode definitions

   nonisolated static let none               	= DebugMode([])
   nonisolated static let globalRefresh		= DebugMode(rawValue: 1 << 0)   // 1
   nonisolated static let keyboard           	= DebugMode(rawValue: 1 << 1)   // 2


	  // Convenience combos
   nonisolated static let all: DebugMode = [
	  .globalRefresh, .keyboard
   ]
}

   // MARK: - Iteration Tracking

private struct DebugPrintState {
   var iterations: [String: Int] = [:]
}

   /// Tracks how many times each debug statement has printed (by file:line)
nonisolated private let debugPrintState = Mutex(DebugPrintState())

   // MARK: - Debug Print Function

   /// Flexible debug print with mode filtering and iteration limiting
nonisolated func DebugPrint(
   mode: DebugMode,
   limit: Int = 0,
   file: String = #file,
   line: Int = #line,
   function: String = #function,
   _ message: @autoclosure () -> String
) {
	  // Early exit if mode isn't active
   let activeMode = DebugConfig.activeMode.withLock { $0 }
   guard activeMode.rawValue & mode.rawValue != 0 else {
	  return
   }

	  // Build the actual message
   let fileName = (file as NSString).lastPathComponent
   let actualMessage = message()

	  // Handle iteration limiting
   if limit > 0 {
	  let key = "\(file):\(line)"
	  let nextCount: Int? = debugPrintState.withLock { state in
		 let count = state.iterations[key, default: 0]
		 guard count < limit else { return nil }
		 state.iterations[key] = count + 1
		 return count + 1
	  }

	  guard let nextCount else { return }

		 // Print with iteration info
	  let iterInfo = "[\(nextCount)/\(limit)]"
	  print("[\(fileName):\(line)] \(function) \(iterInfo) - \(actualMessage)")
   } else {
		 // Normal print without iteration tracking
	  print("[\(fileName):\(line)] \(function) - \(actualMessage)")
   }
}
