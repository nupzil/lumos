//
//  Created by vvgvjks on 2025/1/21.
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

/// 有序集合协议（升序）
///
/// 本协议定义了一组有序（升序）的键值对集合，不允许同一键重复。
/// 底层实现可能采用 BTree、B+Tree、SkipList 等数据结构。
/// 由于底层结构特性，为了避免默认实现带来的性能开销，本协议不要求实现者继承 Sequence 或 Collection 协议。
///
/// 协议的所有方法都要求实现者保证基于其底层结构的高效操作。
public protocol OrderedCollection: CustomStringConvertible {
    associatedtype Key: Comparable
    associatedtype Value
    
    associatedtype ElementSequence: Sequence
    associatedtype ReversedSequence: Sequence

    typealias Element = (Key, Value)
    
    /// 支持无参数的默认构造方法
    init()
    
    // MARK: - 计算属性

    /// 集合中元素的数量
    var count: Int { get }
    
    /// 集合是否为空
    var isEmpty: Bool { get }
    
    /// 集合中最小的元素（升序排序下的第一个元素），若集合为空则返回 nil
    var min: Element? { get }
    
    /// 集合中最大的元素（升序排序下的最后一个元素），若集合为空则返回 nil
    var max: Element? { get }
    
    /// 集合中所有键的数组
    var keys: [Key] { get }
    
    /// 集合中所有值的数组  
    var values: [Value] { get }
    
    /// 返回按升序排列的所有元素数组
    var elements: [Element] { get }

    /// 返回一个实现了 Sequence 协议的序列，用于遍历所有元素
    var elementsSequence: ElementSequence { get }
    
    /// 返回按降序排列的所有元素数组
    var reversed: [Element] { get }

    /// 返回一个实现了 Sequence 协议的序列，用于降序遍历所有元素
    var reversedSequence: ReversedSequence { get }
    
    // MARK: - 核心方法
    
    /// 查找给定键对应的值，若存在则返回该值，否则返回 nil
    func search(key: Key) -> Value?
    
    /// 插入一个键值对
    ///
    /// - 如果键已存在，则不进行插入并返回 false
    /// - 如果插入成功，则返回 true
    @discardableResult
    func insert(key: Key, value: Value) -> Bool
    
    /// 更新已存在的键的值
    ///
    /// - 如果键不存在，则不进行更新并返回 nil
    /// - 如果更新成功，则返回旧值
    @discardableResult
    func update(key: Key, value: Value) -> Value?
    
    /// 插入或更新
    ///
    /// - 如果键存在，则更新其值并返回旧值
    /// - 如果键不存在，则插入该键值对并返回 nil
    @discardableResult
    func upsert(key: Key, value: Value) -> Value?
    
    /// 删除指定键对应的元素
    ///
    /// - 如果键不存在，则返回 nil
    /// - 如果删除成功，则返回被删除的值
    @discardableResult
    func remove(key: Key) -> Value?
    
    /// 清空集合中所有的元素
    func clear()

    /// 下标访问
    ///
    /// - 读取：返回给定键对应的值（若不存在则为 nil）等同于 search(key:)
    /// - 写入：
    ///   - 若 value != nil 则等同于 upsert(key:value:)
    ///   - 若 value == nil 则等同于 remove(key:)
    subscript(key: Key) -> Value? { get set }
    
    // MARK: - 查询操作
    
    /// 检查集合是否包含给定键
    func contains(key: Key) -> Bool



    /// 返回小于等于指定键的最大元素
    ///
    /// - Returns: 若存在，则返回满足条件的最大元素；否则返回 nil
    func floor(key: Key) -> Element?
    
    /// 返回大于等于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    func ceiling(key: Key) -> Element?
    
    /// 返回小于指定键的最大元素
    ///
    /// - Returns: 若存在，则返回满足条件的最大元素；否则返回 nil
    func predecessor(key: Key) -> Element?
    
    /// 返回大于指定键的最小元素
    ///
    /// - Returns: 若存在，则返回满足条件的最小元素；否则返回 nil
    func successor(key: Key) -> Element?

    /// 返回指定范围内的所有元素
    ///
    /// - Returns: 位于指定范围内的元素数组
    func range(in range: ClosedRange<Key>) -> [Element]

    // MARK: - 遍历操作
    /// 因为 OrderedCollection 的底层结构可能并不继承 Sequence 协议，所以这里需要提供一些实用的遍历方法。

    /// 以升序遍历所有元素
    /// forEach 会被格式化程序格式成 for in ，而本协议不要求实现者继承 Sequence 协议，所以此处不能使用 forEach 这个名字。
    func traverse(_ body: (Element) throws -> Void) rethrows -> Void
    
    /// 以降序遍历所有元素
    func reversedTraverse(_ body: (Element) throws -> Void) rethrows -> Void
    
    /// 对集合中的每个元素应用转换函数，返回转换后的数组
    func map<T>(_ transform: (Element) throws -> T) rethrows -> [T]
    
    /// 对集合中的每个元素应用转换函数，返回转换后的数组，如果转换函数返回 nil，则不包含该元素
    func compactMap<T>(_ transform: (Element) throws -> T?) rethrows -> [T]

    /// 对所有元素进行归约计算，并返回累加值
    func reduce<T>(_ initialResult: T, _ nextPartialResult: (T, Element) throws -> T) rethrows -> T

    /// 对集合中的元素执行归约操作，并通过 `inout` 参数直接修改初始累加值。
    func reduce<T>(into initialResult: T, _ updateAccumulatingResult: (inout T, Element) throws -> ()) rethrows -> T
}

// MARK: - 批量操作（语法糖，仅为简化调用，不提供额外性能优势）
extension OrderedCollection {
    /// 批量插入一组元素
    @discardableResult
    func insert(contentsOf elements: [Element]) -> [Bool] {
        var result: [Bool] = []
        for element in elements {
            result.append(self.insert(key: element.0, value: element.1))
        }
        return result
    }
    
    /// 批量更新一组元素
    @discardableResult
    func update(contentsOf elements: [Element]) -> [Value?] {
        var result: [Value?] = []
        for element in elements {
            result.append(self.update(key: element.0, value: element.1))
        }
        return result
    }
    
    /// 批量 upsert（插入或更新）一组元素
    @discardableResult
    func upsert(contentsOf elements: [Element]) -> [Value?] {
        var result: [Value?] = []
        for element in elements {
            result.append(self.upsert(key: element.0, value: element.1))
        }
        return result
    }

    /// 批量删除指定键对应的元素
    @discardableResult
    func remove(keys: [Key]) -> [Value?] {
        var result: [Value?] = []
        for key in keys {
            result.append(self.remove(key: key))
        }
        return result
    }
}
