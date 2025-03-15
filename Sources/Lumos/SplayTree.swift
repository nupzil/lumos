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

/// **SplayTree**
///
/// 该实现的 Splay 操作是自顶向下（Top-Down）的，与自低向上（Down-Top）实现的 SplayTree 在同样的操作下，其树结构可能会不同。
///
/// `SplayTree` 是一种自调整二叉搜索树（Self-Adjusting Binary Search Tree），其特点是每次访问节点后都会通过 Splay 操作将该节点旋转到根位置。
///
/// ### 特性
/// - 适用于高频访问局部热点数据的场景。
/// - 不适合需要稳定树结构的并发环境。
///
/// ### 实现亮点
/// - **区间操作优化**:
///   `range` 方法未采用传统的 `split + join` 方法，而是基于 `Splay + 中序遍历` 的方式实现范围查询。相较于 `split + join`，此方法具有以下优势：
///   - **稳定性更高**：避免了多次分裂和合并操作可能带来的性能波动。
///   - **空间效率更优**：无需创建额外的子树结构，节省了内存开销。
///
/// ⚠️ **线程安全警告**:
/// - 非线程安全。在并发环境下使用时，需由外部提供同步机制。
/// - 大多数方法（如 `search`）会修改树结构，请务必注意其副作用。
public class SplayTree<Key: Comparable, Value> {
    public typealias Element = (Key, Value)

    typealias Node = SplayTreeNode<Key, Value>

    /// 根节点
    var root: Node?

    /// 元素数量
    private var numberOfElements: Int = 0

    /// 初始化一个空的 SplayTree。
    public required init() {}

    /// 内部初始化方法，用于从已有节点构建 SplayTree。
    private init(root: Node?) {
        self.root = root
    }
}

// MARK: - SplayTreeNode

final class SplayTreeNode<Key: Comparable, Value> {
    /// 键
    let key: Key
    /// 值
    var value: Value
    /// 左子节点
    var left: SplayTreeNode<Key, Value>?
    /// 右子节点
    var right: SplayTreeNode<Key, Value>?

    init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}

// MARK: - 私有方法

private extension SplayTree {
    /// 自顶向下的 Splay 操作，将目标键旋转到根节点。
    ///
    /// - 如果目标键存在于树中，则将其旋转到根节点并返回。
    /// - 如果目标键不存在，则将最后访问的节点旋转到根节点并返回。
    /// - 边界情况：如果树为空，直接返回 `nil`。
    ///
    /// ### 实现细节
    /// 维基百科描述了 Splay 树的六种旋转场景（zig, zag, zig-zig, zig-zag, zag-zig, zag-zag），
    /// 但这些是针对 `自底向上` 的实现方式。而 `自顶向下` 的实现通过分解组合操作（如将 zig-zag 分解为 zig + zag），
    /// 简化了逻辑，使得只需处理两种基本旋转：zig 和 zag。
    ///
    /// 自顶向下的 Splay 操作涉及三棵逻辑树：
    /// - 左树：存放所有大于目标键的节点。
    /// - 右树：存放所有小于目标键的节点。
    /// - 中树：当前正在遍历的子树。
    ///
    /// 使用一个虚拟节点 `dummy` 来辅助构建左树和右树，其左右子树分别指向左树和右树的根节点。
    @discardableResult
    private func splay(key: Key) -> Node? {
        /// 如果根节点为空或已经是目标节点，无需 Splay
        guard var node = root, node.key != key else { return root }

        /// 创建一个虚拟节点作为左树和右树的初始头节点, 这里初始的 key 和 value 不会被使用到。
        let dummy = Node(key: key, value: node.value)
        /// 左树尾指针
        var leftTail = dummy
        /// 右树尾指针
        var rightTail = dummy

        while true {
            if key < node.key {
                /// 当前节点的 key 大于目标 key，进入左子树
                guard let child = node.left else { break }
                /// zig-zig 场景：两次连续的右旋
                if key < child.key {
                    node.left = child.right
                    child.right = node
                    node = child
                    if node.left == nil { break }
                }
                /// 将当前节点加入左树，并更新左树尾指针
                leftTail.left = node
                leftTail = node
                /// 此处的 node.left 已经通过前面的 guard let 和内层的 if 判断确保非空，因此可以安全地使用强制解包。
                node = node.left.unsafelyUnwrapped
            } else if key > node.key {
                /// 当前节点的 key 小于目标 key，进入右子树
                guard let child = node.right else { break }
                /// zag-zag 场景：两次连续的左旋
                if key > child.key {
                    node.right = child.left
                    child.left = node
                    node = child
                    if node.right == nil { break }
                }
                /// 将当前节点加入右树，并更新右树尾指针
                rightTail.right = node
                rightTail = node
                /// 此处的 node.right 已经通过前面的 guard let 和内层的 if 判断确保非空，因此可以安全地使用强制解包。
                node = node.right.unsafelyUnwrapped
            } else {
                /// 找到目标节点，退出循环
                break
            }
        }

        /// 拼接左树、右树和中树
        leftTail.left = node.right /// 左树的尾部连接到当前节点的右子树
        rightTail.right = node.left /// 右树的尾部连接到当前节点的左子树

        /// 更新当前节点的左右子树
        node.left = dummy.right /// 左子树指向右树的根节点
        node.right = dummy.left /// 右子树指向左树的根节点

        /// 更新根节点为当前节点
        root = node

        return node
    }
}

// MARK: - 计算属性

/// ✅ **READ-ONLY**
public extension SplayTree {
    /// ✅ **READ-ONLY**: 返回树中元素的总数。
    var count: Int { numberOfElements }

    /// ✅ **READ-ONLY**: 判断树是否为空。
    var isEmpty: Bool { numberOfElements == 0 }

    /// ✅ **READ-ONLY**: 返回树中的最小值（中序遍历首元素）。
    var min: Element? {
        var minNode = root
        var parent = root
        while let node = minNode {
            minNode = node.left
            parent = node
        }
        return parent.map { ($0.key, $0.value) }
    }

    /// ✅ **READ-ONLY**: 返回树中的最大值（中序遍历末元素）。
    var max: Element? {
        var parent = root
        var maxNode = root
        while let node = maxNode {
            maxNode = node.right
            parent = node
        }
        return parent.map { ($0.key, $0.value) }
    }

    /// ✅ **READ-ONLY**: 升序返回树中的所有 `Key`。
    var keys: [Key] {
        guard let root else { return [] }
        return [Key](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var stack: [Node] = []
            var current: Node? = root
            while !stack.isEmpty || current != nil {
                if let node = current {
                    stack.append(node)
                    current = node.left
                } else {
                    let node = stack.removeLast()
                    buffer[initializedCount] = node.key
                    initializedCount += 1
                    current = node.right
                }
            }
        }
    }

    /// ✅ **READ-ONLY**: 升序返回树中的所有 `Value`。
    var values: [Value] {
        guard let root else { return [] }
        return [Value](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var stack: [Node] = []
            var current: Node? = root
            while !stack.isEmpty || current != nil {
                if let node = current {
                    stack.append(node)
                    current = node.left
                } else {
                    let node = stack.removeLast()
                    buffer[initializedCount] = node.value
                    initializedCount += 1
                    current = node.right
                }
            }
        }
    }

    /// ✅ **READ-ONLY**: 返回按升序排列的所有元素数组。
    var elements: [Element] {
        guard let root else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var stack: [Node] = []
            var current: Node? = root
            while !stack.isEmpty || current != nil {
                if let node = current {
                    stack.append(node)
                    current = node.left
                } else {
                    let node = stack.removeLast()
                    buffer[initializedCount] = (node.key, node.value)
                    initializedCount += 1
                    current = node.right
                }
            }
        }
    }

    /// ✅ **READ-ONLY**: 返回按降序排列的所有元素数组。
    var reversed: [Element] {
        guard let root else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var stack: [Node] = []
            var current: Node? = root
            while !stack.isEmpty || current != nil {
                if let node = current {
                    stack.append(node)
                    current = node.right
                } else {
                    let node = stack.removeLast()
                    buffer[initializedCount] = (node.key, node.value)
                    initializedCount += 1
                    current = node.left
                }
            }
        }
    }

    /// ✅ **READ-ONLY**: 返回升序 Sequence
    /// 返回的 Sequence 是持有 SplayTree 的引用，所以遍历的元素是共享的。当 SplayTree 修改时，Sequence 也会随之修改。
    var elementsSequence: SplayTreeSequence<Key, Value> {
        return SplayTreeSequence(self)
    }

    /// ✅ **READ-ONLY**: 返回降序 Sequence
    /// 返回的 Sequence 是持有 SplayTree 的引用，所以遍历的元素是共享的。当 SplayTree 修改时，Sequence 也会随之修改。
    var reversedSequence: SplayTreeReversedSequence<Key, Value> {
        return SplayTreeReversedSequence(self)
    }
}

// MARK: - 核心操作（增删改）

/// ⛔️ **STRUCTURAL**
public extension SplayTree {
    /// ⛔️ **STRUCTURAL**: 在树中查找指定键对应的值。
    func search(key: Key) -> Value? {
        guard let root = splay(key: key) else { return nil }
        return root.key == key ? root.value : nil
    }

    /// ⛔️ **STRUCTURAL**: 插入键值对。
    ///
    /// - 如果键已存在，则插入失败并返回 `false`。
    /// - 插入成功后，新节点将成为根节点。
    @discardableResult
    func insert(key: Key, value: Value) -> Bool {
        /// 对目标 key 进行 Splay 操作，确保树结构调整为适合插入的状态。
        guard let rootNode = splay(key: key) else {
            numberOfElements += 1
            root = Node(key: key, value: value)
            return true
        }

        // 如果 key 已存在，插入失败
        if rootNode.key == key {
            return false
        }

        // 创建新节点
        let newNode = Node(key: key, value: value)

        if rootNode.key < key {
            newNode.left = rootNode
            newNode.right = rootNode.right
            rootNode.right = nil
        } else {
            newNode.right = rootNode
            newNode.left = rootNode.left
            rootNode.left = nil
        }

        // 更新根节点并增加元素计数
        root = newNode
        numberOfElements += 1
        return true
    }

    /// ⛔️ **STRUCTURAL**: 更新指定键对应的值。
    ///
    /// - 如果键存在，则更新值并返回旧值。
    /// - 如果键不存在，则返回 `nil`。
    @discardableResult
    func update(key: Key, value: Value) -> Value? {
        guard let rootNode = splay(key: key) else { return nil }

        if rootNode.key != key {
            return nil
        }

        let oldValue = rootNode.value
        rootNode.value = value
        return oldValue
    }

    /// ⛔️ **STRUCTURAL**: 更新或插入指定键的值。
    ///
    /// - 如果键存在，则更新值并返回旧值。
    /// - 如果键不存在，则插入并返回 `nil`。
    @discardableResult
    func upsert(key: Key, value: Value) -> Value? {
        guard let rootNode = splay(key: key) else {
            numberOfElements += 1
            root = Node(key: key, value: value)
            return nil
        }

        if rootNode.key == key {
            let oldValue = rootNode.value
            rootNode.value = value
            return oldValue
        }

        // 创建新节点
        let newNode = Node(key: key, value: value)

        if rootNode.key < key {
            newNode.left = rootNode
            newNode.right = rootNode.right
            rootNode.right = nil
        } else {
            newNode.right = rootNode
            newNode.left = rootNode.left
            rootNode.left = nil
        }

        // 更新根节点并增加元素计数
        root = newNode
        numberOfElements += 1
        return nil
    }

    /// ⛔️ **STRUCTURAL**: 删除指定键及其对应的值。
    ///
    /// - 如果键存在，则删除并返回被删除的值。
    /// - 如果键不存在，则返回 `nil`。
    @discardableResult
    func remove(key: Key) -> Value? {
        guard let rootNode = splay(key: key), rootNode.key == key else { return nil }
        if rootNode.left == nil {
            root = rootNode.right
        } else if rootNode.right == nil {
            root = rootNode.left
        } else {
            var maxNode = rootNode.left.unsafelyUnwrapped
            var parentOfMaxNode: Node?

            /// 找到左树的最大子节点和其父节点
            while let child = maxNode.right {
                parentOfMaxNode = maxNode
                maxNode = child
            }
            /// 如果存在父节点，即左树的最大值节点不是左树的根节点
            if let parent = parentOfMaxNode {
                parent.right = maxNode.left
                maxNode.left = rootNode.left
            }
            /// 左子树的最大值节点的 right 必定为 nil
            maxNode.right = rootNode.right
            root = maxNode
        }

        numberOfElements -= 1
        return rootNode.value
    }

    /// ⛔️ **STRUCTURAL**: 清空树，删除所有元素。
    func clear() {
        root = nil
        numberOfElements = 0
    }

    /// ⛔️ **STRUCTURAL**: 键值下标访问器
    ///
    /// - Get: ⛔️ **STRUCTURAL**: 可能会修改树结构（执行 `search` 操作）。
    /// - Set: ⛔️ **STRUCTURAL**: 可能会修改树结构（执行 `upsert` 或 `remove` 操作）。
    subscript(key: Key) -> Value? {
        get { search(key: key) }

        set {
            if let newValue {
                upsert(key: key, value: newValue)
            } else {
                remove(key: key)
            }
        }
    }
}

// MARK: - 查询操作

/// ⛔️ **STRUCTURAL**
public extension SplayTree {
    /// ⛔️ **STRUCTURAL**: 检查集合是否包含给定键
    func contains(key: Key) -> Bool {
        guard let root = splay(key: key) else { return false }
        return root.key == key
    }

    /// ⛔️ **STRUCTURAL**: 返回小于等于指定键的最大元素
    ///
    /// - 如果存在，则返回满足条件的最大元素；否则返回 `nil`。
    func floor(key: Key) -> Element? {
        guard let root = splay(key: key) else { return nil }
        /// 如果 root 的 key 大于 目标，那么 floor 值就在其左树的最大值上。
        if root.key > key {
            var current = root.left
            while let node = current?.right {
                current = node
            }
            return current.map({($0.key, $0.value)})
        } else {
            return (root.key, root.value)
        }
    }

    /// ⛔️ **STRUCTURAL**: 返回大于等于指定键的最小元素
    ///
    /// - 如果存在，则返回满足条件的最小元素；否则返回 `nil`。
    func ceiling(key: Key) -> Element? {
        guard let root = splay(key: key) else { return nil }
        if root.key < key {
            var current = root.right
            while let node = current?.left {
                current = node
            }
            return current.map({($0.key, $0.value)})
        } else {
            return (root.key, root.value)
        }
    }

    /// ⛔️ **STRUCTURAL**: 返回小于 `key` 的最大元素。
    ///
    /// - 如果存在，则返回满足条件的最大元素；否则返回 `nil`。
    func predecessor(key: Key) -> Element? {
        guard let root = splay(key: key) else { return nil }
        if root.key >= key {
            var current = root.left
            while let node = current?.right {
                current = node
            }
            return current.map({($0.key, $0.value)})
        } else {
            return (root.key, root.value)
        }
    }

    /// ⛔️ **STRUCTURAL**: 返回大于 `key` 的最小元素。
    ///
    /// - 如果存在，则返回满足条件的最小元素；否则返回 `nil`。
    func successor(key: Key) -> Element? {
        guard let root = splay(key: key) else { return nil }
        /// 如果 root 小于目标，那么其后继便在 root 的右树最左边
        if root.key <= key {
            var current = root.right
            while let node = current?.left {
                current = node
            }
            return current.map({($0.key, $0.value)})
        } else {
            return (root.key, root.value)
        }
    }

    /// ⛔️ **STRUCTURAL**: 返回指定范围内的所有元素
    ///
    /// - 查询指定闭区间 `[range.lowerBound, range.upperBound]` 内的所有元素。
    /// - 时间复杂度：O(log N + K)，其中 N 是树中节点总数，K 是范围内节点的数量。
    /// - 实现细节：
    ///   1. 对 `range.lowerBound` 进行 Splay 操作，将最接近 `range.lowerBound` 的节点旋转到根位置。
    ///      - 如果 `range.lowerBound` 存在于树中，则它将成为根节点。
    ///      - 如果 `range.lowerBound` 不存在，则根节点将是小于 `range.lowerBound` 的最大值或大于 `range.lowerBound` 的最小值。
    ///   2. 从根节点的右子树开始中序遍历，收集键值在 `[range.lowerBound, range.upperBound]` 范围内的节点。
    ///      - 遍历过程中，如果遇到键值大于 `range.upperBound` 的节点，则提前终止遍历。
    ///   3. 如果根节点的键值满足范围条件，也会被包含在结果中。
    ///
    /// - 边界情况：
    ///   - 如果树为空，直接返回空数组。
    ///   - 如果范围内没有符合条件的节点，返回空数组。
    ///
    /// - 注意事项：
    ///   - 该方法会修改树结构（执行 Splay 操作）。
    func range(in range: ClosedRange<Key>) -> [Element] {
        guard let root = splay(key: range.lowerBound) else { return [] }

        var stack: [Node] = []
        var result: [Element] = []

        if root.key >= range.lowerBound && root.key <= range.upperBound {
            result.append((root.key, root.value))
        }

        /// 从根节点的右子树开始中序遍历
        var current: Node? = root.right
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()

                // 如果当前节点的键值超出范围上限，停止遍历
                if node.key > range.upperBound {
                    break
                }
                result.append((node.key, node.value))
                current = node.right
            }
        }

        return result
    }
}

// MARK: - 高级操作

/// ⛔️ **STRUCTURAL**
public extension SplayTree {
    /// ⛔️ **STRUCTURAL**: 将另一棵树合并到当前树中。
    ///
    /// - 当前树被视为左树，另一棵树被视为右树。
    /// - 合并的前提条件是左树的最大值必须小于右树的最小值。
    /// - 合并后，`rightTree` 将被清空，不能再使用。
    /// - 如果两棵树的数据不符合合并条件，则返回 `false`。
    func join(with rightTree: SplayTree) -> Bool {
        guard let rRoot = rightTree.root else {
            return true
        }
        guard let lRoot = root else {
            root = rRoot
            numberOfElements += rightTree.numberOfElements
            rightTree.clear()
            return true
        }

        /// 找到左树的最大子节点
        var maxNode = lRoot
        while let child = maxNode.right {
            maxNode = child
        }

        /// 找到右树的最小子节点
        var minNode = rRoot
        while let child = minNode.left {
            minNode = child
        }
        /// 数据存在交集不可合并
        if maxNode.key >= minNode.key {
            return false
        }
        let newLRoot = splay(key: maxNode.key).unsafelyUnwrapped
        /// 右树都是大于左树的，所以不需要 splay
        newLRoot.right = rightTree.root

        /// 更新计数
        numberOfElements += rightTree.numberOfElements

        /// 清空右树以避免引用问题
        rightTree.clear()
        return true
    }

    /// ⛔️ **STRUCTURAL**: 将当前树按给定键值分裂为两棵子树。
    ///
    /// - 左子树包含所有小于键值的节点，右子树包含所有大于或等于键值的节点。
    /// - 分裂后，原树将被清空。
    /// - 如果树为空，返回两颗新的空树。
    /// - 如果键值小于树中的最小值，则左子树为空，右子树为整棵树。
    /// - 如果键值大于树中的最大值，则右子树为空，左子树为整棵树。
    ///
    /// - 时间复杂度：O(log N + N)，因为需要维护 numberOfElements 属性所以需要额外的 N 时间。
    func split(at key: Key) -> (SplayTree, SplayTree) {
        guard let rootNode = splay(key: key) else { return (SplayTree(), SplayTree()) }

        let leftSubtree: SplayTree<Key, Value>
        let rightSubtree: SplayTree<Key, Value>

        if rootNode.key < key {
            /// 如果根节点小于 key，则右子树为根节点的右子树，左子树为根节点及其左子树
            rightSubtree = SplayTree<Key, Value>(root: rootNode.right)
            rootNode.right = nil
            leftSubtree = SplayTree<Key, Value>(root: rootNode)
        } else {
            /// 如果根节点大于或等于 key，则左子树为根节点的左子树，右子树为根节点及其右子树
            leftSubtree = SplayTree<Key, Value>(root: rootNode.left)
            rootNode.left = nil
            rightSubtree = SplayTree<Key, Value>(root: rootNode)
        }

        /// 清空当前树以避免引用问题
        root = nil
        numberOfElements = 0

        /// 维护 numberOfElements 属性
        leftSubtree.numberOfElements = leftSubtree.reduce(0) { i, _ in i + 1 }
        rightSubtree.numberOfElements = rightSubtree.reduce(0) { i, _ in i + 1 }
        return (leftSubtree, rightSubtree)
    }
}

// MARK: - 遍历和导出

/// ✅ **READ-ONLY**
public extension SplayTree {
    /// ✅ **READ-ONLY**: 深度克隆整棵树。
    func clone() -> SplayTree {
        guard let root = root else { return SplayTree() }

        var newRoot: Node?
        let newTree = SplayTree()
        var nodeStack: [(Node, Node?)] = [(root, nil)]

        while let (oldNode, parent) = nodeStack.popLast() {
            let newNode = Node(key: oldNode.key, value: oldNode.value)
            if let parent = parent {
                if oldNode.key < parent.key {
                    parent.left = newNode
                } else {
                    parent.right = newNode
                }
            } else {
                newRoot = newNode
            }
            if let left = oldNode.left { nodeStack.append((left, newNode)) }
            if let right = oldNode.right { nodeStack.append((right, newNode)) }
        }

        newTree.root = newRoot
        newTree.numberOfElements = numberOfElements
        return newTree
    }

    /// ✅ **READ-ONLY**: 以升序遍历所有元素。
    func traverse(_ body: (Element) throws -> Void) rethrows {
        var stack: [Node] = []
        var current: Node? = root
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()
                try body((node.key, node.value))
                current = node.right
            }
        }
    }

    /// ✅ **READ-ONLY**: 以降序遍历所有元素。
    func reversedTraverse(_ body: (Element) throws -> Void) rethrows {
        var stack: [Node] = []
        var current: Node? = root
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.right
            } else {
                let node = stack.removeLast()
                try body((node.key, node.value))
                current = node.left
            }
        }
    }

    /// ✅ **READ-ONLY**: 对集合中的每个元素应用转换函数，返回转换后的数组。
    func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        var stack: [Node] = []
        var current: Node? = root
        result.reserveCapacity(numberOfElements)
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()
                try result.append(transform((node.key, node.value)))
                current = node.right
            }
        }
        return result
    }

    /// 对集合中的每个元素应用转换函数，返回转换后的数组，如果转换函数返回 nil，则不包含该元素
    func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T] {
        var result: [T] = []
        var stack: [Node] = []
        var current: Node? = root
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()
                if let transformed = try transform((node.key, node.value)) {
                    result.append(transformed)
                }
                current = node.right
            }
        }
        return result
    }

    /// ✅ **READ-ONLY**: 对集合的所有元素进行归约计算（reduce）。
    ///
    /// - Parameters:
    ///   - initialResult: 归约的初始值。
    ///   - nextPartialResult: 计算下一个累积值的闭包 `(累积值, 当前元素) -> 新的累积值`。
    /// - Returns: 计算后的最终结果。
    func reduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) throws -> T) rethrows -> T {
        var result: T = initialResult
        var stack: [Node] = []
        var current: Node? = root
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()
                result = try nextPartialResult(result, (node.key, node.value))
                current = node.right
            }
        }
        return result
    }

    /// ✅ **READ-ONLY**: 对集合中的元素执行归约操作，并通过 `inout` 参数直接修改初始累加值。
    ///
    /// - Parameters:
    ///   - initialResult: 一个可变引用的初始累加值 (`inout T`)，该值会在归约过程中被直接修改。
    ///   - nextPartialResult: 计算下一个累积值的闭包 `(当前累加值的可变引用 (`inout T`), 当前元素) -> Void`。
    func reduce<T>(into initialResult: T, _ updateAccumulatingResult: (inout T, Element) throws -> Void) rethrows -> T {
        var stack: [Node] = []
        var current: Node? = root
        var result = initialResult
        while !stack.isEmpty || current != nil {
            if let node = current {
                stack.append(node)
                current = node.left
            } else {
                let node = stack.removeLast()
                try updateAccumulatingResult(&result, (node.key, node.value))
                current = node.right
            }
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension SplayTree: CustomStringConvertible {
    public var description: String {
        """
        SplayTree:
        - Number of elements: \(numberOfElements)
        - Root key: \(root == nil ? "nil" : "\(root!.key)")
        """
    }
}

// MARK: - OrderedCollection

extension SplayTree: OrderedCollection {}

// MARK: - Sequence+Iterator

public struct SplayTreeSequence<Key: Comparable, Value>: Sequence {
    let tree: SplayTree<Key, Value>

    init(_ tree: SplayTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> SplayTreeIterator<Key, Value> {
        return SplayTreeIterator(tree)
    }
}

public struct SplayTreeIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = (Key, Value)

    private var stack: [SplayTree<Key, Value>.Node] = []

    init(_ tree: SplayTree<Key, Value>) {
        var current = tree.root
        while let node = current {
            stack.append(node)
            current = node.left
        }
    }

    public mutating func next() -> Element? {
        while let node = stack.popLast() {
            var current: SplayTree<Key, Value>.Node? = node.right
            while let nextNode = current {
                stack.append(nextNode)
                current = nextNode.left
            }
            return (node.key, node.value)
        }
        return nil
    }
}

public struct SplayTreeReversedSequence<Key: Comparable, Value>: Sequence {
    let tree: SplayTree<Key, Value>

    init(_ tree: SplayTree<Key, Value>) {
        self.tree = tree
    }

    public func makeIterator() -> SplayTreeReversedIterator<Key, Value> {
        return SplayTreeReversedIterator(tree)
    }
}

public struct SplayTreeReversedIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = (Key, Value)

    private var stack: [SplayTree<Key, Value>.Node] = []

    init(_ tree: SplayTree<Key, Value>) {
        var current = tree.root
        while let node = current {
            stack.append(node)
            current = node.right
        }
    }

    public mutating func next() -> Element? {
        while let node = stack.popLast() {
            var current: SplayTree<Key, Value>.Node? = node.left
            while let nextNode = current {
                stack.append(nextNode)
                current = nextNode.right
            }
            return (node.key, node.value)
        }
        return nil
    }
}

// MARK: - 调试方法-仅在 DEBUG 模式下有效

#if DEBUG
import TreePrinter

extension SplayTreeNode: PrintableBinaryTreeProtocol {
    public var lNode: SplayTreeNode<Key, Value>? { left }
    public var rNode: SplayTreeNode<Key, Value>? { right }
    public var displayName: String {
        "\(key)"
    }
}

extension SplayTree: CustomDebugStringConvertible {
    public var debugDescription: String {
        guard let root else { return "" }
        return BinaryTreePrinter(root).print()
    }
}

#endif
