extension BinaryInteger {
    fileprivate var binary: String {
        var binaryString = ""
        var internalNumber = self
        var counter = 0
        
        for _ in (1...self.bitWidth) {
            binaryString.insert(contentsOf: "\(internalNumber & 1)", at: binaryString.startIndex)
            internalNumber >>= 1
            counter += 1
            if counter % 4 == 0 {
                binaryString.insert(contentsOf: " ", at: binaryString.startIndex)
            }
        }
        
        return binaryString
    }
}
