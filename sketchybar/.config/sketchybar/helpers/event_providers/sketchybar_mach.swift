import Darwin

@_silgen_name("sketchybar_send_args")
func sketchybar_send_args(_ argc: Int32, _ argv: UnsafePointer<UnsafePointer<CChar>?>?) -> Bool

func sketchybarSend(_ arguments: [String]) -> Bool {
	guard !arguments.isEmpty else { return false }

	var cStrings: [UnsafeMutablePointer<CChar>] = []
	cStrings.reserveCapacity(arguments.count)
	for argument in arguments {
		guard let copied = strdup(argument) else {
			cStrings.forEach { free($0) }
			return false
		}
		cStrings.append(copied)
	}
	defer {
		cStrings.forEach { free($0) }
	}

	let argv: [UnsafePointer<CChar>?] = cStrings.map { UnsafePointer($0) }
	var ok = false
	argv.withUnsafeBufferPointer { buffer in
		ok = sketchybar_send_args(Int32(arguments.count), buffer.baseAddress)
	}
	return ok
}
