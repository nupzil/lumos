public struct MultiwayTreePrinter<Node: PrintableMultiwayTreeProtocol>: TreePrinter {
    public let tree: Node
    public var options: TreePrintOptions
    
    public init(_ tree: Node, options: TreePrintOptions = .default) {
        self.tree = tree
        self.options = options
    }
    
    /// 输出多叉树的字符串结构
    public func print() -> String {
        directory()
    }
}

// MARK: - 文件目录风格的输出

extension MultiwayTreePrinter {
    private func directory() -> String {
        var output = ""
        let spacer = " "
        let spacesPerDepth = 4
        var stack: [(Node, Int, Bool, Set<Int>)] = [(tree, 0, true, Set())]
                
        while let (node, depth, isLast, depthsFinished) = stack.popLast() {
            var line = ""
            for i in 0 ..< max(depth - 1, 0) * spacesPerDepth {
                if i % spacesPerDepth == 0 && !depthsFinished.contains(i / spacesPerDepth + 1) {
                    line += options.characters.vertical
                } else {
                    line += spacer
                }
            }
                    
            if depth > 0 {
                line += isLast ? options.characters.cornerBottomLeft : options.characters.teeLeft
                line += options.characters.horizontal
                line += options.characters.horizontal
                line += spacer
            }
            output += line + node.displayName + "\n"
                    
            let newDepthsFinished = isLast ? depthsFinished.union([depth]) : depthsFinished
            let subnodes = node.subnodes
            for i in (0 ..< subnodes.count).reversed() {
                stack.append((subnodes[i], depth + 1, i == subnodes.count - 1, newDepthsFinished))
            }
        }
        // 删除尾随的空格
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
