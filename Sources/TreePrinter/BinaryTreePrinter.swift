import Foundation

public struct BinaryTreePrinter<Node: PrintableBinaryTreeProtocol>: TreePrinter {
    public let tree: Node
    public var options: TreePrintOptions

    public enum Style {
        /// **vertical**
        ///
        /// 水平显示树结构，非常直观但是如果树的节点过多，会导致输出的字符串宽度太宽，导致自动换行，阅读不便。
        /// 只建议在节点较少时使用。
        ///
        /// ```
        ///        1
        ///     ┌──┴──┐
        ///     2     3
        ///  ┌──┴──┐
        ///  4    nil
        /// ```
        ///
        ///  特征和限制：
        ///  1. 当节点为 nil 时，输出为 `Options.nilFiller` 配置的值，仅在其兄弟节点存在时输出。
        ///  2. 左右子节点的宽度是一致的
        ///  3. 节点输出内容会在整个树中进行长度填充（填充的规则是尽量两边填充，如果多出一个字符，则尽量填充在右边）
        ///  4. 会删除树的左右两边的空格，但是不会删除节点内容长度对齐导致的空格。（如上描述 3 的右边没有空格，但是如果左右树调换，3的左边会有一个空格）
        case vertical

        /// **indented**
        ///
        /// 缩进树结构，相当 `vertical` 旋转90度的效果。
        /// 推荐使用此风格。
        ///
        /// ```
        /// │   ┌── 2
        /// |   |
        /// └── 1
        ///     |   ┌── 4
        ///     └── 3
        ///         └── nil
        /// ```
        /// 特征和限制：
        ///  1. 左节点在下方，右节点在上方。
        ///  2. 当节点为 nil 时，输出为 `Options.nilFiller` 配置的值，仅在其兄弟节点存在时输出。
        ///  3. 左右子树的宽度是相同的。
        ///  4. 相对于 `vertical` 风格，`indented` 不存在节点内容长度填充和对齐问题。
        ///  5. 如果树是左偏的，因为左右宽度对齐，会导致上方出现大量空格，会影响阅读，此时会删除上方的空格。
        case indented

        /// **directory**
        ///
        /// 类似文件目录结构的输出
        ///
        /// ```
        /// 1
        /// ├── 2
        /// └── 3
        ///     ├── nil
        ///     └── 4
        /// ```
        ///
        /// 特征和限制：
        ///  1. 左节点在上方，右节点在下方。
        ///  2. 当节点为 nil 时，输出为 `Options.nilFiller` 配置的值，仅在其兄弟节点存在时输出。
        ///  3. 不存在节点内容长度填充和对齐问题。
        case directory
    }

    public init(_ tree: Node, options: TreePrintOptions = .default) {
        self.tree = tree
        self.options = options
    }

    /// 默认使用 `indented` 风格输出
    public func print() -> String {
        indented()
    }

    /// 输出指定风格的字符串树结构
    public func print(style: Style) -> String {
        switch style {
        case .indented:
            return indented()
        case .vertical:
            return vertical()
        case .directory:
            return directory()
        }
    }
}

// MARK: - vertical

extension BinaryTreePrinter {
    // 生成二叉树的矩阵表示
    private func generateVerticalStyleMatrix(root: Node) -> [[String]] {
        // 计算树的高度
        func getHeight(_ node: Node?) -> Int {
            guard let node = node else { return 0 }
            return 1 + max(getHeight(node.lNode), getHeight(node.rNode))
        }
        // 填充连接线
        func fillJoinLine(matrix: inout [[String]], row: Int, low: Int, high: Int) {
            if low <= high {
                for i in low ... high {
                    matrix[row * 2 + 1][i] = options.characters.horizontal
                }
            }
        }
        let spacer = " "
        let height = getHeight(root)
        let maxWidth = (1 << height) - 1 // 2^height - 1

        var matrix: [[String]] = Array(repeating: Array(repeating: spacer, count: maxWidth), count: height * 2)

        // BFS 填充矩阵
        var queue = [(node: root, row: 0, col: (maxWidth - 1) / 2)]

        while !queue.isEmpty {
            let (currentNode, row, col) = queue.removeFirst()

            // 计算子节点的偏移量
            let offset = 1 << (height - row - 2)

            let lNode = currentNode.lNode
            let rNode = currentNode.rNode
            let displayName = currentNode.displayName

            // 填充当前节点值
            matrix[row * 2][col] = displayName

            // 左子节点
            if let left = lNode {
                queue.append((node: left, row: row + 1, col: col - offset))
                matrix[row * 2 + 1][col - offset] = options.characters.cornerTopLeft
                fillJoinLine(matrix: &matrix, row: row, low: col - offset + 1, high: col - 1)
            } else if rNode != nil {
                matrix[(row + 1) * 2][col - offset] = options.nilFiller
            }

            // 右子节点
            if let right = rNode {
                queue.append((node: right, row: row + 1, col: col + offset))
                matrix[row * 2 + 1][col + offset] = options.characters.cornerTopRight
                fillJoinLine(matrix: &matrix, row: row, low: col + 1, high: col + offset - 1)
            } else if lNode != nil {
                matrix[(row + 1) * 2][col + offset] = options.nilFiller
            }

            // 如果有子节点，填充连接线
            if lNode != nil || rNode != nil {
                matrix[row * 2 + 1][col] = options.characters.teeBottom

                if lNode == nil {
                    matrix[row * 2 + 1][col - offset] = options.characters.cornerTopLeft
                    fillJoinLine(matrix: &matrix, row: row, low: col - offset + 1, high: col - 1)
                }

                if rNode == nil {
                    matrix[row * 2 + 1][col + offset] = options.characters.cornerTopRight
                    fillJoinLine(matrix: &matrix, row: row, low: col + 1, high: col + offset - 1)
                }
            }
        }

        // 对齐矩阵中的元素
        let maxLength = matrix.flatMap { $0 }.map { $0.count }.max() ?? 0

        for i in 0 ..< matrix.count {
            for j in 0 ..< matrix[i].count {
                let padding = maxLength - matrix[i][j].count
                let leftPadding = padding / 2
                let rightPadding = padding - leftPadding
                let word = matrix[i][j].trimmingCharacters(in: .whitespacesAndNewlines)
                if [options.characters.teeBottom, options.characters.horizontal, options.characters.cornerTopLeft, options.characters.cornerTopRight].contains(word) {
                    if word == options.characters.cornerTopRight {
                        matrix[i][j] = String(repeating: options.characters.horizontal, count: leftPadding) + matrix[i][j] + String(repeating: spacer, count: rightPadding)
                    } else if word == options.characters.cornerTopLeft {
                        matrix[i][j] = String(repeating: spacer, count: leftPadding) + matrix[i][j] + String(repeating: options.characters.horizontal, count: rightPadding)
                    } else {
                        matrix[i][j] = String(repeating: options.characters.horizontal, count: leftPadding) + matrix[i][j] + String(repeating: options.characters.horizontal, count: rightPadding)
                    }
                } else {
                    matrix[i][j] = String(repeating: spacer, count: leftPadding) + matrix[i][j] + String(repeating: spacer, count: rightPadding)
                }
            }
        }

        return matrix
    }

    /// 直观的垂直结构
    private func vertical() -> String {
        var matrix = generateVerticalStyleMatrix(root: tree)

        // 因为我的矩阵是左右对齐的，如果左右树高度不同，那么左右两边可能存在空格，目前左右两侧的空格都会删除，
        // 后期应该会提供一个参数控制。

        // 计算有几行需要删除
        var doRemoveCols = 0
        for j in 0 ..< matrix[0].count {
            var isEmpty = true
            for i in 0 ..< matrix.count {
                if matrix[i][j].trimmingCharacters(in: .whitespacesAndNewlines) != "" {
                    isEmpty = false
                    break
                }
            }
            if isEmpty == true {
                doRemoveCols += 1
            } else {
                break
            }
        }

        for i in 0 ..< matrix.count {
            for _ in 0 ..< doRemoveCols {
                matrix[i].removeFirst()
            }
        }

        // 将矩阵转换为字符串
        // 删除每一行的末尾空格
        // 删除空行
        return matrix.map { trimTrailingSpaces($0.joined(separator: "")) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }
}

// MARK: - indented

extension BinaryTreePrinter {
    private func generateIndentedStyleMatrix(root: Node) -> [[String]] {
        // 计算树的高度
        func getHeight(_ node: Node?) -> Int {
            guard let node = node else { return 0 }
            return 1 + max(getHeight(node.lNode), getHeight(node.rNode))
        }
        func fillJoinLine(matrix: inout [[String]], row: Int, low: Int, high: Int) {
            if low <= high {
                for i in low ... high {
                    matrix[row * 4 + 4][i] = options.characters.horizontal
                }
            }
        }
        let spacer = " "
        let height = getHeight(root)
        let maxWidth = (1 << height) - 1 // 2^height - 1

        /// 水平方向的坐标好计算一些后面再旋转90就好了
        /// 这里高度乘 4 了
        /// 第一层是 元素内容 + 符号
        /// 第二层是 连接符号
        /// 第三层是 连接符号
        /// 第四层是 空格
        var matrix: [[String]] = Array(repeating: Array(repeating: spacer, count: maxWidth), count: height * 4 + 4)

        // BFS 填充矩阵
        var queue = [(node: root, row: 0, col: (maxWidth - 1) / 2)]

        while !queue.isEmpty {
            let (currentNode, row, col) = queue.removeFirst()

            // 计算子节点的偏移量
            let offset = 1 << (height - row - 2)

            let lNode = currentNode.lNode
            let rNode = currentNode.rNode
            let displayName = currentNode.displayName

            // 填充当前节点值
            // 为啥要加4呢，因为 root 前面会有一层指向
            matrix[row * 4 + 4][col] = displayName

            // 左子节点
            if let left = lNode {
                queue.append((node: left, row: row + 1, col: col - offset))
                matrix[row * 4 + 4][col - offset] = options.characters.cornerTopLeft
                matrix[row * 4 + 4 + 1][col - offset] = options.characters.vertical
                matrix[row * 4 + 4 + 2][col - offset] = options.characters.vertical
                fillJoinLine(matrix: &matrix, row: row, low: col - offset + 1, high: col - 1)
            } else if rNode != nil {
                matrix[(row + 1) * 4 + 4][col - offset] = options.nilFiller
            }

            // 右子节点
            if let right = rNode {
                queue.append((node: right, row: row + 1, col: col + offset))
                matrix[row * 4 + 4][col + offset] = options.characters.cornerTopRight
                matrix[row * 4 + 4 + 1][col + offset] = options.characters.vertical
                matrix[row * 4 + 4 + 2][col + offset] = options.characters.vertical
                fillJoinLine(matrix: &matrix, row: row, low: col + 1, high: col + offset - 1)
            } else if lNode != nil {
                matrix[(row + 1) * 4 + 4][col + offset] = options.nilFiller
            }

            // 如果有子节点，填充连接线
            if lNode != nil || rNode != nil {
                if lNode == nil {
                    matrix[row * 4 + 4][col - offset] = options.characters.cornerTopLeft
                    matrix[row * 4 + 4 + 1][col - offset] = options.characters.vertical
                    matrix[row * 4 + 4 + 2][col - offset] = options.characters.vertical
                    fillJoinLine(matrix: &matrix, row: row, low: col - offset + 1, high: col - 1)
                }

                if rNode == nil {
                    matrix[row * 4 + 4][col + offset] = options.characters.cornerTopRight
                    matrix[row * 4 + 4 + 1][col + offset] = options.characters.vertical
                    matrix[row * 4 + 4 + 2][col + offset] = options.characters.vertical
                    fillJoinLine(matrix: &matrix, row: row, low: col + 1, high: col + offset - 1)
                }
            }
        }

        // 对齐矩阵中的元素
        // 垂直的不需要对齐

        return matrix
    }

    /// 缩进树结构（左右子节点在中间节点的上下两边）
    private func indented() -> String {
        var matrix = rotateMatrixLeft(generateIndentedStyleMatrix(root: tree))

        let spacer = " "
        let width = matrix.count
        for i in 0 ..< matrix.count {
            for j in 0 ..< matrix[i].count {
                let item = matrix[i][j]
                if item.contains(options.characters.cornerTopRight) {
                    matrix[i][j] = options.characters.cornerTopLeft
                } else if item.contains(options.characters.cornerTopLeft) {
                    matrix[i][j] = options.characters.cornerBottomLeft
                } else if item.contains(options.characters.horizontal) {
                    matrix[i][j] = options.characters.vertical
                } else if item.contains(options.characters.vertical) {
                    matrix[i][j] = options.characters.horizontal
                } else if item.contains(options.characters.teeBottom) {
                    matrix[i][j] = spacer
                }
            }

            let mid = width / 2

            if i < mid {
                matrix[i][0] = options.characters.vertical
            } else if i == mid {
                matrix[i][0] = options.characters.cornerBottomLeft
                matrix[i][1] = options.characters.horizontal
                matrix[i][2] = options.characters.horizontal
            }
        }

        // 如果左树高度比右树高，那么上面会有很多空行，需要删除
        // 这个方法是没有填充字符串进行对齐的，直接判断是否为空就行。
        while let firstRow = matrix.first, firstRow.dropFirst().allSatisfy({ $0 == spacer }) {
            matrix.removeFirst()
        }

        // 将矩阵转换为字符串
        // 删除每一行的末尾空格
        // 删除空行
        return matrix.map { trimTrailingSpaces($0.joined(separator: "")) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }
}

// MARK: - directory

extension BinaryTreePrinter {
    private func directory() -> String {
        var result = ""
        let spacer = " "
        let spacesPerDepth = 4
        // 使用栈来存储 (节点, 是否是最后一个子节点, 当前的缩进)
        var stack: [(Node?, Bool, String)] = [(tree, true, "")]

        while !stack.isEmpty {
            var (node, isLast, indent) = stack.removeLast()

            // 输出当前节点
            if isLast {
                result += indent
                result += options.characters.cornerBottomLeft
                result += String(repeating: options.characters.horizontal, count: spacesPerDepth - 2)
                result += spacer
                result += "\(node?.displayName ?? options.nilFiller)\n"

                indent += String(repeating: spacer, count: spacesPerDepth)
            } else {
                result += indent
                result += options.characters.teeLeft
                result += String(repeating: options.characters.horizontal, count: spacesPerDepth - 2)
                result += spacer
                result += "\(node?.displayName ?? options.nilFiller)\n"

                indent += options.characters.vertical
                indent += String(repeating: spacer, count: spacesPerDepth - 1)
            }

            // 先压入右子树（后处理），再压入左子树（先处理）
            var children: [(Node?, Bool)] = []

            // 左右任意一个节点有值就需要输出完整结构，都为空就不输出子结构
            guard node?.lNode != nil || node?.rNode != nil else {
                continue
            }

            children.append((node?.lNode, false))
            children.append((node?.rNode, true))

            // 将子节点按顺序压入栈中
            for (child, isLastChild) in children.reversed() {
                stack.append((child, isLastChild, indent))
            }
        }
        // 删除最后一个换行符号
        result.removeLast()
        return result
    }
}

extension BinaryTreePrinter {
    /// 删除每一行的末尾空格-（vertical 的实现需要）
    private func trimTrailingSpaces(_ string: String) -> String {
        var characters = Array(string)
        // 从尾部向前遍历删除空格
        while let last = characters.last, last.isWhitespace {
            characters.removeLast()
        }
        return String(characters)
    }

    // 矩阵向左旋转90度
    private func rotateMatrixLeft(_ matrix: [[String]]) -> [[String]] {
        let m = matrix.count
        let n = matrix[0].count
        var rotated = Array(repeating: Array(repeating: "", count: m), count: n)

        for i in 0 ..< m {
            for j in 0 ..< n {
                rotated[n - 1 - j][i] = matrix[i][j]
            }
        }
        return rotated
    }
}
