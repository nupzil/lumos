//
//  Created by vvgvjks on 2025/1/16.
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

/// SkipList
///
/// SkipList（跳表）是一种概率性数据结构，它通过在多个层级上维护链表来实现快速查找、插入和删除操作。
/// 每一层都是一个有序的链表，且高层链表中的节点是低层链表中节点的子集。这种结构允许跳过一些节点，从而加快搜索速度。
///
/// SkipList 的空间复杂度为 O(n log n)，基本操作的时间复杂度一般为 O(log n)。
///
/// 此结构不适用于多线程环境。
///
/// 需要使用到迭代器的话需要通过 elementsSequence 获取 Sequence。
///
/// 跳表的随机概率决定了跳表的性能，概率越小，跳表的层级越高，性能越差，但是插入和删除的性能越好。
///
/// 跳表的空间占用：不考虑内存对齐，每个 Node 占用
/// - MemoryLayout<Key>.size
/// - MemoryLayout<Value>.size
/// - MemoryLayout<UnsafeMutablePointer<Node>>.size
/// 上面几个是固定的内存占用。
///
/// 跳表可以看成是一个二维的矩阵，矩阵的行数是 maxLevel，矩阵的列数是 numberOfElements。
/// 跳表的节点在插入时就确认了其在矩阵的高度，所以理论上每个 Node 需要维护 level 个指针，这个 level 最大是 maxLevel。
///
/// 但是跳表的列是使用数组来维护的，所以每个 Node 需要维护 level 个指针。因为数组是连续的内存，所以是维持跳表结构的指针占用：
///
/// MemoryLayout<UnsafeMutablePointer<Node>>.size * level  * numberOfElements
///
/// 因为数组的原因，跳表的指针占用的内存会比想象中大很多。
public class SkipList<Key: Comparable, Value> {
    public typealias Element = (Key, Value)
    fileprivate typealias Node = SkipListNode<Key, Value>

    /// 跳表的最大层级。
    private let maxLevel: Int
    /// 跳表的随机概率。
    private let probability: Double
    /// 跳表的头节点。
    fileprivate var head: Node
    /// 跳表的尾节点。
    /// 增加 tail 指针以便支持高效的倒序遍历和 max 属性。
    fileprivate var tail: Node?
    /// 跳表的当前最大层级。
    private var currentMaxLevel: Int = 1
    /// 跳表中元素的数量。
    private var numberOfElements: Int = 0

    /// 初始化跳表。
    ///
    /// - Parameters:
    ///   - probability: 跳表的随机概率。
    ///   - maxLevel: 跳表的最大层级。
    public init(probability: Double = 0.5, maxLevel: Int = 32) {
        precondition(maxLevel > 0, "Max level must be greater than 0")
        precondition(maxLevel <= 128, "Max level must be less than or equal to 128")
        precondition(probability >= 0.0 && probability <= 1.0, "Probability must be between 0 and 1")

        self.maxLevel = maxLevel
        self.probability = probability
        self.head = .init(element: nil, prev: nil, level: maxLevel)
    }

    public required init() {
        self.maxLevel = 32
        self.probability = 0.5
        self.head = .init(element: nil, prev: nil, level: maxLevel)
    }
}

/// 跳表的节点。
private final class SkipListNode<Key: Comparable, Value> {
    /// head 节点是不存在 element 的，但是其他的 Node 都是必定存在 element 的。
    /// 如何避免使用 ? 呢？
    var element: (Key, Value)?
    /// 增加一个指针以便支持高效的倒序遍历。
    var prev: SkipListNode<Key, Value>?
    /// 跳表的列，每一个元素都指向下一个节点，下个节点可能在不同的列不同的行。
    var nexts: [SkipListNode<Key, Value>?]

    init(element: (Key, Value)?, prev: SkipListNode<Key, Value>?, level: Int) {
        self.prev = prev
        self.element = element
        self.nexts = Array(repeating: nil, count: level)
    }
}

// MARK: - 计算属性

public extension SkipList {
    /// 返回跳表中元素的数量。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    var count: Int { numberOfElements }

    /// 返回跳表是否为空。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    var isEmpty: Bool { numberOfElements == 0 }

    /// 返回跳表的当前最大层级。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    var height: Int { currentMaxLevel }

    /// 返回跳表中的最小值。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    var min: Element? { head.nexts[0]?.element }

    /// 返回跳表中的最大值。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    var max: Element? { tail?.element }

    /// 返回跳表中的所有键。
    ///
    /// - 复杂度: 时间复杂度 O(n)，n 是跳表中元素的数量。
    var keys: [Key] {
        guard numberOfElements > 0 else { return [] }
        return [Key](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = head
            while let next = current.nexts[0] {
                buffer[initializedCount] = next.element.unsafelyUnwrapped.0
                initializedCount += 1
                current = next
            }
        }
    }

    /// 返回跳表中的所有值。
    ///
    /// - 复杂度: 时间复杂度 O(n)，n 是跳表中元素的数量。
    var values: [Value] {
        guard numberOfElements > 0 else { return [] }
        return [Value](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = head
            while let next = current.nexts[0] {
                buffer[initializedCount] = next.element.unsafelyUnwrapped.1
                initializedCount += 1
                current = next
            }
        }
    }

    /// 返回跳表中的所有元素。
    ///
    /// - 复杂度: 时间复杂度 O(n)，n 是跳表中元素的数量。
    var elements: [Element] {
        guard numberOfElements > 0 else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node = head
            while let next = current.nexts[0] {
                buffer[initializedCount] = next.element.unsafelyUnwrapped
                initializedCount += 1
                current = next
            }
        }
    }

    /// 返回跳表中的所有元素。
    ///
    /// - 复杂度: 时间复杂度 O(n)，n 是跳表中元素的数量。
    var reversed: [Element] {
        guard numberOfElements > 0 else { return [] }
        return [Element](unsafeUninitializedCapacity: numberOfElements) { buffer, initializedCount in
            var current: Node? = tail
            while let node = current, node !== head {
                buffer[initializedCount] = node.element.unsafelyUnwrapped
                initializedCount += 1
                current = node.prev
            }
        }
    }

    /// 返回一个基于 SkipList 的 Sequence 结构。
    /// 返回的 Sequence 是持有 SkipList 的引用，所以遍历的元素是共享的，当 SkipList 修改时，Sequence 也会随之修改。
    ///
    /// 这个 Sequence 的遍历是 O(n) 的复杂度。
    var elementsSequence: SkipListSequence<Key, Value> {
        SkipListSequence(self)
    }

    /// 返回一个基于 SkipList 的 Sequence 结构。
    /// 返回的 Sequence 是持有 SkipList 的引用，所以遍历的元素是共享的，当 SkipList 修改时，Sequence 也会随之修改。
    ///
    /// 这个 Sequence 的遍历是 O(n) 的复杂度。
    var reversedSequence: SkipListReversedSequence<Key, Value> {
        SkipListReversedSequence(self)
    }
}

// MARK: - 私有方法

extension SkipList {
    /// 确认新元素的层高，它可能会一次增加好几层。
    ///
    /// - Returns: 返回新元素的层高。
    private func randomLevel() -> Int {
        var level = 1
        while Double.random(in: 0 ..< 1) < probability && level < maxLevel {
            level += 1
        }
        return level
    }

    /// 找到目标元素的每一层的前驱
    ///
    /// - Returns: 返回一个包含每一层的前驱节点的数组。
    @inline(__always)
    private func collectLevelPredecessors(key: Key) -> [Node] {
        var current = head
        /// 记录每一层的前驱
        /// 这里使用 head 填充因为后续的 for 循环会覆盖的，填充可以避免解包
        /// 因为使用的是 maxLevel 作为 count 的，填充 nil 或者 head 内存上没有区别。
        /// 最多多 maxLevel - currentMaxLevel 个指针的内存，影响非常小。
        var prevs: [Node] = Array(repeating: head, count: maxLevel)
        /// 找到插入位置
        var i = currentMaxLevel - 1
        while i >= 0 {
            while i < current.nexts.count, let next = current.nexts[i], next.element.unsafelyUnwrapped.0 < key {
                current = next
            }
            prevs[i] = current
            i -= 1
        }
        return prevs
    }

    @inline(__always)
    private func findPredecessor(key: Key) -> Node {
        var prev = head
        var current = head
        var i = currentMaxLevel - 1
        while i >= 0 {
            while i < current.nexts.count, let next = current.nexts[i], next.element.unsafelyUnwrapped.0 < key {
                current = next
            }
            prev = current
            i -= 1
        }
        return prev
    }
}

// MARK: - 核心增删改查

public extension SkipList {
    /// 查询指定 `Key` 的值。
    ///
    /// - Returns: 如果 `Key` 存在返回对应的 `Value`，否则返回 nil。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func search(key: Key) -> Value? {
        /// 找到插入位置
        /// 从最上层开始往右走，如果右边没有下一个指针或者其 Key 比目标值大就往下一层走，重复这个过程直到到达最下层。
        let prev = findPredecessor(key: key)
        guard let element = prev.nexts[0]?.element, element.0 == key else { return nil }
        return element.1
    }

    /// 向跳表中插入元素。
    ///
    /// - Returns: 如果插入成功返回 true，如果 Key 已存在则返回 false。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    @discardableResult
    func insert(key: Key, value: Value) -> Bool {
        /// 找到每一层的前驱节点
        let prevs: [Node] = collectLevelPredecessors(key: key)
        /// 检查元素是否已存在
        if let node = prevs[0].nexts[0], node.element!.0 == key {
            return false
        }
        // 确定新节点的层
        let level = randomLevel()
        // 是否新增了层
        if level > currentMaxLevel {
            currentMaxLevel = level
        }
        // 插入节点
        let node = Node(element: (key, value), prev: prevs[0], level: level)

        for i in 0 ..< level {
            node.nexts[i] = prevs[i].nexts[i]
            prevs[i].nexts[i] = node
        }
        // 维护 prev 指针
        node.nexts[0]?.prev = node
        // 维护 tail 指针
        // 小于等于是处理初始 tail 为空的场景，跳表不允许存在相同的 key
        if (tail?.element?.0 ?? key) <= key {
            tail = node
        }
        numberOfElements += 1
        return true
    }

    /// 更新指定元素的值。
    ///
    /// - Returns: 如果 Key 不存在返回 nil 否则返回旧值。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    @discardableResult
    func update(key: Key, value: Value) -> Value? {
        let prev = findPredecessor(key: key)
        guard let node = prev.nexts[0], node.element!.0 == key else { return nil }
        let oldValue = node.element!.1
        node.element = (key, value)
        return oldValue
    }

    /// 插入或更新指定元素的值。
    ///
    /// - Returns: 返回 nil 表示插入，返回旧值表示更新。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    @discardableResult
    func upsert(key: Key, value: Value) -> Value? {
        /// 找到每一层的前驱节点
        let prevs: [Node] = collectLevelPredecessors(key: key)
        /// 检查元素是否已存在
        if let node = prevs[0].nexts[0], node.element!.0 == key {
            let oldValue = node.element!.1
            node.element = (key, value)
            return oldValue
        }
        // 确定新节点的层
        let level = randomLevel()
        // 是否新增了层
        if level > currentMaxLevel {
            currentMaxLevel = level
        }
        // 插入节点
        let node = Node(element: (key, value), prev: prevs[0], level: level)
        for i in 0 ..< level {
            node.nexts[i] = prevs[i].nexts[i]
            prevs[i].nexts[i] = node
        }
        // 维护 prev 指针
        node.nexts[0]?.prev = node
        // 维护 tail 指针
        if (tail?.element?.0 ?? key) <= key {
            tail = node
        }
        numberOfElements += 1
        return nil
    }

    /// 删除指定元素。
    ///
    /// - Returns: 如果 Key 不存在返回 nil, 存在则返回旧值。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    @discardableResult
    func remove(key: Key) -> Value? {
        let prevs: [Node] = collectLevelPredecessors(key: key)
        let current = prevs[0].nexts[0] ?? head
        /// 是否存在
        guard let element = current.element, element.0 == key else {
            return nil
        }
        /// 修改当前节点在 prevs 出现过的层指针
       
        /// 修改位于上层的指针
        for i in 0 ..< current.nexts.endIndex {
            prevs[i].nexts[i] = current.nexts[i]
        }
        /// 检查层高是否有降低
        while currentMaxLevel > 1, head.nexts[currentMaxLevel - 1] == nil {
            currentMaxLevel -= 1
        }
        // 维护底层 prev 指针
        current.nexts[0]?.prev = current.prev
        // 维护 tail 指针
        if (tail?.element?.0 ?? key) == key {
            tail = (current.prev !== head) ? current.prev : nil
        }
        numberOfElements -= 1
        return element.1
    }

    /// 删除所有的元素。
    ///
    /// - 复杂度: 时间复杂度 O(1)。
    func clear() {
        tail = nil
        currentMaxLevel = 1
        numberOfElements = 0
        head = .init(element: nil, prev: nil, level: maxLevel)
    }

    /// 支持下标访问。
    ///
    /// - Get: 返回指定键的值，如果键不存在返回 nil，等同于 `search` 方法。
    /// - Set:
    ///   - 如果值为 nil，删除指定键的元素，等同于 `remove` 方法。
    ///   - 如果值不为 nil，更新指定键的值, 等同于 `upsert` 方法。
    ///   - 如果键不存在，插入指定键的元素，等同于 `insert` 方法。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    subscript(key: Key) -> Value? {
        get {
            search(key: key)
        }
        set {
            if let newValue {
                upsert(key: key, value: newValue)
            } else {
                remove(key: key)
            }
        }
    }
}

// MARK: - 查找操作

public extension SkipList {
    /// 检查跳表中是否存在指定的 `Key`。
    ///
    /// - Returns: 如果 `Key` 存在返回 true，否则返回 false。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func contains(key: Key) -> Bool {
        search(key: key) != nil
    }

    /// 获取小于等于指定键的元素。
    ///
    /// - 如果存在相等的元素，返回相等的元素。
    /// - 如果跳表是空的，返回 nil。
    /// - 如果指定键小于跳表中的所有元素，返回 nil。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func floor(key: Key) -> Element? {
        var current = findPredecessor(key: key)
        if let node = current.nexts[0], node.element!.0 == key {
            current = node
        }
        return current.element
    }

    /// 获取大于等于指定键的元素。
    ///
    /// - 如果存在相等的元素，返回相等的元素。
    /// - 如果跳表是空的，返回 nil。
    /// - 如果指定键大于跳表中的所有元素，返回 nil。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func ceiling(key: Key) -> Element? {
        findPredecessor(key: key).nexts[0]?.element
    }

    /// 获取指定键的前驱元素。
    ///
    /// - 如果没有前驱元素（SkipList 只有一个元素，或者指定键小于跳表中的所有元素，或者 SkipList 为空），返回 nil。
    /// - 如果指定的键不存在，返回小于指定键的最大元素。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func predecessor(key: Key) -> Element? {
        findPredecessor(key: key).element
    }

    /// 获取指定键的后继元素。
    ///
    /// - 如果没有后继元素（SkipList 只有一个元素，或者指定键大于跳表中的所有元素，或者 SkipList 为空），返回 nil。
    /// - 如果指定的键不存在，返回大于指定键的最小元素。
    ///
    /// - 复杂度: 时间复杂度 O(log n)，n 是跳表中元素的数量。
    func successor(key: Key) -> Element? {
        let prev = findPredecessor(key: key)
        guard let node = prev.nexts[0] else { return nil }
        let current = node.element!.0 != key ? node : node.nexts[0]
        return current?.element
    }

    /// 查询指定范围内的元素。
    ///
    /// - Argument: range 一个闭合范围 `ClosedRange<Key>` ，表示要查找的键的范围。
    /// - Returns: 返回一个包含所有在指定范围内的元素的数组。
    ///
    /// - 复杂度: 时间复杂度 O(log n + k)，n 是跳表中元素的数量，k 是范围内的元素数量。
    func range(in range: ClosedRange<Key>) -> [Element] {
        var result: [Element] = []
        var current: Node = findPredecessor(key: range.lowerBound)
        while let next = current.nexts[0], next.element!.0 <= range.upperBound {
            result.append(next.element!)
            current = next
        }
        return result
    }
}

// MARK: - 遍历操作

public extension SkipList {
    /// 遍历跳表中的所有元素。
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func traverse(_ body: (Element) throws -> Void) rethrows {
        var current: Node = head
        while let next = current.nexts[0] {
            try body(next.element.unsafelyUnwrapped)
            current = next
        }
    }

    /// 倒序遍历跳表中的所有元素。
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func reversedTraverse(_ body: (Element) throws -> Void) rethrows {
        var current: Node? = tail
        while let node = current, node !== head {
            try body(node.element.unsafelyUnwrapped)
            current = node.prev
        }
    }

    /// 对集合中的每个元素应用转换函数，返回转换后的数组
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func map<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        var current: Node = head
        while let next = current.nexts[0] {
            try result.append(transform(next.element.unsafelyUnwrapped))
            current = next
        }
        return result
    }

    /// 对集合中的每个元素应用转换函数，返回转换后的数组，如果转换函数返回 nil，则不包含该元素
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T] {
        var result: [T] = []
        var current: Node = head
        while let next = current.nexts[0] {
            if let transformed = try transform(next.element.unsafelyUnwrapped) {
                result.append(transformed)
            }
            current = next
        }
        return result
    }

    /// 对集合中的元素进行归约操作，返回一个单一的结果。
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func reduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) throws -> T) rethrows -> T {
        var result: T = initialResult
        var current: Node = head
        while let next = current.nexts[0] {
            result = try nextPartialResult(result, next.element.unsafelyUnwrapped)
            current = next
        }
        return result
    }

    /// 对集合中的元素进行归约操作，返回一个单一的结果。
    ///
    /// - 复杂度: 时间复杂度 O(n)，其中 n 是跳表中元素的数量。
    func reduce<T>(into initialResult: T, _ updateAccumulatingResult: (inout T, Element) throws -> Void) rethrows -> T {
        var result: T = initialResult
        var current: Node = head
        while let next = current.nexts[0] {
            try updateAccumulatingResult(&result, next.element.unsafelyUnwrapped)
            current = next
        }
        return result
    }
}

// MARK: - CustomStringConvertible

extension SkipList: CustomStringConvertible {
    private func trim(_ rawString: String) -> String {
        rawString
            .replacingOccurrences(of: "Optional(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }

    /// 返回跳表的描述信息。
    ///
    /// 时间复杂度：O(1)
    public var description: String {
        return """
        SkipList:
        - Number of elements: \(numberOfElements)
        - Maximum level: \(maxLevel) (p = \(String(format: "%.2f", probability)))
        - Current level: \(currentMaxLevel)
        - Head next key: \(trim(String(describing: head.nexts[0]?.element?.0)))
        - Tail key: \(trim(String(describing: tail?.element?.0)))
        """
    }
}

// MARK: - OrderedCollection

extension SkipList: OrderedCollection {}

// MARK: - Sequence+Iterator

public struct SkipListSequence<Key: Comparable, Value>: Sequence {
    private let skipList: SkipList<Key, Value>

    fileprivate init(_ skipList: SkipList<Key, Value>) {
        self.skipList = skipList
    }

    public func makeIterator() -> SkipListIterator<Key, Value> {
        SkipListIterator(head: skipList.head.nexts[0])
    }
}

public class SkipListIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = (Key, Value)
    private var current: SkipListNode<Key, Value>?

    fileprivate init(head: SkipListNode<Key, Value>?) {
        self.current = head
    }

    public func next() -> Element? {
        guard let node = current else { return nil }
        let value = node.element
        current = node.nexts[0]
        return value
    }
}

public struct SkipListReversedSequence<Key: Comparable, Value>: Sequence {
    private let skipList: SkipList<Key, Value>

    fileprivate init(_ skipList: SkipList<Key, Value>) {
        self.skipList = skipList
    }

    public func makeIterator() -> SkipListReversedIterator<Key, Value> {
        SkipListReversedIterator(tail: skipList.tail)
    }
}

public class SkipListReversedIterator<Key: Comparable, Value>: IteratorProtocol {
    public typealias Element = (Key, Value)
    private var current: SkipListNode<Key, Value>?

    fileprivate init(tail: SkipListNode<Key, Value>?) {
        self.current = tail
    }

    public func next() -> Element? {
        guard let node = current else { return nil }
        let value = node.element
        current = node.prev
        return value
    }
}

// MARK: - 调试方法-仅在 DEBUG 模式下有效

#if DEBUG
import Foundation

extension SkipList: CustomDebugStringConvertible {
    /// 返回跳表的调试信息。
    ///
    /// - 它是一个字符串，它描述了跳表的矩阵结构。
    ///
    /// SkipList
    /// Keys    | nil |  1  |  2  |  3  |  4  |  5  |  6
    /// -------------------------------------------------
    /// Level 5 |  4  |  -  |  -  |  -  | nil |  -  | nil
    /// Level 4 |  2  |  -  |  4  |  -  | nil |  -  | nil
    /// Level 3 |  2  |  -  |  4  |  -  |  5  | nil | nil
    /// Level 2 |  1  |  2  |  4  |  -  |  5  | nil | nil
    /// Level 1 |  1  |  2  |  3  |  4  |  5  |  6  | nil
    public var debugDescription: String {
        guard numberOfElements > 0 else { return "" }

        let matrix = alignMatrix(self.matrix)
        let maxLength = matrix[0][0].count
        let digit = digitCount(matrix.count)

        var result: [String] = []
        result.reserveCapacity(matrix.count + 2)

        for index in 0 ..< (matrix.count - 1) {
            let first = "Level \(String(repeating: "0", count: digit - String(index + 1).count))\(String(index + 1))"
            result.append(first + " | " + matrix[index].joined(separator: " | ") + " | " + alignString("nil", chart: " ", count: maxLength))
        }

        var current: Node? = head
        var keys = ["Keys" + String(repeating: " ", count: 6 + digit - 4)]
        keys.reserveCapacity(numberOfElements + 1)
        while let node = current {
            keys.append(alignString(node.element == nil ? "nil" : "\(node.element!.0)", chart: " ", count: maxLength))
            current = node.nexts.first ?? nil
        }
        result.append(String(repeating: "-", count: (maxLength + 3) * (numberOfElements + 1) + 6 + digit))
        result.append(keys.joined(separator: " | "))

        return "SkipList\n" + result.reversed().joined(separator: "\n") + "\n"
    }

    
    /// 返回 SkipList 的矩阵字符串
    public var matrixString: [[String]] {
        Array(self.matrix.dropLast().reversed())
    }

    /// 返回跳表的矩阵结构。
    private var matrix: [[String]] {
        let row: [String] = Array(repeating: "", count: count)
        var result: [[String]] = Array(repeating: row, count: currentMaxLevel + 1)

        var index = 0
        var prev = head
        var current: Node = head

        // 遍历最下层，亦就是底层有序完整的链表。
        while let next = current.nexts.first ?? nil {
            current = next
            // 遍历列-从上往下
            for level in 0 ..< currentMaxLevel {
                var output = "nil"
                if level >= prev.nexts.count {
                    output = "-"
                } else if let element = prev.nexts[level]?.element {
                    output = "\(element.0)"
                }
                result[level][index] = output
            }
            index += 1
            prev = current
        }

        return result
    }

    private func alignMatrix(_ matrix: [[String]]) -> [[String]]{
        let maxLength = matrix.flatMap { $0 }.map { $0.count }.max() ?? 0
        var result: [[String]] = matrix
        for i in 0 ..< matrix.count {
            for j in 0 ..< matrix[i].count {
                result[i][j] = alignString(matrix[i][j], chart: " ", count: maxLength)
            }
        }
        return result
    }

    private func alignString(_ input: String, chart: String, count: Int) -> String {
        guard input.count < count else { return input }
        let padding = count - input.count
        let leftPadding = padding / 2
        let rightPadding = padding - leftPadding
        return String(repeating: chart, count: leftPadding) + input + String(repeating: chart, count: rightPadding)
    }

    /// 返回一个数字的位数。
    private func digitCount(_ number: Int) -> Int {
        if number == 0 { return 1 }
        return Int(log10(Double(abs(number)))) + 1
    }
}
#endif
