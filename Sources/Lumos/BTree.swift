//  Created by vvgvjks on 2025/1/15.
//
//  Copyright © 2025 vvgvjks <vvgvjks@gmail.com>.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice
//  (including the next paragraph) shall be included in all copies or substantial
//  portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
//  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
//  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
//  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

/// BTree
///
/// 该实现无其他依赖，Debug 模式会依赖内部的另一个 TreePinter 模块, 为了性能避免函数调用开销，有不少重复代码。
/// 将持续为了性能进行优化。
///
/// ### B-Tree 设计特点
///
/// 1. 低层高优化查询性能
///    - 由于 B-Tree 在单个节点中存储多个键，与二叉树相比，它的层高显著降低。
///    - 层高较低意味着查找时的内存或磁盘访问次数减少，从而提升查询效率。
///
/// 2. 利用连续内存布局优化 CPU 缓存
///    - B-Tree 采用数组存储子节点，这种连续分配的方式能提高缓存命中率。
///    - 在 Swift 中，可使用 `ContiguousArray<Optional<Node>>` 存储子节点，进一步优化访问性能。
///
/// ### 定义
///
/// 该实现基于 Knuth 对 B-Tree 的定义，并符合其关键特性：
///  - 每个节点最多可拥有 m 个子节点。
///  - 除根节点和叶子节点外，每个节点至少包含 ⌈m/2⌉ 个子节点。
///  - 根节点至少包含两个子节点（除非它是叶子节点）。
///  - 所有叶子节点处于相同层级，保证树的平衡性。
///  - 拥有 K 个子节点的非叶节点存储 K-1 个键，以维持有序性。
///
/// ### Knuth 阶数 k 与 CLRS 度数 t 的对应关系如下：
///
/// Knuth Order, k  |  (min, max)   | CLRS Degree, t
///  -------------- | ------------- | --------------
///       3         |    (2, 3)     |        -
///       4         |    (2, 4)     |      t = 2
///       5         |    (3, 5)     |        -
///       6         |    (3, 6)     |      t = 3
///       7         |    (4, 7)     |        -
///       8         |    (4, 8)     |      t = 4
///       9         |    (5, 9)     |        -
///       10        |    (5, 10)    |      t = 5
///
/// ### `Sequence` 协议支持
///
/// B-Tree 本身不直接遵循 `Sequence` 协议，但提供以下两种遍历方式：
/// - `elementsSequence`：基于 **中序遍历**，返回符合 `Sequence` 协议的结构体。
/// - `reversedSequence`：基于 **后序遍历**，返回符合 `Sequence` 协议的结构体。
///
/// 这两种方式均提供 `Iterator` 实现，使其支持 `map`、`filter`、`reduce` 等方法。但建议优先使用 B-Tree 专有 API，以获得更好的性能。
///
/// ### 调试支持
///
/// - 实现 `CustomDebugStringConvertible`，可输出结构化字符串，便于分析和调试。
/// - 仅在 `#if DEBUG` 环境下生效。
///
///
/// ### 叶子节点 `children` 设计考量
///
/// 本实现不将叶子节点和中间节点拆分，而是让 `children` 采用 `Optional` 类型，主要基于以下权衡：
///
/// 1. **避免拆分带来的额外开销**
///    - **继承方案**：代码更优雅，但会引入 **动态派发**，增加运行时成本。
///    - **协议方案**：泛型协议难以直接用作类型，同时仍可能导致动态派发。
///    - **枚举方案**：每个节点需额外占用 8 字节，并带来额外的解包操作。
///
/// 2. **选择 `Optional` 作为更优解**
///    - `Optional` 方案同样增加 8 字节存储开销，但避免了类型拆分的复杂性。
///    - 代码更简洁，且访问 `children` 时只需进行简单解包，无需额外的类型判断或动态派发。
///
/// ### 对于 Top-Down 与 Bottom-Up 的插入与删除
///
/// 内部目前插入使用 Button-up 的方案，删除使用 Top-Down 的方案。
/// 但是在该实现中，两种方案都有实现，但是另一种方案没有暴露出来。
///
/// Top-Down
/// 1. 优点：
///    - 提前调整，减少回溯的开销，这使得在磁盘的场景下，性能要好很多，因为回溯会增加磁盘访问次数。
///    - 只需一次下降遍历。
/// 2. 缺点：
///    - 大量逻辑写在循环中，循环中分支比较多。
///    - 整体代码复杂度更高，逻辑可能不够清晰（特别是 remove ）
///    - 提前调整，这会增加一些不必要的调整，这会让一些操作速度变慢。
///
/// Bottom-Up
/// 1. 优点：
///    - 代码逻辑更清晰，代码简单易懂，是 BTree 的标准实现。
///    - 仅在需要调整时，才会去调整，这会让一些操作速度更加快。
///    - 代码中分支更少，可能在分支预测方面更有优势。
/// 2. 缺点：
///    - 极端场景，需要两次遍历，一次下降遍历，一次上升遍历。
///    - 需要回溯，这会增加磁盘访问次数。
///
/// 综上，在磁盘场景下，Top-Down 的方案性能会更好，在内存场景下，两者性能差距不大。
public class BTree<Key: Comparable, Value> {
    typealias Node = BTreeNode<Key, Value>
    public typealias Element = (Key, Value)

    /// 根节点
    var root: Node?

    /// 树的阶-表示内部子节点的最大数量
    /// 最小值为 3，表示每个内部节点最多存在 3 个子节点
    public let order: Int

    /// 树中存在的元素数目
    private var numberOfElements: Int

    /// 初始化
    public init(order: Int) {
        /// Top-Down 的插入至少需要 order = 4，而这里支持 order = 3 是因为内部的插入基于 Bottom-Up 的方案
        precondition(order >= 3, "Order must be greater than or equal to 3.")

        self.root = nil
        self.order = order
        self.numberOfElements = 0
    }

    public required convenience init() {
        // 16 是一个比较好的折中值：
        // 1. 对于大多数 Key/Value 类型，一个节点能装入 1-2 个缓存行
        // 2. 树的高度适中，3层可以存储约 4096 个元素
        // 3. 二分查找的开销不会太大（最多比较 4 次）
        self.init(order: 16)
    }
}

// MARK: - BTreeNode

/// 如果 BTree 的order比较大，并且其插入和删除操作比较多的话，内部使用其他结构代替数组会比较好，但是需要支持：
/// - 高效的随机访问
/// - 高效的中间节点删除
/// - 高效的中间节点插入
final class BTreeNode<Key: Comparable, Value> {
    /// 叶子节点不需要这个属性
    var children: [BTreeNode<Key, Value>]?

    /// values 和 keys 拆开可能局部性缓存会更好
    /// 是插入后，如果元素数目超出最大值（order - 1），则触发分裂。
    /// 故而 elements 的容量与 children 是一样的，其最后一个位置只会临时存在值。
    var keys: ContiguousArray<Key> = []
    var values: [Value] = []

    /// 是否是叶子节点
    var isLeaf: Bool { children == nil }

    init() {}

    init(keys: ContiguousArray<Key>, values: [Value], children: [BTreeNode<Key, Value>]? = nil) {
        self.keys = keys
        self.values = values
        self.children = children
    }

    /// 没有额外的判断，需要调用者保证 index 在有效范围内
    func keyValuePair(at index: Int) -> (Key, Value) {
        (keys[index], values[index])
    }
}

// MARK: - 初始化方法

public extension BTree {
    /// 批量加载的初始化方式
    ///
    /// 参数：
    /// - elements: 需要加载的元素数组
    /// - order: 树的阶，如果为 nil 则使用默认的阶
    ///
    /// 注意：
    /// - 元素数组必须是有序的，否则 debug 模式下会抛出异常
    /// - debug 模式下会进行有序性检查，release 模式为了性能不会进行检查
    /// - 有序性检查的复杂度为 O(n)
    convenience init(contentsOf elements: [Element], order: Int? = nil) {
        #if DEBUG
            for i in 1 ..< elements.count {
                if elements[i - 1].0 > elements[i].0 {
                    preconditionFailure("Error: contentsOf must be sorted by Key for optimal performance")
                }
            }
        #endif

        if let order {
            self.init(order: order)
        }
        else {
            self.init()
        }
        bulkLoad(contentsOf: elements)
    }

    /// 批量加载
    @inline(__always)
    private func bulkLoad(contentsOf elements: [Element]) {
        if elements.isEmpty { return }
        numberOfElements = elements.count

        var keys: ContiguousArray<Key> = []
        var values: [Value] = []

        keys.reserveCapacity(numberOfElements)
        values.reserveCapacity(numberOfElements)

        for element in elements {
            keys.append(element.0)
            values.append(element.1)
        }

        /// 如果元素数量小于等于一个节点的最大容量，直接创建根节点
        if elements.count <= order - 1 {
            root = createLeafNode(keys: keys[0...], values: values[0...])
            return
        }

        var index = 0
        var nodes: [Node] = []
        /// 预估叶子节点数量
        nodes.reserveCapacity(elements.count / order + 1)

        /// 构建叶子节点，其中每个节点其值都超出限制
        /// 注意 BTree 在批量加载时，elements 需要预留一个位置用于提升，但是最后一个叶子节点是不需要预留的
        /// 这里按照 order 的数量构造一层叶子节点。
        while index < elements.count {
            let remainingElements = elements.count - index

            let nodeSize = Swift.min(order, remainingElements)
            nodes.append(createLeafNode(keys: keys[index ..< (index + nodeSize)], values: values[index ..< (index + nodeSize)]))
            index += nodeSize
        }

        /// 检查最后一个节点的元素的数量是否足够，不够就与其左兄弟节点借一个
        /// 注意左兄弟需要预留提升的元素，而右兄弟节点不需要。
        /// 注意如果最后一个节点的数量刚好 == order，那么因为最后一个节点不需要预留提升的问题，也需要重新分配

        /// == order - 1 就是完美状态，无需再次分配
        /// 不等于的话，就只有 == order 和小于 order - 1 两种情况了
        if nodes.last!.keys.count != order - 1 {
            /// 只需要重新分配最后一个节点
            var keys: ContiguousArray<Key> = []
            var values: [Value] = []

            if nodes.last!.keys.count == order {
                let lastNode = nodes.removeLast()
                keys = lastNode.keys
                values = lastNode.values
            }
            else {
                /// 此时需要将倒数两个节点进行重新分配, 此处是必定存在两个节点的。
                let node2 = nodes.removeLast()
                let node1 = nodes.removeLast()

                keys = node1.keys + node2.keys
                values = node1.values + node2.values
            }

            let splitIndex = keys.count / 2
            /// 左节点需要保留需要提升的节点
            let leftNode = createLeafNode(keys: keys[...splitIndex], values: values[...splitIndex])
            let rightNode = createLeafNode(keys: keys[(splitIndex + 1)...], values: values[(splitIndex + 1)...])
            nodes.append(leftNode)
            nodes.append(rightNode)
        }

        /// 自底向上构建非叶子节点
        /// children 的数量是 order 而 elements 的数量也是 order 但是 elements 的最后一个位置将会提升
        /// 故而这里创建下一层节点时，还是按照 order 一组创建
        while nodes.count > 0 {
            var nexts: [Node] = []

            /// 如果节点数量小于等于 order，则直接创建根内部节点
            if nodes.count <= order {
                var keys: ContiguousArray<Key> = []
                var values: [Value] = []

                keys.reserveCapacity(order)
                values.reserveCapacity(order)

                /// 最后一个节点的 node 无需提升
                for index in 0 ..< (nodes.count - 1) {
                    keys.append(nodes[index].keys.removeLast())
                    values.append(nodes[index].values.removeLast())
                }

                let node = Node(keys: keys, values: values, children: nodes)
                node.keys.reserveCapacity(order)
                node.values.reserveCapacity(order)
                node.children!.reserveCapacity(order)

                root = node
                break
            }

            /// 如果节点数量大于 order，则需要创建新的一层内部节点
            /// 这里创建的 nexts 的数量至少是 2 个
            var i = 0
            while i < nodes.count {
                var keys: ContiguousArray<Key> = []
                var values: [Value] = []
                var children: [Node] = []

                keys.reserveCapacity(order)
                values.reserveCapacity(order)
                children.reserveCapacity(order)

                while children.count < order, i < nodes.count {
                    // 最后一个节点无需向上提升
                    if i != nodes.endIndex - 1 {
                        /// 这里使用 removeLast 是因为 elements 的最后一个位置是预留的
                        keys.append(nodes[i].keys.removeLast())
                        values.append(nodes[i].values.removeLast())
                    }
                    children.append(nodes[i])
                    i += 1
                }

                let node = Node(keys: keys, values: values, children: children)
                node.keys.reserveCapacity(order)
                node.values.reserveCapacity(order)
                node.children!.reserveCapacity(order)

                nexts.append(node)
            }

            /// 检查上一步创建的 nexts 的最后一个节点是否需要进行借用操作
            /// 如果其最后一个节点的 keys.count == order - 1 就无需操作。

            if nexts.last!.keys.count != order - 1 {
                var keys: ContiguousArray<Key> = []
                var values: [Value] = []
                var children: [Node] = []

                if nexts.last!.keys.count == order {
                    let lastNode = nexts.removeLast()
                    keys = lastNode.keys
                    values = lastNode.values
                    children = lastNode.children!
                }
                else {
                    /// 此时需要将倒数两个节点进行重新分配, 此处是必定存在两个节点的。
                    let node2 = nexts.removeLast()
                    let node1 = nexts.removeLast()

                    keys = node1.keys + node2.keys
                    values = node1.values + node2.values
                    children = node1.children! + node2.children!
                }

                let splitIndex = keys.count / 2

                let leftChild = createInternalNode()
                leftChild.keys.append(contentsOf: keys[...splitIndex])
                leftChild.values.append(contentsOf: values[...splitIndex])
                leftChild.children!.append(contentsOf: children[...splitIndex])

                let rightChild = createInternalNode()
                rightChild.keys.append(contentsOf: keys[(splitIndex + 1)...])
                rightChild.values.append(contentsOf: values[(splitIndex + 1)...])
                rightChild.children!.append(contentsOf: children[(splitIndex + 1)...])

                nexts.append(leftChild)
                nexts.append(rightChild)
            }

            nodes = nexts
        }
    }
}

// MARK: - 内部方法

extension BTree {
    /// 按照最坏情况估算树的高度
    /// 计算公式：以 m 为底的 n 的对数 m 是最小子节点数，n 是总元素数量。
    ///
    /// 1万亿 数据在 order = 3 的 BTree 中：
    ///  - 最坏：math.log(1000000000000) / math.log(2) + 1 = 40
    ///  - 最佳：math.log(1000000000000) / math.log(3) + 1 = 26
    ///
    /// 这已经是差距最大的场景了，如果 order 更大，这里的差别会更小。
    ///
    /// 由此可见差距并不大，浪费的内存空间是可控的，并且保证了不会触发数组扩容。
    @inline(__always)
    private var estimatedTreeHeight: Int {
        guard numberOfElements > 1 else { return 0 }
        assert(order > 2, "order must be greater than 2")
        return estimatedHeight(order: order, numberOfElements: numberOfElements)
    }

    // 模块级别方法，用于测试
    @inline(__always)
    func estimatedHeight(order: Int, numberOfElements: Int) -> Int {
        return log(Double((order + 1) / 2), numberOfElements) + 1
    }

    /// 计算以 m 为底 n 的对数（避开 Foundation 的依赖）
    ///
    /// 因为是私有方法，所以没有边界检查，需要使用方保证 n 和 m 都大于 1
    @inline(__always)
    private func log(_ m: Double, _ n: Int) -> Int {
        var result = 0
        var value = 1.0

        // 使用二分查找找到最小的 k 使得 m^k >= n
        while value < Double(n) {
            value *= m
            result += 1
        }

        return result
    }

    @inline(__always)
    private func createLeafNode() -> Node {
        let node = Node()
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)
        return node
    }

    @inline(__always)
    private func createLeafNode(key: Key, value: Value) -> Node {
        let node = Node(keys: [key], values: [value], children: nil)
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)
        return node
    }

    @inline(__always)
    private func createLeafNode(keys: ArraySlice<Key>, values: ArraySlice<Value>) -> Node {
        let node = Node()
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)

        node.keys.append(contentsOf: keys)
        node.values.append(contentsOf: values)
        return node
    }

    @inline(__always)
    private func createInternalNode() -> Node {
        let node = Node(keys: [], values: [], children: [])
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)
        node.children!.reserveCapacity(order)
        return node
    }

    @inline(__always)
    private func createInternalNode(keys: ArraySlice<Key>, values: ArraySlice<Value>, children: ArraySlice<Node>) -> Node {
        let node = Node(keys: [], values: [], children: [])
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)
        node.children!.reserveCapacity(order)

        node.keys.append(contentsOf: keys)
        node.values.append(contentsOf: values)
        node.children!.append(contentsOf: children)
        return node
    }

    /// 树高增加时使用
    @inline(__always)
    private func createInternalNode(element: Element, left: Node, right: Node) -> Node {
        let node = Node(keys: [element.0], values: [element.1], children: [left, right])
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)
        node.children!.reserveCapacity(order)
        return node
    }

    /// 查找指定的 Key 在 elements 中的下边界
    @inline(__always)
    private func findLowerBoundIndex(node: Node, key: Key) -> Int {
        /// 当数据量较小时比如小于16时，循环查找通常性能更优。
        node.keys.count <= 16 ? linearSearchLowerBound(node, key: key) : binarySearchLowerBound(node, key: key)
    }

    /// 使用二分查找的 Lower Bound Search
    /// 使用二分搜索找到指定 Key 的插入点即：
    /// 1. 如果指定的 Key 存在，则返回对应下标
    /// 2. 如果指定的 Key 不存在，返回第一个大于 Key 的元素的下标
    @inline(__always)
    private func binarySearchLowerBound(_ node: Node, key: Key) -> Int {
        var lowerBound = 0
        var upperBound = node.keys.count
        while lowerBound < upperBound {
            let midIndex = lowerBound + (upperBound - lowerBound) / 2
            if node.keys[midIndex] == key {
                return midIndex
            }
            else if node.keys[midIndex] < key {
                lowerBound = midIndex + 1
            }
            else {
                upperBound = midIndex
            }
        }
        return lowerBound
    }

    /// 使用遍历查找的 Lower Bound Search
    /// 1. 如果指定的 Key 存在，则返回对应下标
    /// 2. 如果指定的 Key 不存在，返回第一个大于 Key 的元素的下标
    @inline(__always)
    private func linearSearchLowerBound(_ node: Node, key: Key) -> Int {
        node.keys.withUnsafeBufferPointer { buffer in
            var index = 0
            let count = node.keys.count
            while index < count {
                if buffer[index] >= key {
                    return index
                }
                index += 1
            }
            return count
        }
    }
}

// MARK: - 计算属性

public extension BTree {
    /// 树中存在的元素数目
    ///
    /// 时间复杂度：O(1)
    var count: Int { numberOfElements }

    /// 是否为空
    ///
    /// 时间复杂度：O(1)
    var isEmpty: Bool { numberOfElements == 0 }

    /// 树的高度
    ///
    /// 时间复杂度：O(log n)
    var height: Int {
        guard let root = root else { return 0 }
        var height = 0
        var current: Node = root
        while current.isLeaf == false {
            height += 1
            current = current.children!.first!
        }
        return height + 1
    }

    /// 集合中最小的元素（升序排序下的第一个元素），若集合为空则返回 nil
    ///
    /// 时间复杂度：O(log n)
    var min: Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children!.first!
        }
        return current.keyValuePair(at: 0)
    }

    /// 集合中最大的元素（升序排序下的最后一个元素），若集合为空则返回 nil
    ///
    /// 时间复杂度：O(log n)
    var max: Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children!.last!
        }
        return current.keyValuePair(at: current.keys.endIndex - 1)
    }

    /// 集合中所有键的数组
    ///
    /// 时间复杂度：O(log n + n)
    var keys: [Key] {
        guard numberOfElements > 0 else { return [] }
        return [Key](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current = root
            var stack: [(node: Node, index: Int)] = []
            stack.reserveCapacity(estimatedTreeHeight)

            while current != nil || stack.isEmpty == false {
                while let node = current {
                    stack.append((node, 0))
                    current = node.children?.first
                }
                guard let (node, index) = stack.last else {
                    break
                }
                buffer[initializedCount] = node.keys[index]
                initializedCount += 1

                /// 更新 index
                stack[stack.endIndex - 1].index += 1

                if index + 1 == node.keys.count {
                    stack.removeLast()
                }

                /// 如果有右子树，则继续下降
                if index + 1 <= node.keys.count, node.isLeaf == false {
                    current = node.children![index + 1]
                }
            }
        }
    }

    /// 集合中所有值的数组
    ///
    /// 时间复杂度：O(log n + n)
    var values: [Value] {
        guard numberOfElements > 0 else { return [] }
        return [Value](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current = root
            var stack: [(node: Node, index: Int)] = []
            stack.reserveCapacity(estimatedTreeHeight)
            while current != nil || stack.isEmpty == false {
                while let node = current {
                    stack.append((node, 0))
                    current = node.children?.first
                }

                guard let (node, index) = stack.last else {
                    break
                }

                buffer[initializedCount] = node.values[index]
                initializedCount += 1

                /// 更新 index
                stack[stack.endIndex - 1].index += 1

                if index + 1 == node.keys.count {
                    stack.removeLast()
                }

                /// 如果有右子树，则继续下降
                if index + 1 <= node.keys.count, node.isLeaf == false {
                    current = node.children![index + 1]
                }
            }
        }
    }

    /// 返回按升序排列的所有元素数组
    ///
    /// 时间复杂度：O(log n + n)
    var elements: [Element] {
        guard numberOfElements > 0 else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current = root
            var stack: [(node: Node, index: Int)] = []
            stack.reserveCapacity(estimatedTreeHeight)
            while current != nil || stack.isEmpty == false {
                while let node = current {
                    stack.append((node, 0))
                    current = node.children?.first
                }

                guard let (node, index) = stack.last else {
                    break
                }

                buffer[initializedCount] = node.keyValuePair(at: index)
                initializedCount += 1

                /// 更新 index
                stack[stack.count - 1].index += 1

                if index + 1 == node.keys.count {
                    stack.removeLast()
                }

                /// 如果有右子树，则继续下降
                if index + 1 <= node.keys.count, node.isLeaf == false {
                    current = node.children![index + 1]
                }
            }
        }
    }

    /// 返回按降序排列的所有元素数组
    ///
    /// 时间复杂度：O(log n + n)
    var reversed: [Element] {
        guard numberOfElements > 0 else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current = root
            var stack: [(node: Node, index: Int)] = []
            stack.reserveCapacity(estimatedTreeHeight)
            while current != nil || stack.isEmpty == false {
                while let node = current {
                    stack.append((node, node.keys.count - 1))
                    current = node.children?.last
                }

                guard let (node, index) = stack.last else {
                    break
                }

                buffer[initializedCount] = node.keyValuePair(at: index)
                initializedCount += 1

                /// 更新 index
                stack[stack.count - 1].index -= 1

                if index == 0 {
                    stack.removeLast()
                }

                /// 如果有左子树，则继续下降
                if index >= 0, node.isLeaf == false {
                    current = node.children![index]
                }
            }
        }
    }

    /// 返回一个实现了 Sequence 协议的序列，用于遍历所有元素
    /// 返回的 Sequence 是持有 BTree 的引用，所以遍历的元素是共享的。当 BTree 修改时，Sequence 也会随之修改。
    ///
    /// 时间复杂度：O(1)
    var elementsSequence: BTreeSequence<Key, Value> {
        BTreeSequence(self)
    }

    /// 返回一个实现了 Sequence 协议的序列，用于降序遍历所有元素
    /// 返回的 Sequence 是持有 BTree 的引用，所以遍历的元素是共享的。当 BTree 修改时，Sequence 也会随之修改。
    ///
    /// 时间复杂度：O(1)
    var reversedSequence: BTreeReversedSequence<Key, Value> {
        BTreeReversedSequence(self)
    }
}

// MARK: - 核心方法

public extension BTree {
    /// 查找给定键对应的值，若存在则返回该值，否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func search(key: Key) -> Value? {
        guard let root else { return nil }

        var current = root
        while true {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            if lowerBoundIndex < current.keys.count, current.keys[lowerBoundIndex] == key {
                return current.values[lowerBoundIndex]
            }
            if current.isLeaf {
                return nil
            }
            current = current.children![lowerBoundIndex]
        }
    }

    /// 插入一个键值对 - 基于 Bottom-Up 的实现方式
    ///
    /// - 如果键已存在，则不进行插入并返回 false
    /// - 如果插入成功，则返回 true
    ///
    /// 逻辑：
    /// - 插入只在叶子节点插入。
    /// - 先下降到叶子节点并记录访问路径。
    /// - 如果目标键已存在，则直接返回。
    /// - 插入然后回溯处理分裂。
    /// - 检查树的层高是否有提升。
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func insert(key: Key, value: Value) -> Bool {
        guard let root = root else {
            numberOfElements = 1
            self.root = createLeafNode(key: key, value: value)
            return true
        }

        /// 定位到将要插入的节点位置
        var insertPos = 0
        var current: Node = root
        /// 记录访问路径用以回溯
        var ancestorPath: [(Node, Int)] = []
        ancestorPath.reserveCapacity(estimatedTreeHeight)
        while true {
            insertPos = findLowerBoundIndex(node: current, key: key)
            ancestorPath.append((current, insertPos))
            /// 如果对应的 key 存在于树中，则直接返回
            if insertPos < current.keys.count, current.keys[insertPos] == key {
                return false
            }
            /// 不能在 while 写这个，也需要再叶子节点执行内部 while 逻辑
            if current.isLeaf {
                break
            }
            current = current.children![insertPos]
        }

        /// 插入
        numberOfElements += 1
        current.keys.insert(key, at: insertPos)
        current.values.insert(value, at: insertPos)

        /// Bottom-Up 的实现是在插入后超出限制才分裂的。
        if current.keys.count < order {
            return true
        }

        /// 元素分裂点
        /// ceil(order / 2) 是 min 和 max 子节点数，分割点需要 - 1
        let splitIndex = (order + 1) / 2 - 1
        /// 指针修改
        var leftChild = current
        /// 将要被提升的 element
        var promotedKey = current.keyValuePair(at: splitIndex)
        /// 复制 elements 到新的右兄弟节点。
        var rightChild = createLeafNode(keys: current.keys[(splitIndex + 1)...], values: current.values[(splitIndex + 1)...])
        /// 删除被提升和已复杂到右兄弟节点的 elements
        current.keys.removeSubrange(splitIndex...)
        current.values.removeSubrange(splitIndex...)

        /// 删除最后一个叶子节点
        ancestorPath.removeLast()

        /// 向上回溯操作
        /// 返回的是 ReversedCollection，这是一个轻量级的封装
        ancestorPath.withUnsafeBufferPointer { buffer in
            var bufferIndex = buffer.count
            while bufferIndex > 0 {
                bufferIndex -= 1
                let (parent, index) = buffer[bufferIndex]

                /// 修改 left 指针
                parent.children![index] = leftChild
                /// 插入新的 element
                parent.keys.insert(promotedKey.0, at: index)
                parent.values.insert(promotedKey.1, at: index)
                /// 修改 right 指针
                parent.children!.insert(rightChild, at: index + 1)
                /// 如果中间节点插入后未满，就直接 break
                if parent.keys.count < order {
                    break
                }
                /// 指针修改
                leftChild = parent
                /// 需要提升的 key
                promotedKey = parent.keyValuePair(at: splitIndex)
                /// 复制到右边
                rightChild = createInternalNode(
                    keys: parent.keys[(splitIndex + 1)...],
                    values: parent.values[(splitIndex + 1)...],
                    children: parent.children![(splitIndex + 1)...]
                )
                /// 删除被提升的和复制到 right 节点的 elements
                parent.keys.removeSubrange(splitIndex...)
                parent.values.removeSubrange(splitIndex...)
                /// children 不会存在提升，所以无需删除 midIndex 对应的子节点
                parent.children!.removeSubrange((splitIndex + 1)...)
            }
        }
        // 如果遍历完所有祖先节点后，最后的节点仍然需要分裂
        // 说明需要创建新的根节点
        if leftChild === root {
            self.root = createInternalNode(element: promotedKey, left: leftChild, right: rightChild)
        }
        return true
    }

    /// 插入一个键值对 - 基于 Top-Down 的实现方式
    ///
    /// - 如果键已存在，则不进行插入并返回 false
    /// - 如果插入成功，则返回 true
    ///
    /// 逻辑：
    /// - 插入只在叶子节点插入。
    /// - 下降到叶子节点的过程中，检查节点是否会因为插入而导致分裂，如果是则提前进行分裂处理。
    /// - 如果目标键已存在，则直接返回。
    /// - 叶子节点的插入不需要进行回溯检查。
    /// - 检查树的层高是否有提升。
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func _insert(key: Key, value: Value) -> Bool {
        guard let root = root else {
            numberOfElements = 1
            self.root = createLeafNode(key: key, value: value)
            return true
        }

        var postion = 0
        var parent: Node? = nil
        var current: Node = root
        /// ceil(order / 2) 是 min 和 max 子节点数，分割点需要 - 1
        let splitIndex = (order + 1) / 2 - 1
        while true {
            let insertPos = findLowerBoundIndex(node: current, key: key)

            /// 如果对应的 key 存在于树中，则直接返回
            if insertPos < current.keys.count, current.keys[insertPos] == key {
                return false
            }

            /// 当前节点的元素是否已满
            if current.keys.count == order - 1 {
                /// 需要提升的 key
                let promotedKey = current.keyValuePair(at: splitIndex)
                /// 复制到右边
                let rightChild: Node

                /// 叶子节点没有子节点
                if current.isLeaf == false {
                    rightChild = createInternalNode(
                        keys: current.keys[(splitIndex + 1)...],
                        values: current.values[(splitIndex + 1)...],
                        children: current.children![(splitIndex + 1)...]
                    )
                    /// children 不会存在提升，所以无需删除 midIndex 对应的子节点
                    current.children!.removeSubrange((splitIndex + 1)...)
                }
                else {
                    rightChild = createLeafNode(keys: current.keys[(splitIndex + 1)...], values: current.values[(splitIndex + 1)...])
                }

                /// 删除被提升的和复制到 right 节点的 elements
                current.keys.removeSubrange(splitIndex...)
                current.values.removeSubrange(splitIndex...)

                /// 如果存在父节点
                /// 这里的父节点插入必定不会导致分裂了
                if let parent {
                    /// 修改 left 指针
                    parent.children![postion] = current
                    /// 插入新的 element
                    parent.keys.insert(promotedKey.0, at: postion)
                    parent.values.insert(promotedKey.1, at: postion)
                    /// 修改 right 指针
                    parent.children!.insert(rightChild, at: postion + 1)
                }
                else {
                    self.root = createInternalNode(element: promotedKey, left: current, right: rightChild)
                }

                /// 修正子节点执行
                if insertPos > splitIndex {
                    postion += 1
                    current = rightChild
                    continue
                }
            }

            /// 这里插入时不会触发分裂的，因为上面已经检查并分裂过了。
            if current.isLeaf {
                numberOfElements += 1
                current.keys.insert(key, at: insertPos)
                current.values.insert(value, at: insertPos)
                return true
            }

            parent = current
            postion = insertPos
            current = current.children![insertPos]
        }
    }

    /// 更新已存在的键的值
    ///
    /// - 如果键不存在，则不进行更新并返回 nil
    /// - 如果更新成功，则返回旧值
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func update(key: Key, value: Value) -> Value? {
        guard let root else { return nil }

        var current = root
        while true {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            if lowerBoundIndex < current.keys.count, current.keys[lowerBoundIndex] == key {
                let oldValue = current.values[lowerBoundIndex]
                current.values[lowerBoundIndex] = value
                return oldValue
            }
            if current.isLeaf {
                return nil
            }
            current = current.children![lowerBoundIndex]
        }
    }

    /// 插入或更新 - 插入时基于 Bottom-up 的实现方式
    ///
    /// - 如果键存在，则更新其值并返回旧值
    /// - 如果键不存在，则插入该键值对并返回 nil
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func upsert(key: Key, value: Value) -> Value? {
        guard let root = root else {
            numberOfElements = 1
            self.root = createLeafNode(key: key, value: value)
            return nil
        }

        /// 定位到将要插入的节点位置
        var insertPos = 0
        var current: Node = root
        /// 记录访问路径用以回溯
        var ancestorPath: [(Node, Int)] = []
        ancestorPath.reserveCapacity(estimatedTreeHeight)
        while true {
            insertPos = findLowerBoundIndex(node: current, key: key)
            ancestorPath.append((current, insertPos))
            /// 如果对应的 key 存在于树中，则直接返回
            if insertPos < current.keys.count, current.keys[insertPos] == key {
                let oldValue = current.values[insertPos]
                current.values[insertPos] = value
                return oldValue
            }
            /// 不能在 while 写这个，也需要再叶子节点执行内部 while 逻辑
            if current.isLeaf {
                break
            }
            current = current.children![insertPos]
        }
        /// 插入
        numberOfElements += 1
        current.keys.insert(key, at: insertPos)
        current.values.insert(value, at: insertPos)

        /// Bottom-Up 的实现是在插入后超出限制才分裂的。
        if current.keys.count < order {
            return nil
        }

        /// 元素分裂点
        /// ceil(order / 2) 是 min 和 max 子节点数，分割点需要 - 1
        let splitIndex = (order + 1) / 2 - 1
        /// 指针修改
        var leftChild = current
        /// 将要被提升的 element
        var promotedKey = current.keyValuePair(at: splitIndex)
        /// 复制 elements 到新的右兄弟节点。
        var rightChild = createLeafNode(keys: current.keys[(splitIndex + 1)...], values: current.values[(splitIndex + 1)...])
        /// 删除被提升和已复杂到右兄弟节点的 elements
        current.keys.removeSubrange(splitIndex...)
        current.values.removeSubrange(splitIndex...)

        /// 删除最后一个叶子节点
        ancestorPath.removeLast()

        /// 向上回溯操作
        /// 返回的是 ReversedCollection，这是一个轻量级的封装
        ancestorPath.withUnsafeBufferPointer { buffer in
            var bufferIndex = buffer.count
            while bufferIndex > 0 {
                bufferIndex -= 1
                let (parent, index) = buffer[bufferIndex]

                /// 修改 left 指针
                parent.children![index] = leftChild
                /// 插入新的 element
                parent.keys.insert(promotedKey.0, at: index)
                parent.values.insert(promotedKey.1, at: index)
                /// 修改 right 指针
                parent.children!.insert(rightChild, at: index + 1)
                /// 如果中间节点插入后未满，就直接 break
                if parent.keys.count < order {
                    break
                }
                /// 指针修改
                leftChild = parent
                /// 需要提升的 key
                promotedKey = parent.keyValuePair(at: splitIndex)
                /// 复制到右边
                rightChild = createInternalNode(
                    keys: parent.keys[(splitIndex + 1)...],
                    values: parent.values[(splitIndex + 1)...],
                    children: parent.children![(splitIndex + 1)...]
                )
                /// 删除被提升的和复制到 right 节点的 elements
                parent.keys.removeSubrange(splitIndex...)
                parent.values.removeSubrange(splitIndex...)
                /// children 不会存在提升，所以无需删除 midIndex 对应的子节点
                parent.children!.removeSubrange((splitIndex + 1)...)
            }
        }
        // 如果遍历完所有祖先节点后，最后的节点仍然需要分裂
        // 说明需要创建新的根节点
        if leftChild === root {
            self.root = createInternalNode(element: promotedKey, left: leftChild, right: rightChild)
        }
        return nil
    }

    /// 删除指定键对应的元素 - 基于 Bottom-Up 的实现方式
    ///
    /// - 如果键不存在，则返回 nil
    /// - 如果删除成功，则返回被删除的值
    ///
    /// 逻辑：
    /// - 删除总是在叶子节点出现。
    /// - 如果目标键在内部节点，需要查找其前驱或后继交换并沿着路径下降到叶子节点，并继续删除。
    /// - 交互前驱与后继时，优先使用前驱。
    /// - 借用与合并时，优先对左兄弟节点进行借用或合并。
    /// - 在叶子节点删除后，回溯时检查是否需要借用或合并。
    /// - 删除可能会降低树的高度。
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func _remove(key: Key) -> Value? {
        guard let root = root else { return nil }

        /// ceil(order / 2) 是 min 和 max 子节点数，键的数量还需要 - 1
        let minKeys = (order + 1) / 2 - 1

        var current: Node = root
        var indexOfLeafNodeKeys = 0
        /// 记录访问路径用以回溯
        var ancestorPath: [(Node, Int)] = []
        ancestorPath.reserveCapacity(estimatedTreeHeight)

        /// 向下直到叶子节点
        while true {
            let position = findLowerBoundIndex(node: current, key: key)
            /// 如果对应的 key 位于内部节点中
            if current.isLeaf == false, position < current.keys.count, current.keys[position] == key {
                let child: Node
                let index: Int

                /// 根据左右子节点那边节点多来选择前驱还是后继
                /// 如果后继所在的节点，元素更多则使用后继否则使用前驱
                /// 需要改为顺着前驱或后继的路径下降了，也就是说进入这个分支结束后会直接退出循环。
                if current.children![position].keys.count < current.children![position + 1].keys.count {
                    /// 记录路径
                    ancestorPath.append((current, position + 1))

                    var successor: Node = current.children![position + 1]
                    while let next = successor.children?.first ?? nil {
                        // 最后一个叶子节点不记录
                        // 如果 successor 已经是叶子节点了，那么此处循环就不会进入，那么一样能达到要求
                        ancestorPath.append((successor, 0))
                        successor = next
                    }
                    index = 0
                    child = successor
                }
                else {
                    /// 记录路径
                    ancestorPath.append((current, position))

                    var predecessor: Node = current.children![position]
                    while let next = predecessor.children?.last ?? nil {
                        // 最后一个叶子节点不记录
                        ancestorPath.append((predecessor, predecessor.keys.count))
                        predecessor = next
                    }
                    index = predecessor.keys.endIndex - 1
                    child = predecessor
                }

                swap(&current.keys[position], &child.keys[index])
                swap(&current.values[position], &child.values[index])

                /// 此时 child 就是叶子节点了。
                current = child
                indexOfLeafNodeKeys = index
                break
            }

            if current.isLeaf {
                // 如果叶子节点还是不存在目标节点，则直接返回
                if position >= current.keys.count || current.keys[position] != key {
                    return nil
                }
                indexOfLeafNodeKeys = position
                /// 出循环处理删除和回溯
                break
            }

            /// 正常的查询路径
            ancestorPath.append((current, position))
            current = current.children![position]
        }

        // 删除
        numberOfElements -= 1
        current.keys.remove(at: indexOfLeafNodeKeys)
        let removed = current.values.remove(at: indexOfLeafNodeKeys)

        // 如果是叶子节点，并且删除后如果不需要借用或合并，直接返回
        if current.keys.count >= minKeys {
            return removed
        }

        /// 向上回溯操作
        for (parent, index) in ancestorPath.reversed() {
            current = parent.children![index]
            /// 借用 - 借用不会影响树的节点变动只是旋转。

            /// 如果左兄弟节点存在多余的值
            /// 右旋：左边节点的最大值移动到父节点，父节点对应键移下来
            if index > 0, parent.children![index - 1].keys.count > minKeys {
                current.keys.insert(parent.keys[index - 1], at: 0)
                parent.keys[index - 1] = parent.children![index - 1].keys.removeLast()

                current.values.insert(parent.values[index - 1], at: 0)
                parent.values[index - 1] = parent.children![index - 1].values.removeLast()

                if current.isLeaf == false {
                    current.children!.insert(parent.children![index - 1].children!.removeLast(), at: 0)
                }
                break
            }

            /// 如果右边兄弟存在多余的值
            /// 左旋：右边节点的最小值移动到父节点，父节点对应键移下来
            if index != parent.keys.count, parent.children![index + 1].keys.count > minKeys {
                current.keys.append(parent.keys[index])
                parent.keys[index] = parent.children![index + 1].keys.removeFirst()

                current.values.append(parent.values[index])
                parent.values[index] = parent.children![index + 1].values.removeFirst()

                if current.isLeaf == false {
                    current.children!.append(parent.children![index + 1].children!.removeFirst())
                }
                break
            }

            // 合并 - 合并会触发树的节点结构变化，需要递归回溯

            /// 合并其实就是右边节点向左边节点合并，第一步是确定缺少元素的节点是左节点还是右节点
            /// 非叶子节点必定存在一个兄弟节点，所以此处只需判断一边就行，无需判断 childIndex + 1 是否存在对应节点
            let (leftNode, rightNode, elementIndex, childrenIndex) = index > 0
                ? (parent.children![index - 1], current, index - 1, index)
                : (current, parent.children![index + 1], index, index + 1)

            /// 将分隔值复制到左边的节点
            leftNode.keys.append(parent.keys[elementIndex])
            leftNode.values.append(parent.values[elementIndex])
            /// 将右边节点中所有的元素移动到左边节点
            leftNode.keys.append(contentsOf: rightNode.keys)
            leftNode.values.append(contentsOf: rightNode.values)
            /// 合并子节点，叶子节点的 children 是空的，此时会是两个数组合并，没必要添加一个 if 判断。
            if leftNode.isLeaf == false {
                leftNode.children!.append(contentsOf: rightNode.children!)
            }
            /// 将空的右子树移除
            parent.children!.remove(at: childrenIndex)
            /// 将父节点中的分隔值删除
            parent.keys.remove(at: elementIndex)
            parent.values.remove(at: elementIndex)
            /// 如果父节点删除后结构没有被破坏，则直接返回
            if parent.keys.count >= minKeys {
                break
            }
        }

        /// 如果根节点没有元素了，那么此时也只会存在一个子节点，层级需要降低
        if self.root!.keys.count == 0 {
            /// 需要支持删光的情况
            self.root = self.root!.children?.first ?? nil
        }

        return removed
    }

    /// 删除指定键对应的元素 - 基于 Top-Down 的实现方式
    ///
    /// - 如果键不存在，则返回 nil
    /// - 如果删除成功，则返回被删除的值
    ///
    /// 逻辑：
    /// - 删除总是在叶子节点出现
    /// - 如果目标键在内部节点，需要查找其前驱或后继交换并沿着路径下降到叶子节点，并继续删除。
    /// - 在进入下一层时，先检查下一层是否可能因为删除导致借用与合并，如果可能，就提前处理。
    /// - 交互前驱与后继时，优先使用前驱。
    /// - 借用与合并时，优先对左兄弟节点进行借用或合并。
    /// - 因为下降时的预处理，叶子节点的删除是安全的，必定不会触发借用与合并。
    /// - 删除可能会降低树的高度。
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func remove(key: Key) -> Value? {
        guard let root = root else { return nil }

        @inline(__always)
        func leftBorrow(parent: Node, index: Int, leftBortherIndex: Int) -> (Node, Int) {
            let child = parent.children![leftBortherIndex + 1]
            let leftBorther = parent.children![leftBortherIndex]
            let keyValueNewIndex = child.keys.endIndex

            /// 目标节点插入父节点的分隔值
            child.keys.insert(parent.keys[index], at: 0)
            /// 左兄弟删除其最大值，并且将其设置为目标节点的父节点分隔值
            parent.keys[index] = leftBorther.keys.removeLast()

            /// 目标节点插入父节点的分隔值
            child.values.insert(parent.values[index], at: 0)
            /// 左兄弟删除其最大值，并且将其设置为目标节点的父节点分隔值
            parent.values[index] = leftBorther.values.removeLast()

            if child.isLeaf == false {
                /// 添加借过来的子节点
                child.children!.insert(leftBorther.children!.removeLast(), at: 0)
            }
            return (child, keyValueNewIndex)
        }

        @inline(__always)
        func leftMerge(parent: Node, index: Int, leftBortherIndex: Int) -> (Node, Int) {
            let child = parent.children![leftBortherIndex + 1]
            let leftBorther = parent.children![leftBortherIndex]
            let keyValueNewIndex = leftBorther.keys.endIndex

            /// 将分隔值复制到左边的节点
            leftBorther.keys.append(parent.keys[index])
            leftBorther.values.append(parent.values[index])

            /// 将右边节点中所有的元素移动到左边节点
            leftBorther.keys.append(contentsOf: child.keys)
            leftBorther.values.append(contentsOf: child.values)

            /// 合并子节点，叶子节点的 children 是空的
            if leftBorther.isLeaf == false {
                leftBorther.children!.append(contentsOf: child.children!)
            }

            /// 将父节点中的分隔值删除
            parent.keys.remove(at: index)
            parent.values.remove(at: index)
            /// 将空的右子树移除
            parent.children!.remove(at: leftBortherIndex + 1)

            return (leftBorther, keyValueNewIndex)
        }

        @inline(__always)
        func rightMerge(parent: Node, index: Int, rightBortherIndex: Int) -> (Node, Int) {
            let child = parent.children![rightBortherIndex - 1]
            let rightBorther = parent.children![rightBortherIndex]

            let keyValueNewIndex = child.keys.endIndex

            /// 将分隔值复制到左边的节点
            child.keys.append(parent.keys[index])
            child.values.append(parent.values[index])
            /// 将右边节点中所有的元素移动到左边节点
            child.keys.append(contentsOf: rightBorther.keys)
            child.values.append(contentsOf: rightBorther.values)

            /// 合并子节点
            if child.isLeaf == false {
                child.children!.append(contentsOf: rightBorther.children!)
            }

            /// 将父节点中的分隔值删除
            parent.keys.remove(at: index)
            parent.values.remove(at: index)
            /// 将空的右子树移除
            parent.children!.remove(at: rightBortherIndex)

            return (child, keyValueNewIndex)
        }

        @inline(__always)
        func rightBorrow(parent: Node, index: Int, rightBortherIndex: Int) -> (Node, Int) {
            let child = parent.children![rightBortherIndex - 1]
            let rightBorther = parent.children![rightBortherIndex]

            let keyValueNewIndex = child.keys.endIndex

            /// 目标节点插入父节点的分隔值
            child.keys.append(parent.keys[index])
            /// 右兄弟删除其最小值，并且将其设置为目标节点的父节点分隔值
            parent.keys[index] = rightBorther.keys.removeFirst()

            /// 目标节点插入父节点的分隔值
            child.values.append(parent.values[index])
            /// 右兄弟删除其最小值，并且将其设置为目标节点的父节点分隔值
            parent.values[index] = rightBorther.values.removeFirst()

            if child.isLeaf == false {
                /// 添加借过来的子节点
                child.children!.append(rightBorther.children!.removeFirst())
            }

            return (child, keyValueNewIndex)
        }

        /// ceil(order / 2) 是 min 和 max 子节点数，键数还需要 - 1
        let minKeys = (order + 1) / 2 - 1

        var current: Node = root
        var nextIndex: Int = findLowerBoundIndex(node: current, key: key)

        /// 向下直到叶子节点
        /// 如果 root 节点已经是叶子节点就无需进入循环。
        while current.isLeaf == false {
            /// Top-Down 会在下降过程中检查下个路径是否需要预调整。
            /// 下降过程中，必定只会选择走前驱所在节点下降，或者走后继节点下降，默认的 lowerBound 就是 floor 所在节点。
            /// 三种情况：（此处说的前驱和后继是相对与 lowerBound 的）
            /// 1. lowerBound 小于 keys.count 此时它可选择前驱节点或者后继节点
            ///   1. 如果 keys[lowerBound] == key , isLeaf == false 此时需要根据前驱后继节点元素哪个更多来选择
            ///   2. 选择前驱 children[lowerBound] 此时后面的路径已经明确，沿着 .last 访问。
            ///   3. 选择后继 children[lowerBound + 1] 此时路径也已明确，沿着 .first 访问。
            ///   4. 在访问过程中预调整和交换位置，注意：选择后继节点时如果触发合并是无需 交换的，目标键会被旋转下来。
            /// 2. lowerBound 等于 keys.count 此时它只能选择前驱节点下降。
            ///   1. 此时下降过程中必定不会触发交换，但是需要预先调整。

            if nextIndex == current.keys.count || current.keys[nextIndex] != key {
                /// 必定不会触发交换，只需要预调整，这里的预调整，可以分别检查左兄弟与右兄弟了
                if current.children![nextIndex].keys.count < minKeys + 1 {
                    let position = nextIndex

                    /// 如果左兄弟节点存在多余的值
                    /// 右旋：左边节点的最大值移动到父节点，父节点对应键移下来
                    if position > 0, current.children![position - 1].keys.count > minKeys {
                        _ = leftBorrow(parent: current, index: position - 1, leftBortherIndex: position - 1)
                        current = current.children![nextIndex]
                        nextIndex = findLowerBoundIndex(node: current, key: key)
                        continue
                    }

                    /// 如果右边兄弟存在多余的值
                    /// 左旋：右边节点的最小值移动到父节点，父节点对应键移下来
                    if position != current.keys.count, current.children![position + 1].keys.count > minKeys {
                        _ = rightBorrow(parent: current, index: position, rightBortherIndex: position + 1)
                        current = current.children![nextIndex]
                        nextIndex = findLowerBoundIndex(node: current, key: key)
                        continue
                    }

                    // 合并 - 合并会触发树的节点结构变化

                    /// 合并其实就是右边节点向左边节点合并，第一步是确定缺少元素的节点是左节点还是右节点
                    /// 非叶子节点必定存在一个兄弟节点，所以此处只需判断一边就行，无需判断 position + 1 是否存在对应节点
                    let (leftNode, rightNode, elementIndex, childrenIndex) = position > 0
                        ? (current.children![position - 1], current.children![position], position - 1, position)
                        : (current.children![position], current.children![position + 1], position, position + 1)

                    /// 将分隔值复制到左边的节点
                    leftNode.keys.append(current.keys[elementIndex])
                    leftNode.values.append(current.values[elementIndex])

                    /// 将右边节点中所有的元素移动到左边节点
                    leftNode.keys.append(contentsOf: rightNode.keys)
                    leftNode.values.append(contentsOf: rightNode.values)

                    /// 合并子节点，叶子节点的 children 是空的
                    if leftNode.isLeaf == false {
                        leftNode.children!.append(contentsOf: rightNode.children!)
                    }

                    /// 将父节点中的分隔值删除
                    current.keys.remove(at: elementIndex)
                    current.values.remove(at: elementIndex)

                    /// 将空的右子树移除
                    current.children!.remove(at: childrenIndex)

                    current = leftNode
                    nextIndex = findLowerBoundIndex(node: current, key: key)
                    continue
                }

                /// 进入下一层
                current = current.children![nextIndex]
                nextIndex = findLowerBoundIndex(node: current, key: key)
                continue
            }

            /// 此时 current.keys[nextIndex] == key
            ///
            /// 根据左右子节点那边节点多来选择前驱还是后继，如果后继所在的节点，元素更多则使用后继否则使用前驱。
            /// 前驱所在节点：current.children![nextIndex]
            /// 后继所在节点：current.children![nextIndex + 1]
            ///
            /// 只要是前驱所在节点与后继所在节点发生借用或合并，那么都将目标键旋转到下一层。
            if current.children![nextIndex + 1].keys.count > current.children![nextIndex].keys.count {
                let parent = current
                var successor = current.children![nextIndex + 1]

                /// 这里的借用与合并都只发生在 successor 与其左兄弟节点上
                /// 这里的借用与合并都会导致将目标键旋转下来，所以需要回到主循环, 并且将可能重新回到这个分支。
                if successor.keys.count < minKeys + 1 {
                    /// 左合并
                    if current.children![nextIndex].keys.count <= minKeys {
                        (current, nextIndex) = leftMerge(parent: parent, index: nextIndex, leftBortherIndex: nextIndex)
                        continue
                    }

                    (current, nextIndex) = leftBorrow(parent: parent, index: nextIndex, leftBortherIndex: nextIndex)
                    continue
                }

                /// 如果无需预调整那么就需要下降到叶子节点，并交换 kv

                /// 这里会一直预调整+沿着后继下降，直到叶子节点，最后处理交换。
                /// 为啥这里无需退到上层循环中呢，因为这里的旋转不会影响到目标键
                while let nextNode = successor.children?.first ?? nil {
                    /// 检查是否需要进行预调整
                    if nextNode.keys.count < minKeys + 1 {
                        /// 右借用
                        if successor.children![1].keys.count > minKeys {
                            _ = rightBorrow(parent: successor, index: 0, rightBortherIndex: 1)
                        }
                        /// 右合并
                        else {
                            _ = rightMerge(parent: successor, index: 0, rightBortherIndex: 1)
                        }
                    }
                    successor = nextNode
                }

                /// 这里的 successor 已经是叶子节点了。
                swap(&current.keys[nextIndex], &successor.keys[0])
                swap(&current.values[nextIndex], &successor.values[0])

                nextIndex = 0
                current = successor
                break
            }

            let parent = current
            var predecessor = current.children![nextIndex]

            /// 这里的借用与合并都只发生在 predecessor 与其右兄弟节点上
            /// 这里的借用与合并都会导致将目标键旋转下来，所以需要回到主循环, 并且将可能重新回到这个分支。
            if predecessor.keys.count < minKeys + 1 {
                /// 右合并
                if current.children![nextIndex + 1].keys.count <= minKeys {
                    (current, nextIndex) = rightMerge(parent: parent, index: nextIndex, rightBortherIndex: nextIndex + 1)
                    continue
                }
                /// 右借用
                (current, nextIndex) = rightBorrow(parent: parent, index: nextIndex, rightBortherIndex: nextIndex + 1)
                continue
            }

            /// 无需预调整就需要下降到叶子节点，并交换 kv
            /// 为啥这里无需退到上层循环中呢，因为这里的旋转不会影响到目标键
            while let nextNode = predecessor.children?.last ?? nil {
                /// 检查是否需要进行预调整
                if nextNode.keys.count < minKeys + 1 {
                    let index = predecessor.keys.endIndex - 1
                    /// 左借用
                    if predecessor.children![index].keys.count > minKeys {
                        _ = leftBorrow(parent: predecessor, index: index, leftBortherIndex: index)
                    }
                    /// 左合并
                    else {
                        _ = leftMerge(parent: predecessor, index: index, leftBortherIndex: index)
                    }
                }
                /// 向左合并 last 节点会被删除的，这里需要重新获取一下
                predecessor = predecessor.children![predecessor.keys.endIndex]
            }

            /// 这里的 predecessor 已经是叶子节点了。
            swap(&current.keys[nextIndex], &predecessor.keys[predecessor.keys.endIndex - 1])
            swap(&current.values[nextIndex], &predecessor.values[predecessor.keys.endIndex - 1])

            current = predecessor
            nextIndex = predecessor.keys.endIndex - 1
            break
        }

        /// 检查叶子节点是否存在目标键
        if nextIndex >= current.keys.count || current.keys[nextIndex] != key {
            /// Top-Down的实现在循环内就已经调整完了，叶子节点的删除不会影响层级，所以在这里需要检查
            /// 检查树的高度是否有降低
            if self.root!.keys.count == 0 {
                self.root = self.root!.children?.first ?? nil
            }
            return nil
        }

        /// 安全的删除
        numberOfElements -= 1
        current.keys.remove(at: nextIndex)
        let removed = current.values.remove(at: nextIndex)
        
        /// 如果根节点就是叶子节点，那么此处可能会删除完
        if self.root!.keys.count == 0 {
            self.root = self.root!.children?.first ?? nil
        }

        return removed
    }

    /// 清空树中的所有元素
    ///
    /// 时间复杂度：O(1)
    func clear() {
        root = nil
        numberOfElements = 0
    }

    /// 下标访问
    ///
    /// - 读取：返回给定键对应的值（若不存在则为 nil）等同于 search(key:)
    /// - 写入：
    ///   - 若 value != nil 则等同于 upsert(key:value:)
    ///   - 若 value == nil 则等同于 remove(key:)
    ///
    /// 时间复杂度：O(log n)
    subscript(key: Key) -> Value? {
        get {
            search(key: key)
        }
        set {
            if let value = newValue {
                upsert(key: key, value: value)
            }
            else {
                remove(key: key)
            }
        }
    }
}

// MARK: - 查询操作

public extension BTree {
    /// 检查集合是否包含给定键
    ///
    /// 时间复杂度：O(log n)
    func contains(key: Key) -> Bool {
        search(key: key) != nil
    }

    /// 返回小于等于指定键的最大元素
    ///
    /// - Returns: 若存在，则返回满足条件的最大元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func floor(key: Key) -> Element? {
        var current: Node? = root
        var lastLeftParent: Element?
        while let node = current {
            let lowerBoundIndex = findLowerBoundIndex(node: node, key: key)
            if lowerBoundIndex < node.keys.count, node.keys[lowerBoundIndex] == key {
                return node.keyValuePair(at: lowerBoundIndex)
            }

            if node.isLeaf {
                if lowerBoundIndex > 0 {
                    return node.keyValuePair(at: lowerBoundIndex - 1)
                }
                break
            }

            if lowerBoundIndex > 0 {
                /// 记录最后一个左父节点
                lastLeftParent = node.keyValuePair(at: lowerBoundIndex - 1)
            }
            current = node.children![lowerBoundIndex]
        }
        return lastLeftParent
    }

    /// 返回大于等于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func ceiling(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        var lastRightParent: Element?
        while current.isLeaf == false {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            if lowerBoundIndex < current.keys.count, current.keys[lowerBoundIndex] == key {
                return current.keyValuePair(at: lowerBoundIndex)
            }

            if lowerBoundIndex < current.keys.count {
                /// 记录最后一个右父节点
                lastRightParent = current.keyValuePair(at: lowerBoundIndex)
            }
            current = current.children![lowerBoundIndex]
        }
        let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)

        if lowerBoundIndex < current.keys.count {
            return current.keyValuePair(at: lowerBoundIndex)
        }
        return lastRightParent
    }

    /// 返回小于指定键的最大元素
    ///
    /// - Returns: 若存在，则返回满足条件的最大元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func predecessor(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        var lastLeftParent: Element?
        while current.isLeaf == false {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            if lowerBoundIndex > 0 {
                /// 记录最后一个左父节点
                lastLeftParent = current.keyValuePair(at: lowerBoundIndex - 1)
            }

            current = current.children![lowerBoundIndex]
        }

        let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
        return lowerBoundIndex > 0 ? current.keyValuePair(at: lowerBoundIndex - 1) : lastLeftParent
    }

    /// 返回大于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func successor(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        var lastRightParent: Element?
        while current.isLeaf == false {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            if lowerBoundIndex < current.keys.count {
                if current.keys[lowerBoundIndex] == key {
                    // 如果找到相等的键，后继一定在右子树的最左路径上
                    current = current.children![lowerBoundIndex + 1]
                    // 找右子树最小值
                    while current.isLeaf == false {
                        current = current.children!.first!
                    }
                    return current.keyValuePair(at: 0)
                }
                lastRightParent = current.keyValuePair(at: lowerBoundIndex)
            }

            current = current.children![lowerBoundIndex]
        }
        /// 在叶子节点进行查找
        let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
        if lowerBoundIndex >= current.keys.count {
            return lastRightParent
        }
        // 如果当前位置的键等于目标键，需要使用之前记录的父节点
        if current.keys[lowerBoundIndex] == key {
            if lowerBoundIndex + 1 < current.keys.count {
                return current.keyValuePair(at: lowerBoundIndex + 1)
            }
            return lastRightParent
        }
        // 如果当前位置的键大于目标键，直接返回
        return current.keyValuePair(at: lowerBoundIndex)
    }

    /// 返回指定范围内的所有元素
    ///
    /// - Returns: 位于指定范围内的元素数组
    ///
    /// 时间复杂度：O(log n + k)
    func range(in range: ClosedRange<Key>) -> [Element] {
        var result: [Element] = []
        guard root != nil else { return result }

        var current = root
        var stack: [(node: Node, index: Int)] = []
        while let node = current {
            let lowerIndex = findLowerBoundIndex(node: node, key: range.lowerBound)
            stack.append((node, lowerIndex))
            if lowerIndex < node.keys.count, node.keys[lowerIndex] == range.lowerBound {
                break
            }
            // 此时 lowerBound 必定不存在于 Tree 中，需要尝试从其后继开始遍历。
            if node.isLeaf {
                /// 其后继一般就在其父级
                if lowerIndex == node.keys.count {
                    /// 删除叶子节点路径
                    stack.removeLast()
                    /// 检查是否存在后继
                    if let last = stack.last, last.1 == last.0.keys.count {
                        return []
                    }
                }
                break
            }
            else {
                current = node.children![lowerIndex]
            }
        }

        while stack.isEmpty == false {
            guard let (node, index) = stack.last else {
                break
            }

            /// 下降过程中如果节点中所有值都小于 lowerBound 那么此处 index 将 == keys.count
            /// 此时应该尝试去其右兄弟节点查找
            if index == node.keys.count {
                stack.removeLast()
                continue
            }

            if node.keys[index] > range.upperBound {
                break
            }

            result.append(node.keyValuePair(at: index))

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }
            /// 如果有右子树，则继续下降
            if node.isLeaf == false, index + 1 <= node.keys.count {
                current = node.children![index + 1]
                while let node = current {
                    stack.append((node, 0))
                    current = node.children?.first
                }
            }
        }
        return result
    }
}

// MARK: - 遍历操作

public extension BTree {
    /// 以升序遍历所有元素
    /// forEach 会被格式化程序格式成 for in ，而本协议不要求实现者继承 Sequence 协议，所以此处不能使用 forEach 这个名字。
    ///
    /// 时间复杂度：O(log n + n)
    func traverse(_ body: (Element) throws -> Void) rethrows {
        var current = root
        var stack: [(node: Node, index: Int)] = []
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            guard let (node, index) = stack.last else {
                break
            }

            try body(node.keyValuePair(at: index))

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
        }
    }

    /// 以降序遍历所有元素
    ///
    /// 时间复杂度：O(log n + n)
    func reversedTraverse(_ body: (Element) throws -> Void) rethrows {
        var current = root
        var stack: [(node: Node, index: Int)] = []
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, node.keys.count - 1))
                current = node.children?.last
            }

            guard let (node, index) = stack.last else {
                break
            }

            try body(node.keyValuePair(at: index))

            /// 更新 index
            stack[stack.count - 1].index -= 1

            if index - 1 == -1 {
                stack.removeLast()
            }

            /// 如果有左子树，则继续下降
            if index >= 0, node.isLeaf == false {
                current = node.children![index]
            }
        }
    }

    /// 对集合中的每个元素应用转换函数，返回转换后的数组
    ///
    /// 时间复杂度：O(log n + n)
    func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        var current = root
        var result: [T] = []
        var stack: [(node: Node, index: Int)] = []
        result.reserveCapacity(numberOfElements)
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            guard let (node, index) = stack.last else {
                break
            }

            try result.append(transform(node.keyValuePair(at: index)))

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
        }
        return result
    }

    /// 对集合中的每个元素应用转换函数，返回转换后的数组，如果转换函数返回 nil，则不包含该元素
    ///
    /// 时间复杂度：O(log n + n)
    func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T] {
        var current = root
        var result: [T] = []
        var stack: [(node: Node, index: Int)] = []
        result.reserveCapacity(numberOfElements)
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            guard let (node, index) = stack.last else {
                break
            }

            if let transformed = try transform(node.keyValuePair(at: index)) {
                result.append(transformed)
            }

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
        }
        return result
    }

    /// 对所有元素进行归约计算，并返回累加值
    ///
    /// 时间复杂度：O(log n + n)
    func reduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) throws -> T) rethrows -> T {
        var current = root
        var result: T = initialResult
        var stack: [(node: Node, index: Int)] = []
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            guard let (node, index) = stack.last else {
                break
            }

            result = try nextPartialResult(result, node.keyValuePair(at: index))

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
        }
        return result
    }

    /// 对集合中的元素执行归约操作，并通过 `inout` 参数直接修改初始累加值。
    ///
    /// 时间复杂度：O(log n + n)
    func reduce<T>(into initialResult: T, _ updateAccumulatingResult: (inout T, Element) throws -> Void) rethrows -> T {
        var current = root
        var result: T = initialResult
        var stack: [(node: Node, index: Int)] = []
        stack.reserveCapacity(estimatedTreeHeight)
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            guard let (node, index) = stack.last else {
                break
            }

            try updateAccumulatingResult(&result, node.keyValuePair(at: index))

            /// 更新 index
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension BTree: CustomStringConvertible {
    /// 输出 BTree 的内部结构字符串形式.
    ///
    /// 时间复杂度：O(log n)
    public var description: String {
        /// 要不要加上 叶子节点数和内部节点数呢？但是需要维护这两个属性呢，还需要写测试
        """
        BTree:
        - Height: \(height)
        - Number of elements: \(numberOfElements)
        - Order: \(order) (maximum number of children per node)
        """
    }
}

// MARK: - OrderedCollection

extension BTree: OrderedCollection {}

// MARK: - Sequence+IteratorProtocol

public struct BTreeSequence<Key: Comparable, Value>: Sequence {
    let tree: BTree<Key, Value>

    init(_ tree: BTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> BTreeIterator<Key, Value> {
        BTreeIterator(tree)
    }
}

public struct BTreeReversedSequence<Key: Comparable, Value>: Sequence {
    let tree: BTree<Key, Value>

    init(_ tree: BTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> BTreeReversedIterator<Key, Value> {
        BTreeReversedIterator(tree)
    }
}

public struct BTreeIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = BTree<Key, Value>.Element
    typealias Node = BTree<Key, Value>.Node

    private var stack: [(node: Node, index: Int)]

    private var current: Node? = nil

    init(_ tree: BTree<Key, Value>) {
        self.stack = []
        self.current = tree.root
    }

    public mutating func next() -> Element? {
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, 0))
                current = node.children?.first
            }

            let (node, index) = stack.last!

            // 获取当前元素
            let element = node.keyValuePair(at: index)

            // 更新索引
            stack[stack.count - 1].index += 1

            if index + 1 == node.keys.count {
                stack.removeLast()
            }

            /// 如果有右子树，则继续下降
            if index + 1 <= node.keys.count, node.isLeaf == false {
                current = node.children![index + 1]
            }
            return element
        }

        return nil
    }
}

public struct BTreeReversedIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = BTree<Key, Value>.Element
    typealias Node = BTree<Key, Value>.Node

    private var current: Node?
    private var stack: [(node: Node, index: Int)]

    init(_ tree: BTree<Key, Value>) {
        self.stack = []
        self.current = tree.root
    }

    public mutating func next() -> Element? {
        while current != nil || stack.isEmpty == false {
            while let node = current {
                stack.append((node, node.keys.count - 1))
                current = node.children?.last
            }

            guard let (node, index) = stack.last else {
                break
            }

            let element = node.keyValuePair(at: index)

            /// 更新 index
            stack[stack.count - 1].index -= 1

            if index - 1 == -1 {
                stack.removeLast()
            }

            /// 如果有左子树，则继续下降
            if index >= 0, node.isLeaf == false {
                current = node.children![index]
            }
            return element
        }
        return nil
    }
}

// MARK: - 调试方法-仅在 DEBUG 模式下有效

#if DEBUG
    import TreePrinter

    extension BTreeNode: PrintableMultiwayTreeProtocol {
        var subnodes: [BTreeNode<Key, Value>] {
            children ?? []
        }

        var displayName: String {
            keys.map { "\($0)" }.joined(separator: " ")
        }
    }

    extension BTree: CustomDebugStringConvertible {
        public var debugDescription: String {
            guard let root else { return "" }
            return MultiwayTreePrinter(root).print()
        }
    }
#endif
