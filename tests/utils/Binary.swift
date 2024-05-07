extension BinaryInteger {
    /// Prints the underlying bits representing the receiving integer.
    internal var binary: String {
        var binaryString = ""
        var internalNumber = self
        var counter = Int.zero
        
        for _ in (1...self.bitWidth) {
            binaryString.insert(contentsOf: "\(internalNumber & 1)", at: binaryString.startIndex)
            internalNumber >>= 1
            counter += 1
            if counter % 4 == .zero {
                binaryString.insert(contentsOf: " ", at: binaryString.startIndex)
            }
        }
        
        return binaryString
    }
}
