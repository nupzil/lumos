//
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

/// BPlusTree
///
/// B+ 树是一种自平衡的树状数据结构，用于存储和检索有序数据。它具有以下特点：
///  - 自平衡：B+ 树的插入和删除操作会自动调整树的结构，以保持树的平衡。
///  - 有序：B+ 树中的数据是有序的，可以快速进行范围查询。
///  - 多路搜索树：B+ 树的每个节点可以有多个子节点，这使得它在存储大量数据时具有较高的效率。
///  - 有序链表：B+ 树的叶子节点通过双向链表连接，这使得它在范围查询时具有较高的效率。
///
/// 实现定义：
/// 在 B+ 树中，阶通常用字母 m 表示，它定义了一个节点可以拥有的子节点的最大数量。具体来说，以下是与 B+ 树阶数相关的几个关键点：
///  - 最大子节点数：一个非叶子节点最多可以有 m 个子节点。
///  - 最小子节点数：除了根节点之外，一个非叶子节点至少有 m/2 个子节点，根节点至少有两个子节点，除非它是叶节点。
///  - 键的数量：在非叶子节点中，键的数量比子节点的数量少 1。也就是说，一个非叶子节点包含的键的数量在 m/2 - 1 到 m -1 之间。
///  - 叶节点：叶节点通常包含相同数量的键，并且它们之间是通过指针连接的，形成一个有序链表。叶节点的子节点数量是0。
///
/// 该 B+Tree 实现不拆分叶子节点和中间节点，主要基于以下几点考虑：
///
/// 1. **拆分带来的内存节省有限**
///    - 叶子节点的 `children` 属性使用 `Optional` 类型，与拆分节点相比，额外的内存开销相同，都是 **8 字节**。
///    - 也就是说，拆分节点仅能减少中间节点的内存消耗，而叶子节点的数量通常远大于中间节点，至少是 `min_degree` 倍。
///    - 仅在 **极端大规模数据** 场景下，拆分节点的内存优化才会体现，但即便如此，节省的比例仍然较小，相较之下，从其他方面优化更具收益。
///    - 当然，拆分节点对 **中间节点** 确实能显著减少内存占用，大约可降低至原来的 **六分之一**（不拆分: `24 + 8 + 8 + 8` 字节，拆分后仅 `8` 字节）。
///
/// 2. **拆分并非零成本**
///    - 采用 **继承** 实现拆分，代码上更优雅，但会引入 **动态派发**，增加运行时开销。
///    - 使用 **协议**，特别是泛型协议，不仅无法直接作为类型使用，还可能同样引入动态派发的问题。
///    - 采用 **枚举** 封装叶子节点和中间节点，会导致 **每个节点额外增加 8 字节**，并且带来 **解包** 及额外的运行时开销。
///
/// 3. **代码复杂度与运行时成本**
///    - 拆分后，代码需要额外区分叶子节点和中间节点，增加实现复杂度。
///    - 访问数据时需进行额外的类型判断和解包，影响查询效率。
///    - 目前的设计在 **保持代码简洁** 的同时，通过 `Optional` 优化 `children`，有效减少了叶子节点的无效内存占用。
///
/// **综上所述，拆分节点带来的内存优化比例有限，且增加了代码复杂度和运行时开销。**
/// 因此，本实现 **不拆分节点**，而是采用 `Optional` 优化 `children`，重点降低叶子节点的存储成本，以实现更高效的内存利用率。
///
/// 为了性能该实现相当于手动内联了，有不少重复代码。
public class BPlusTree<Key: Comparable, Value> {
    public typealias Element = (Key, Value)
    typealias Node = BPlusTreeNode<Key, Value>

    /// 根节点
    var root: Node?

    /// 树的阶-表示内部子节点的最大数量
    /// 最小值为 3，表示每个内部节点最多存在 3 个子节点
    private let order: Int

    /// 元素数量
    private var numberOfElements: Int

    /// 初始化
    /// - Parameter order: 阶数
    public init(order: Int) {
        // 因为 BPlusTree 不像 BTree 那样在分裂时间 keys、value 提升，而是复制，所以无论 Top-Down 还是 Bottom-Up order 都可以最低支持到 3
        precondition(order >= 3, "Order must be greater than or equal to 3.")

        self.root = nil
        self.order = order
        self.numberOfElements = 0
    }

    /// 默认初始化
    public required convenience init() {
        // 16 是一个比较好的折中值：
        // 1. 对于大多数 Key/Value 类型，一个节点能装入 1-2 个缓存行
        // 2. 树的高度适中，3层可以存储约 4096 个元素
        // 3. 二分查找的开销不会太大（最多比较 4 次）
        self.init(order: 16)
    }
}

// MARK: - BPlusTreeNode

/// 如果为 values + children 使用 Optional 来节省内存，因为有节省也会增加，那么最终是一个节点节省 8 个字节。
final class BPlusTreeNode<Key: Comparable, Value> {
    var values: [Value] = []
    var keys: ContiguousArray<Key> = []
    var children: ContiguousArray<BPlusTreeNode<Key, Value>> = []

    var prev: BPlusTreeNode<Key, Value>?
    var next: BPlusTreeNode<Key, Value>?

    var isLeaf: Bool { children.isEmpty }

    init() {}

    /// 创建根叶子节点
    init(key: Key, value: Value) {
        self.keys = [key]
        self.values = [value]
    }

    /// 创建新的根叶子节点
    init(key: Key, left: BPlusTreeNode<Key, Value>, right: BPlusTreeNode<Key, Value>) {
        self.keys = [key]
        self.children = [left, right]
    }

    /// 没有额外的判断，需要调用者保证 index 在有效范围内
    func keyValuePair(at index: Int) -> (Key, Value) {
        (keys[index], values[index])
    }
}

// MARK: - 便捷初始化

public extension BPlusTree {
    /// 从数组中初始化
    ///
    /// - debug 模式下会进行有序性检查，release 模式为了性能不会进行检查
    /// - 有序性检查的复杂度为 O(n)
    convenience init(contentsOf elements: [Element], order: Int? = nil) {
        #if DEBUG
        for i in 1..<elements.count {
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

    @inline(__always)
    private func bulkLoad(contentsOf elements: [Element]) {
        if elements.isEmpty { return }

        numberOfElements = elements.count

        /// 如果元素数量小于等于 order - 1，则直接创建根叶子节点
        if elements.count <= MAX_KEY_COUNT {
            let leafNode = createLeafNode()
            /// ChatGPT 说设置了 reserveCapacity 后，即使这里使用 append(contentsOf:) 需要两次遍历，但是比直接使用 append 要快。
            leafNode.keys.append(contentsOf: elements.map { $0.0 })
            leafNode.values.append(contentsOf: elements.map { $0.1 })
            root = leafNode
            return
        }

        var index = 0
        var nodes: [Node] = []
        nodes.reserveCapacity(elements.count / MAX_KEY_COUNT + 1)

        /// 构建叶子节点，其中每个节点其值都超出限制
        /// 因为内层节点的 Key 都来源于叶子节点，而不是其下层节点，所以这里采取策略：
        /// - 构建叶子时将该叶子节点的最小值复制到 keys 的最后一个位置。
        /// - 构建内层节点时从子节点的 keys.last 取值，并且将第一个子节点的 keys.last 放置在内层节点的 keys.last
        /// - 虽然这样最上层第一个子节点的 .last 用不上，但是也节省了很多计算量。
        while index < elements.count {
            let remainingCount = elements.count - index
            let endIndex = Swift.min(MAX_KEY_COUNT, remainingCount)

            /// ceil(order / 2) 是 min 和 max 子节点数，键的数量还需要 - 1
            if remainingCount >= MIN_KEY_COUNT {
                let leafNode = createLeafNode()

                for i in index..<(index + endIndex) {
                    leafNode.keys.append(elements[i].0)
                    leafNode.values.append(elements[i].1)
                }
                /// 用于上层节点的分隔值
                leafNode.keys.append(elements[index].0)

                /// 叶子节点需要添加前后指针。
                if let previousNode = nodes.last {
                    previousNode.next = leafNode
                    leafNode.prev = previousNode
                }

                nodes.append(leafNode)
            }
            else {
                /// 如果最后一个节点元素太少，则需要向前一个节点借一些
                let previousNode = nodes.removeLast()
                let leaftNodeMinValue = previousNode.keys.removeLast()
                let splitIndex = (previousNode.keys.count + remainingCount) / 2

                let leftNode = createLeafNode()
                leftNode.keys.append(contentsOf: previousNode.keys[..<splitIndex])
                leftNode.values.append(contentsOf: previousNode.values[..<splitIndex])

                /// 用于上层节点的分隔值
                leftNode.keys.append(leaftNodeMinValue)

                /// 分裂时左节点拥有最小元素数，splitIndex 所在元素将分配给右节点
                let rightNode = createLeafNode()
                let rightElements = elements[(elements.count - splitIndex - 1)...]
                for element in rightElements {
                    rightNode.keys.append(element.0)
                    rightNode.values.append(element.1)
                }

                /// 用于上层节点的分隔值
                rightNode.keys.append(rightElements[rightElements.startIndex].0)

                /// 前后指针修正
                rightNode.prev = leftNode
                leftNode.next = rightNode
                leftNode.prev = previousNode.prev

                nodes.append(leftNode)
                nodes.append(rightNode)
            }

            index += endIndex
        }

        /// 构建内部节点
        var nexts: [Node] = []
        nexts.reserveCapacity(nodes.count / order)
        while nodes.count > 0 {
            nexts.removeAll()

            /// 如果节点数量小于等于 order，则直接创建根内部节点
            if nodes.count <= MAX_CHILD_COUNT {
                let root = createInternalNode()
                root.children.append(contentsOf: nodes)
                nodes[0].keys.removeLast()
                root.keys.append(contentsOf: nodes[1...].map { $0.keys.removeLast() })
                self.root = root
                break
            }

            /// 如果节点数量大于 order，则需要创建新的一层内部节点
            var i = 0
            while i < nodes.count {
                /// 使用切片避免数组的拷贝开销
                let endIndex = i + MAX_CHILD_COUNT
                let children = nodes[i..<(Swift.min(endIndex, nodes.count))]
                i = endIndex

                if children.count >= MIN_CHILD_COUNT {
                    let newNode = createInternalNode()
                    newNode.children.append(contentsOf: children)

                    let minValue = children[children.startIndex].keys.removeLast()
                    newNode.keys.append(contentsOf: children[children.index(after: children.startIndex)...].map { $0.keys.removeLast() })
                    newNode.keys.append(minValue)
                    nexts.append(newNode)
                }
                else {
                    /// 只有最后一个节点可能不满
                    let previousNode = nexts.removeLast()

                    let leftNodeMinValue = previousNode.keys.removeLast()
                    let splitIndex = (previousNode.keys.count + keys.count) / 2

                    let leftNode = createInternalNode()
                    leftNode.keys.append(contentsOf: previousNode.keys[..<splitIndex])
                    leftNode.children.append(contentsOf: previousNode.children[...splitIndex])

                    leftNode.keys.append(leftNodeMinValue)

                    let rightNode = createInternalNode()
                    rightNode.children.append(contentsOf: previousNode.children[(splitIndex + 1)...])
                    rightNode.children.append(contentsOf: children)

                    /// 这里需要从 children 中取，因为再分配时，前一个节点的最后一个子节点重新分配过来了,
                    /// 但是这个子节点的 key 并不存在于 previousNode.keys 中
                    rightNode.keys.append(contentsOf: previousNode.keys[(splitIndex + 1)...])
                    rightNode.keys.append(contentsOf: children.map { $0.keys.removeLast() })

                    /// 分裂时需要重新递归向下查找最小值了

                    var node = rightNode.children[0]
                    while let next = node.children.first ?? nil {
                        node = next
                    }
                    rightNode.keys.append(node.keys[0])

                    nexts.append(leftNode)
                    nexts.append(rightNode)
                }
            }

            nodes = nexts
        }
    }
}

// MARK: - 私有方法

extension BPlusTree {
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
        return log(Double(((order + 1) / 2)), numberOfElements)
    }

    @inline(__always)
    private var MIN_KEY_COUNT: Int {
        ((order + 1) / 2) - 1
    }

    @inline(__always)
    private var splitIndex: Int {
        ((order + 1) / 2) - 1
    }

    @inline(__always)
    private var MAX_KEY_COUNT: Int {
        order - 1
    }

    /// ceil(order / 2)
    @inline(__always)
    private var MIN_CHILD_COUNT: Int {
        (order + 1) / 2
    }

    @inline(__always)
    private var MAX_CHILD_COUNT: Int {
        order
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
        let node = Node(key: key, value: value)
        node.keys.reserveCapacity(order)
        node.values.reserveCapacity(order)

        return node
    }

    @inline(__always)
    private func createInternalNode() -> Node {
        let node = Node()
        node.keys.reserveCapacity(order)
        node.children.reserveCapacity(order)

        return node
    }

    @inline(__always)
    private func createInternalNode(key: Key, left: Node, right: Node) -> Node {
        let node = Node(key: key, left: left, right: right)
        node.keys.reserveCapacity(order)
        node.children.reserveCapacity(order)

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
    private func findChildIndex(node: Node, key: Key) -> Int {
        let index = findLowerBoundIndex(node: node, key: key)
        /// 内部节点的 key 在 BPlusTree 中是放在右子节点中的需要+1
        return index < node.keys.count && node.keys[index] == key ? index + 1 : index
    }

    @inline(__always)
    func findKeyIndex(node: Node, key: Key) -> Int {
        findLowerBoundIndex(node: node, key: key)
    }

    /// 查找指定的 Key 在 elements 中的下边界
    @inline(__always)
    private func findLowerBoundIndex(node: Node, key: Key) -> Int {
        /// 当数据量较小时比如小于16时，循环查找通常性能更优。
        order <= 16 ? linearSearchLowerBound(node, key: key) : binarySearchLowerBound(node, key: key)
    }

    /// 使用二分查找的 Lower Bound Search
    /// 使用二分搜索找到指定 Key 的插入点即：
    /// 1. 如果指定的 Key 存在，则返回对应下标
    /// 2. 如果指定的 Key 不存在，返回第一个大于 Key 的元素的下标
    @inline(__always)
    private func binarySearchLowerBound(_ node: Node, key: Key) -> Int {
        var lowerBound = 0
        var upperBound = keys.count
        while lowerBound < upperBound {
            let midIndex = lowerBound + (upperBound - lowerBound) / 2
            let midKey = keys[midIndex]
            if midKey < key {
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
                if buffer[index] > key {
                    return index
                }
                index += 1
            }
            return count
        }
    }
}

// MARK: - 计算属性

public extension BPlusTree {
    /// 树中存在的元素数目
    var count: Int { numberOfElements }

    /// 是否为空
    var isEmpty: Bool { numberOfElements == 0 }

    /// 树的高度
    ///
    /// 时间复杂度：O(log n)
    var height: Int {
        guard let root = root else { return 0 }
        var height = 1
        var current: Node = root
        while current.isLeaf == false {
            height += 1
            current = current.children.first.unsafelyUnwrapped
        }
        return height
    }

    /// 集合中最小的元素（升序排序下的第一个元素），若集合为空则返回 nil
    ///
    /// 时间复杂度：O(log n)
    var min: Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
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
            current = current.children.last.unsafelyUnwrapped
        }
        return current.keyValuePair(at: current.keys.count - 1)
    }

    /// 集合中所有键的数组
    ///
    /// 时间复杂度：O(log n + n)
    var keys: [Key] {
        guard let root = root else { return [] }
        return [Key](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = root
            while current.isLeaf == false {
                current = current.children.first.unsafelyUnwrapped
            }
            var leafNode: Node? = current
            while let node = leafNode {
                for key in node.keys {
                    buffer[initializedCount] = key
                    initializedCount += 1
                }
                leafNode = node.next
            }
        }
    }

    /// 集合中所有值的数组
    ///
    /// 时间复杂度：O(log n + n)
    var values: [Value] {
        guard let root = root else { return [] }
        return [Value](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = root
            while current.isLeaf == false {
                current = current.children.first.unsafelyUnwrapped
            }
            var leafNode: Node? = current
            while let node = leafNode {
                for value in node.values {
                    buffer[initializedCount] = value
                    initializedCount += 1
                }
                leafNode = node.next
            }
        }
    }

    /// 返回按升序排列的所有元素数组
    ///
    /// 时间复杂度：O(log n + n)
    var elements: [Element] {
        guard let root = root else { return [] }
        
        
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = root
            while current.isLeaf == false {
                current = current.children.first.unsafelyUnwrapped
            }
            var leafNode: Node? = current
            while let node = leafNode {
                var index = 0
                let count = node.values.count
                while index < count {
                    
                    buffer[initializedCount] = node.keyValuePair(at: index)
                    index += 1
                    initializedCount += 1
                }
                leafNode = node.next
            }
        }
    }

    /// 返回按降序排列的所有元素数组
    ///
    /// 时间复杂度：O(log n + n)
    var reversed: [Element] {
        guard let root = root else { return [] }
        
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = root
            while current.isLeaf == false {
                current = current.children.last.unsafelyUnwrapped
            }
            
            var leafNode: Node? = current
            while let node = leafNode {
                var index = node.values.count - 1
                while index >= 0 {
                    
                    buffer[initializedCount] = node.keyValuePair(at: index)
                    index -= 1
                    initializedCount += 1
                }
                leafNode = node.prev
            }
        }
    }

    /// 返回一个实现了 Sequence 协议的序列，用于遍历所有元素
    /// 返回的 Sequence 是持有 BTree 的引用，所以遍历的元素是共享的。当 BTree 修改时，Sequence 也会随之修改。
    var elementsSequence: BPlusTreeSequence<Key, Value> {
        BPlusTreeSequence(self)
    }

    /// 返回一个实现了 Sequence 协议的序列，用于降序遍历所有元素
    /// 返回的 Sequence 是持有 BTree 的引用，所以遍历的元素是共享的。当 BTree 修改时，Sequence 也会随之修改。
    var reversedSequence: BPlusTreeReversedSequence<Key, Value> {
        BPlusTreeReversedSequence(self)
    }
}

// MARK: - 核心增删改查

public extension BPlusTree {
    /// 查找给定键对应的值，若存在则返回该值，否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func search(key: Key) -> Value? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        let index = findLowerBoundIndex(node: current, key: key) - 1
        if index < 0 || current.keys[index] != key {
            return nil
        }
        return current.values[index]
    }

    /// 插入一个键值对 - 基于 Bottom-Up 的实现方式
    ///
    /// - 如果键已存在，则不进行插入并返回 false
    /// - 如果插入成功，则返回 true
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func insert(key: Key, value: Value) -> Bool {
        guard let root = root else {
            numberOfElements = 1
            self.root = createLeafNode(key: key, value: value)
            return true
        }

        var current: Node = root
        var ancestorPath: [(Node, Int)] = []
        ancestorPath.reserveCapacity(estimatedTreeHeight)
        /// 下降到叶子节点
        while current.isLeaf == false {
            let lowerBoundIndex = findLowerBoundIndex(node: current, key: key)
            ancestorPath.append((current, lowerBoundIndex))
            current = current.children[lowerBoundIndex]
        }
        /// 是否存在于叶子节点
        let insertPos = findLowerBoundIndex(node: current, key: key)
        if insertPos > 0, current.keys[insertPos - 1] == key {
            return false
        }
        /// 插入
        numberOfElements += 1
        current.keys.insert(key, at: insertPos)
        current.values.insert(value, at: insertPos)

        /// 无需分裂
        if current.keys.count < order {
            return true
        }

        /// 元素分裂点
        /// ceil(order / 2)
        let splitIndex = MIN_KEY_COUNT

        /// 指针修改
        var leftChild = current

        /// 将要被提升的 element
        var promotedKey = current.keys[splitIndex]

        /// 复制 elements 到新的右兄弟节点。
        var rightChild = createLeafNode(keys: current.keys[splitIndex...], values: current.values[splitIndex...])

        /// 删除被提升和已复制到右兄弟节点的 elements
        current.keys.removeSubrange(splitIndex...)
        current.values.removeSubrange(splitIndex...)
        
        /// 维护前后指针
        rightChild.prev = leftChild
        rightChild.next = leftChild.next
        leftChild.next?.prev = rightChild
        leftChild.next = rightChild

        /// 向上回溯操作
        ancestorPath.withUnsafeBufferPointer { buffer in
            var bufferIndex = buffer.count
            while bufferIndex > 0 {
                bufferIndex -= 1
                let (parent, index) = buffer[bufferIndex]

                /// 修改 left 指针
                parent.children[index] = leftChild
                /// 插入新的 element
                parent.keys.insert(promotedKey, at: index)
                /// 修改 right 指针
                parent.children.insert(rightChild, at: index + 1)
                /// 如果中间节点插入后未满，就直接 break
                if parent.keys.count < order {
                    break
                }

                /// 指针修改
                leftChild = parent
                /// 需要提升的 key
                promotedKey = parent.keys[splitIndex]

                /// 复制到右边
                rightChild = createInternalNode()
                rightChild.keys.append(contentsOf: parent.keys[(splitIndex + 1)...])
                rightChild.children.append(contentsOf: parent.children[(splitIndex + 1)...])

                /// 删除被提升的和复制到 right 节点的 elements
                parent.keys.removeSubrange(splitIndex...)
                /// children 不会存在提升，所以无需删除 midIndex 对应的子节点
                parent.children.removeSubrange((splitIndex + 1)...)
            }
        }

        // 如果遍历完所有祖先节点后，最后的节点仍然需要分裂
        // 说明需要创建新的根节点
        if leftChild === root {
            self.root = createInternalNode(key: promotedKey, left: leftChild, right: rightChild)
        }

        return true
    }

    /// 更新已存在的键的值
    ///
    /// - 如果键不存在，则不进行更新并返回 nil
    /// - 如果更新成功，则返回旧值
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func update(key: Key, value: Value) -> Value? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        let index = findLowerBoundIndex(node: current, key: key) - 1
        if index < 0 || current.keys[index] != key {
            return nil
        }
        let oldValue = current.values[index]
        current.values[index] = value
        return oldValue
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

        var current: Node = root
        var ancestorPath: [(Node, Int)] = []
        ancestorPath.reserveCapacity(estimatedTreeHeight)
        /// 下降到叶子节点
        while current.isLeaf == false {
            let index = findLowerBoundIndex(node: current, key: key)
            ancestorPath.append((current, index))
            current = current.children[index]
        }
        /// 是否存在于叶子节点
        let insertPos = findLowerBoundIndex(node: current, key: key)
        if insertPos > 0, current.keys[insertPos - 1] == key {
            let oldValue = current.values[insertPos - 1]
            current.values[insertPos - 1] = value
            return oldValue
        }
        
        /// 插入
        numberOfElements += 1
        current.keys.insert(key, at: insertPos)
        current.values.insert(value, at: insertPos)

        /// 无需分裂
        if current.keys.count < order {
            return nil
        }

        /// 元素分裂点
        let splitIndex = MIN_KEY_COUNT

        /// 指针修改
        var leftChild = current

        /// 将要被提升的 element
        var promotedKey = current.keys[splitIndex]

        /// 复制 elements 到新的右兄弟节点。
        var rightChild = createLeafNode(keys: current.keys[splitIndex...], values: current.values[splitIndex...])

        /// 删除被提升和已复制到右兄弟节点的 elements
        current.keys.removeSubrange(splitIndex...)
        current.values.removeSubrange(splitIndex...)

        /// 维护前后指针
        rightChild.prev = leftChild
        rightChild.next = leftChild.next
        leftChild.next?.prev = rightChild
        leftChild.next = rightChild

        /// 向上回溯操作
        ancestorPath.withUnsafeBufferPointer { buffer in
            var bufferIndex = buffer.count - 1
            while bufferIndex >= 0 {
                let (parent, index) = buffer[bufferIndex]

                /// 修改 left 指针
                parent.children[index] = leftChild
                /// 插入新的 element
                parent.keys.insert(promotedKey, at: index)
                /// 修改 right 指针
                parent.children.insert(rightChild, at: index + 1)
                /// 如果中间节点插入后未满，就直接 break
                if parent.keys.count < order {
                    break
                }

                /// 指针修改
                leftChild = parent
                /// 需要提升的 key
                promotedKey = parent.keys[splitIndex]

                /// 复制到右边
                rightChild = createInternalNode()
                rightChild.keys.append(contentsOf: parent.keys[(splitIndex + 1)...])
                rightChild.children.append(contentsOf: parent.children[(splitIndex + 1)...])

                /// 删除被提升的和复制到 right 节点的 elements
                parent.keys.removeSubrange(splitIndex...)
                /// children 不会存在提升，所以无需删除 midIndex 对应的子节点
                parent.children.removeSubrange((splitIndex + 1)...)

                bufferIndex -= 1
            }
        }

        // 如果遍历完所有祖先节点后，最后的节点仍然需要分裂
        // 说明需要创建新的根节点
        if leftChild === root {
            self.root = createInternalNode(key: promotedKey, left: leftChild, right: rightChild)
        }
        return nil
    }

    /// 删除指定键对应的元素 - 基于 Top-Down 的实现方式
    ///
    /// - 如果键不存在，则返回 nil
    /// - 如果删除成功，则返回被删除的值
    ///
    /// 时间复杂度：O(log n)
    @discardableResult
    func remove(key: Key) -> Value? {
        guard let root = root else { return nil }

        let minKeys = MIN_KEY_COUNT

        /// BPlusTree 的删除与 BTree 有很大不同，BPlusTree 允许被删除的key继续在内部节点中存在
        /// 也就是说内层节点只是用来作为索引的，只在借用与合并中发生更改，删除一般也是不会影响到的。
        /// 这里就可以省略 BTree 的前驱后继路径下降的分支了。
        var current: Node = root
        while current.isLeaf == false {
            var position = findLowerBoundIndex(node: current, key: key)

            let child = current.children[position]
            

            /// 是否需要进行调整
            /// 采用优先左借用与合并的策略，不检测两边键数谁更多。
            if child.keys.count <= minKeys {

                /// 内层节点不存在 next 与 prev 指针的
                /// 8 38 50
                /// ├── 4 5 7
                /// │   ├── 1 2 3
                /// │   ├── 4
                /// │   ├── 5
                /// │   └── 7
                /// ├── 33
                /// │   ├── 8 13 23
                /// │   └── 33
                /// ├── 46
                /// │   ├── 38
                /// │   └── 46
                /// └── 56 57 61
                ///     ├── 50
                ///     ├── 56
                ///     ├── 57
                ///     └── 61 62 78
                /// 如果左兄弟存在多余节点，就向它借一个
                /// 有个麻烦的地方在于如果目标键存在内部节点的 keys 中，那么 position 需要 +1 才能指向正确的子节点。
                if position > 0, position < current.children.count, current.children[position - 1].keys.count > minKeys {
                    let leftBorther = current.children[position - 1]
                    
                    if child.isLeaf == false {
                        child.keys.insert(current.keys[position - 1], at: 0)
                        child.children.insert(leftBorther.children.removeLast(), at: 0)

                        current.keys[position - 1] = leftBorther.keys.removeLast()
                    }
                    else {
                        child.keys.insert(leftBorther.keys.removeLast(), at: 0)
                        child.values.insert(leftBorther.values.removeLast(), at: 0)
                        
                        current.keys[position - 1] = child.keys[0]
                    }
                }
                /// 如果右兄弟存在多余节点, 就向它借一个
                else if position < current.children.count - 1, current.children[position + 1].keys.count > minKeys {
                    let rightBorther = current.children[position + 1]

                    if child.isLeaf == false {
                        child.keys.append(current.keys[position])
                        child.children.append(rightBorther.children.removeFirst())

                        current.keys[position] = rightBorther.keys.removeFirst()
                    }
                    else {
                        child.keys.append(rightBorther.keys.removeFirst())
                        child.values.append(rightBorther.values.removeFirst())

                        current.keys[position] = rightBorther.keys[0]
                    }
                }
                /// 都没有就尝试合并
                else {
                   
                    /// 优先合并后继节点
                    let (leftNode, rightNode, delimiter) = position > 0
                    ? (current.children[position - 1], child, position - 1)
                    : (child, current.children[position + 1], position)

                    if leftNode.isLeaf == false {
                        leftNode.keys.append(current.keys[delimiter])
                        leftNode.keys.append(contentsOf: rightNode.keys)
                        leftNode.children.append(contentsOf: rightNode.children)

                        current.keys.remove(at: delimiter)
                        current.children.remove(at: delimiter + 1)
                    }
                    else {
                        leftNode.keys.append(contentsOf: rightNode.keys)
                        leftNode.values.append(contentsOf: rightNode.values)

                        current.keys.remove(at: delimiter)
                        current.children.remove(at: delimiter + 1)
                        
                        /// 维护指针
                        leftNode.next = rightNode.next
                        rightNode.next?.prev = leftNode
                        
                    }
                    

                    /// 左合并后，分隔值需要-1，因为 position 被合并至左节点了
                    position = delimiter
                }
            }

            current = current.children[position]
        }

        let position = findKeyIndex(node: current, key: key) - 1
        
        /// 不存在
        if position < 0 || current.keys[position] != key {
            /// Top-Down的实现在循环内就已经调整完了，叶子节点的删除不会影响层级
            /// 所以在这里需要检查树的高度是否有降低
            if self.root!.keys.count == 0 {
                self.root = self.root!.children.first ?? nil
            }
            return nil
        }

        /// 再循环中其实已经为这个叶子节点进行了借用与合并操作，此时删除必定不会触发借用或合并。
        numberOfElements -= 1
        current.keys.remove(at: position)

        /// 检查树的高度是否有降低
        /// 如果根节点就是叶子节点，那么此处可能会删除完
        if self.root!.keys.count == 0 {
            self.root = self.root!.children.first ?? nil
        }
        
        return current.values.remove(at: position)
    }

    /// 清空集合中所有的元素
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
            if let newValue = newValue {
                upsert(key: key, value: newValue)
            }
            else {
                remove(key: key)
            }
        }
    }
}

// MARK: - 查询操作

public extension BPlusTree {
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
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        // 返回的下标是后继
        let index = findLowerBoundIndex(node: current, key: key)
        
        // 上一个元素必定是小于等于目标的
        if index > 0{
            return current.keyValuePair(at: index - 1)
        }
        // 如果需要查看左边的叶子节点
        if let left = current.prev {
            return left.keyValuePair(at: left.keys.count - 1)
        }
        return nil
    }

    /// 返回大于等于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func ceiling(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        /// 这里查询第一个大于 key 的下标所以直接拿到的就是 后继需要判断相等，需要 -1 判断
        let index = findLowerBoundIndex(node: current, key: key)
        
        // 如果存在相等的元素
        if index > 0, current.keys[index - 1] == key {
            return current.keyValuePair(at: index - 1)
        }
        // 如果大于 keys 中的所有元素
        if index == current.keys.count {
            return current.next?.keyValuePair(at: 0)
        }
        // 后继
        return current.keyValuePair(at: index)
    }

    /// 返回小于指定键的最大元素
    ///
    /// - Returns: 若存在，则返回满足条件的最大元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func predecessor(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        let index = findLowerBoundIndex(node: current, key: key)
        
        // 如果当前位置有更小的元素
        if index > 0 {
            if current.keys[index - 1] == key {
                if index > 1 {
                    return current.keyValuePair(at: index - 2)
                }
                if let left = current.prev {
                    return left.keyValuePair(at: left.keys.count - 1)
                }
                return nil
            }
            return current.keyValuePair(at: index - 1)
        }
        // 如果需要查看左边的叶子节点
        if let left = current.prev {
            return left.keyValuePair(at: left.keys.count - 1)
        }
        return nil
    }

    /// 返回大于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    ///
    /// 时间复杂度：O(log n)
    func successor(key: Key) -> Element? {
        guard let root = root else { return nil }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: key)]
        }
        let index = findLowerBoundIndex(node: current, key: key)
        // 返回的 index 必定不会等于目标键
        
        if index == current.keys.count {
            return current.next?.keyValuePair(at: 0)
        }

        // 找到的是大于 key 的最小元素
        return current.keyValuePair(at: index)
    }

    /// 返回指定范围内的所有元素
    ///
    /// - Returns: 位于指定范围内的元素数组
    ///
    /// 时间复杂度：O(log n + n)
    func range(in range: ClosedRange<Key>) -> [Element] {
        guard let root = root else { return [] }
        var current: Node = root
        var result: [Element] = []

        while current.isLeaf == false {
            current = current.children[findLowerBoundIndex(node: current, key: range.lowerBound)]
        }
        var leafNode: Node? = current
        var startIndex = findLowerBoundIndex(node: current, key: range.lowerBound)
        
        // startIndex 找到的是后继，这里检查下是否存在与 range.lowerBound 相等的元素
        if startIndex > 0 {
            if current.keys[startIndex - 1] == range.lowerBound {
                startIndex -= 1
            }
        } else {
            // 检查左兄弟节点是否存在与 range.lowerBound 相等的元素
            if let left = current.prev {
                if left.keys.last! == range.lowerBound {
                    result.append(left.keyValuePair(at: left.keys.endIndex - 1))
                }
            }
        }
       
        while let node = leafNode {
            let elementRange = startIndex..<node.keys.count
            for index in elementRange {
                if node.keys[index] > range.upperBound {
                    break
                }
                result.append(node.keyValuePair(at: index))
            }
            startIndex = 0
            leafNode = node.next
        }
        return result
    }
}

// MARK: - 遍历操作

public extension BPlusTree {
    /// 遍历所有元素
    ///
    /// 时间复杂度：O(log n + n)
    func traverse(_ body: (Element) throws -> Void) rethrows {
        guard let root = root else { return }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            let range = 0..<node.keys.count
            for index in range {
                try body(node.keyValuePair(at: index))
            }
            leafNode = node.next
        }
    }

    /// 倒序遍历所有元素
    ///
    /// 时间复杂度：O(log n + n)
    func reversedTraverse(_ body: (Element) throws -> Void) rethrows {
        guard let root = root else { return }
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.last.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            var index = node.keys.count - 1
            while index >= 0 {
                try body(node.keyValuePair(at: index))
                index -= 1
            }
            leafNode = node.prev
        }
    }

    /// 对所有元素应用转换函数
    ///
    /// 时间复杂度：O(log n + n)
    func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        guard let root = root else { return [] }
        var result: [T] = []
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            let range = 0..<node.keys.count
            for index in range {
                try result.append(transform(node.keyValuePair(at: index)))
            }
            leafNode = node.next
        }
        return result
    }

    /// 对所有元素应用转换函数, 并返回非 nil 的元素
    ///
    /// 时间复杂度：O(log n + n)
    func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T] {
        guard let root = root else { return [] }
        var result: [T] = []
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            let range = 0..<node.keys.count
            for index in range {
                if let transformed = try transform(node.keyValuePair(at: index)) {
                    result.append(transformed)
                }
            }
            leafNode = node.next
        }
        return result
    }

    /// 对所有元素进行归约计算，并返回累加值
    ///
    /// 时间复杂度：O(log n + n)
    func reduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) throws -> T) rethrows -> T {
        guard let root = root else { return initialResult }
        var result = initialResult
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            let range = 0..<node.keys.count
            for index in range {
                result = try nextPartialResult(result, node.keyValuePair(at: index))
            }
            leafNode = node.next
        }
        return result
    }

    /// 对集合中的元素执行归约操作，并通过 `inout` 参数直接修改初始累加值。
    ///
    /// 时间复杂度：O(log n + n)
    func reduce<T>(into initialResult: T, _ updateAccumulatingResult: (inout T, Element) throws -> Void) rethrows -> T {
        guard let root = root else { return initialResult }
        var result = initialResult
        var current: Node = root
        while current.isLeaf == false {
            current = current.children.first.unsafelyUnwrapped
        }
        var leafNode: Node? = current
        while let node = leafNode {
            let range = 0..<node.keys.count
            for index in range {
                try updateAccumulatingResult(&result, node.keyValuePair(at: index))
            }
            leafNode = node.next
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension BPlusTree: CustomStringConvertible {
    /// 其实可以跟踪叶子节点数，内部节点数的，方便计算内存消耗，但是需要维护两个变量，比较麻烦，所以暂时不实现。
    public var description: String {
        """
        BPlusTree:
        - Height: \(height)
        - Number of elements: \(numberOfElements)
        - Order: \(order) (maximum number of children per node)
        """
    }
}

// MARK: - OrderedCollection

extension BPlusTree: OrderedCollection {}

// MARK: - Sequence+Iterator

public struct BPlusTreeSequence<Key: Comparable, Value>: Sequence {
    let tree: BPlusTree<Key, Value>

    init(_ tree: BPlusTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> BPlusTreeIterator<Key, Value> {
        BPlusTreeIterator(tree)
    }
}

public struct BPlusTreeReversedSequence<Key: Comparable, Value>: Sequence {
    let tree: BPlusTree<Key, Value>

    init(_ tree: BPlusTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> BPlusTreeReversedIterator<Key, Value> {
        BPlusTreeReversedIterator(tree)
    }
}

public struct BPlusTreeIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = BPlusTree<Key, Value>.Element

    private var index: Int
    private var current: BPlusTree<Key, Value>.Node?

    init(_ tree: BPlusTree<Key, Value>) {
        var current: BPlusTree<Key, Value>.Node? = tree.root
        while let node = current, node.isLeaf == false {
            current = node.children.first.unsafelyUnwrapped
        }
        self.index = -1
        self.current = current
    }

    public mutating func next() -> Element? {
        guard let node = current else { return nil }

        if index < node.keys.count - 1 {
            index += 1
            return node.keyValuePair(at: index)
        }

        // 移动到下一个节点
        self.current = node.next
        guard let current = current else { return nil }

        index = 0
        return current.keyValuePair(at: index)
    }
}

public struct BPlusTreeReversedIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = BPlusTree<Key, Value>.Element

    private var index: Int
    private var current: BPlusTree<Key, Value>.Node?

    init(_ tree: BPlusTree<Key, Value>) {
        var current: BPlusTree<Key, Value>.Node? = tree.root
        while let node = current, node.isLeaf == false {
            current = node.children.last.unsafelyUnwrapped
        }
        self.current = current
        self.index = current?.keys.count ?? 0
    }

    public mutating func next() -> Element? {
        guard let node = current else { return nil }

        if index > 0 {
            index -= 1
            return node.keyValuePair(at: index)
        }

        // 移动到前一个节点
        self.current = node.prev
        guard let current = current else { return nil }

        index = current.keys.count - 1
        return current.keyValuePair(at: index)
    }
}

// MARK: - 调试方法-仅在 DEBUG 模式下有效

#if DEBUG
import TreePrinter

extension BPlusTreeNode: PrintableMultiwayTreeProtocol {
    var displayName: String {
        keys.map { "\($0)" }.joined(separator: " ")
    }

    var subnodes: [BPlusTreeNode<Key, Value>] {
        Array(children)
    }
}

extension BPlusTree: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard let root = root else { return "" }
        return MultiwayTreePrinter(root).print()
    }
}
#endif
