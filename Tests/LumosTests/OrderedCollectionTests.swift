//
//  Created by vvgvjks on 2025/1/21.
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

import Testing
import Foundation
@testable import Lumos

protocol OrderedCollectionTests {
    associatedtype CollectionType: OrderedCollection
        where CollectionType.Key == Int,
        CollectionType.Value == Int,
        CollectionType.ElementSequence.Element == (Int, Int),
        CollectionType.ReversedSequence.Element == (Int, Int)

    /// 工厂方法，子类/实现者必须提供
    func factory() -> CollectionType
    /// 基本操作
    func TestBasicOperationsTests() async throws

    /// 插入和删除
    func TestInsertionAndDeletionTests() async throws

    /// 下标操作
    func TestSubscriptOperationsTests() async throws

    /// 遍历方法
    func TestTraversalTests() async throws

    /// floor、ceiling、predecessor、successor
    func TestFloorCeilingPredecessorSuccessorTests() async throws

    /// search、contains、range
    func TestSearchContainsRangeTests() async throws

    /// 随机操作测试
    func TestRandomOperations() async throws
}

// MARK: - 测试辅助方法

func == <T: Equatable>(lhs: (T, T)?, rhs: (T, T)?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case let ((l1, l2)?, (r1, r2)?):
        return l1 == r1 && l2 == r2
    default:
        return false
    }
}

func == <T: Equatable>(lhs: [(T, T)]?, rhs: [(T, T)]?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case let (l?, r?) where l.count == r.count:
        for (index, leftElement) in l.enumerated() {
            let rightElement = r[index]
            if leftElement.0 != rightElement.0 || leftElement.1 != rightElement.1 {
                return false
            }
        }
        return true
    default:
        return false
    }
}

/// 测试思路围绕状态来测试场景，最后单独测试方法的功能。
///
/// OrderedCollection 的核心就是有序和正确。
///
/// 状态由 checkIntegrity 方法具体测试，围绕着 checkIntegrity 方法来思考有哪些状态流转的场景。
///
/// 方法如果出现在场景中就顺便测试了，如果不存在于场景（只读方法）就单独进行测试。
extension OrderedCollectionTests {
    /// 构建集合
    private func buildCollection(_ keys: [Int]) -> CollectionType {
        let collection = factory()
        _ = collection.insert(contentsOf: keys.map { ($0, $0 * 10) })
        return collection
    }

    /// 检查集合的完整性
    func checkIntegrity(_ collection: CollectionType) {
        if collection.isEmpty {
            #expect(collection.min == nil)
            #expect(collection.max == nil)
            #expect(collection.count == 0)
            #expect(collection.elements == [])
        }

        let elements = collection.elements

        /// max min
        #expect(collection.max == elements.last)
        #expect(collection.min == elements.first)

        /// count isEmpty
        #expect(collection.count == elements.count)
        #expect(collection.isEmpty == elements.isEmpty)

        /// 状态一致性：keys、values、elements、reversed、elementsSequence、reversedSequence
        var result: [(Int, Int)] = []

        #expect(collection.keys == elements.map { $0.0 })
        #expect(collection.values == elements.map { $0.1 })
        #expect(collection.reversed == elements.reversed())
        #expect(Array(collection.elementsSequence) == elements)
        #expect(Array(collection.reversedSequence) == elements.reversed())

        /// 各种遍历方法的遍历顺序是否正确。
        /// map
        #expect(elements == collection.map { $0 })
        #expect(elements == collection.compactMap { $0 })

        /// traverse
        result.removeAll()
        collection.traverse { result.append($0) }
        #expect(elements == result)

        /// reversedTraverse
        result.removeAll()
        collection.reversedTraverse { result.append($0) }
        #expect(elements.reversed() == result)

        /// reduce
        #expect(elements == collection.reduce(into: []) { $0.append($1) })
        #expect(elements == collection.reduce([]) { array, element in
            var array1 = array
            array1.append(element)
            return array1
        })

        /// 有序性
        #expect(elements == elements.sorted(by: { $0.0 < $1.0 }))
        #expect(collection.reversed == elements.sorted(by: { $0.0 > $1.0 }))
    }
}

// MARK: - 与暴露的 Test 方法一一对应

extension OrderedCollectionTests {
    /// 大批量随机操作测试
    /// 一些问题可能需要再一定量级的数据才能体现
    func runTestRandomOperations() {
        let collection = factory()
        var referenceSet = Set<Int>()

        srand48(42)

        // 第一阶段：随机插入100个元素
        while referenceSet.count < 50 {
            let key = Int.random(in: 0..<1000)
            if referenceSet.insert(key).inserted {
                collection.insert(key: key, value: key * 10)
            }
        }
        
        // 内部结构是否仍然完整
        checkIntegrity(collection)
        // 是否插入成功
        #expect(collection.count == referenceSet.count)
        // 验证值是否还能与 key 一一对应
        #expect(collection.values == collection.keys.map({$0 * 10}))
        
        // 随机删除 10 个不存在的 key
        var count = 10
        while count > 0 {
            let key = Int.random(in: 0..<1000)
            if referenceSet.contains(key) {
                continue
            }
            count -= 1
            collection.remove(key: key)
            checkIntegrity(collection)
        }
        
        // 内部结构是否仍然完整
        checkIntegrity(collection)
        // 是否删除成功
        #expect(collection.count == referenceSet.count)
        // 验证值是否还能与 key 一一对应
        #expect(collection.values == collection.keys.map({$0 * 10}))

        // 随机删除 80 个元素
        let deleteCount = Int(0.8 * Double(referenceSet.count))
        for _ in 0..<deleteCount {
            let valueToDelete = referenceSet.randomElement()!
            
            referenceSet.remove(valueToDelete)
            collection.remove(key: valueToDelete)
        }

        // 内部结构是否仍然完整
        checkIntegrity(collection)
        // 是否删除成功
        #expect(collection.count == referenceSet.count)
        // 验证值是否还能与 key 一一对应
        #expect(collection.values == collection.keys.map({$0 * 10}))

        // 继续删除直至全部删除
        while referenceSet.count > 0 {
            let valueToDelete = referenceSet.randomElement()!
            referenceSet.remove(valueToDelete)
            collection.remove(key: valueToDelete)
        }
        // 内部结构是否仍然完整
        checkIntegrity(collection)
        // 是否已经删除完
        #expect(collection.count == 0)
        // 是否删除成功
        #expect(collection.count == referenceSet.count)
        // 验证值是否还能与 key 一一对应
        #expect(collection.values == collection.keys.map({$0 * 10}))
    }

    func runBasicOperationsTests() {
        runTestEmptyCollection()
        runTestClearCollection()
        runTestSingleElementCollection()
        runTestSequentialOperations()
        runTestNegativeAndZeroKeys()
    }

    func runInsertionAndDeletionTests() {
        runTestInsertSingleElement()
        runTestInsertMultipleElementsInOrder()
        runTestInsertMultipleElementsOutOfOrder()
        runTestInsertDuplicateKey()
        runTestUpdateExistingKey()
        runTestUpdateNonExistingKey()
        runTestUpsertNewKey()
        runTestUpsertExistingKey()
        runTestRemoveExistingKey()
        runTestRemoveNonExistingKey()
        runTestRemoveAllElements()
    }

    func runSubscriptOperationsTests() {
        runTestSubscriptGet()
        runTestSubscriptDeleteKey()
        runTestSubscriptSetNewKey()
        runTestSubscriptUpdateExistingKey()
        runTestSubscriptDeleteNonExistingKey()
        runTestSubscriptDeleteAllElements()
    }

    func runTraversalTests() {
        runTestCompactMapTransformation()
    }

    func runFloorCeilingPredecessorSuccessorTests() {
        runTestFloor_WhenKeyEqual()
        runTestFloor_WhenKeyBetween()
        runTestFloor_WhenKeyLessThanAll()
        runTestFloor_WhenKeyGreaterThanAll()

        runTestCeiling_WhenKeyEqual()
        runTestCeiling_WhenKeyBetween()
        runTestCeiling_WhenKeyLessThanAll()
        runTestCeiling_WhenKeyGreaterThanAll()

        runTestPredecessor_WhenKeyEqual()
        runTestPredecessor_WhenKeyBetween()
        runTestPredecessor_WhenKeyLessThanAll()
        runTestPredecessor_WhenKeyGreaterThanAll()

        runTestSuccessor_WhenKeyEqual()
        runTestSuccessor_WhenKeyBetween()
        runTestSuccessor_WhenKeyLessThanAll()
        runTestSuccessor_WhenKeyGreaterThanAll()
    }

    func runSearchContainsRangeTests() {
        runTestSearch()
        runTestContains()
        runTestRangeWithNoElements()
        runTestRangeWithAllElements()
        runTestRangeWithSomeElements()
    }
}

// MARK: - 空集合

extension OrderedCollectionTests {
    /// 空集合
    func runTestEmptyCollection() {
        let collection = factory()
        checkIntegrity(collection)
    }

    /// 清空集合
    func runTestClearCollection() {
        let collection = buildCollection([1, 2, 3, 4, 5])

        collection.clear()
        /// checkIntegrity 只能测试状态，不能测试 clear 操作是否正确
        checkIntegrity(collection)

        /// 添加这几个就够了，其他的 checkIntegrity 会检查的
        #expect(collection.count == 0)
        #expect(collection.isEmpty == true)
        #expect(collection.elements.isEmpty == true)
    }

    /// 单元素集合测试
    func runTestSingleElementCollection() {
        let collection = factory()
        _ = collection.insert(key: 1, value: 10)
        checkIntegrity(collection)
        #expect(collection.min == (1, 10))
        #expect(collection.max == (1, 10))
        #expect(collection.floor(key: 0) == nil)
        #expect(collection.ceiling(key: 2) == nil)
    }

    /// 连续操作测试
    func runTestSequentialOperations() {
        let collection = factory()
        _ = collection.insert(key: 1, value: 10)
        _ = collection.insert(key: 2, value: 20)
        _ = collection.update(key: 1, value: 11)
        _ = collection.remove(key: 2)
        checkIntegrity(collection)
        #expect(collection.elements == [(1, 11)])
    }

    /// 负数和零键测试
    func runTestNegativeAndZeroKeys() {
        let collection = factory()
        _ = collection.insert(key: -3, value: -30)
        _ = collection.insert(key: 0, value: 0)
        _ = collection.insert(key: 2, value: 20)
        checkIntegrity(collection)
        #expect(collection.elements == [(-3, -30), (0, 0), (2, 20)])
    }
}

// MARK: - insert、update、upsert、remove

extension OrderedCollectionTests {
    // 插入单个元素。
    func runTestInsertSingleElement() {
        let collection = factory()
        let result = collection.insert(key: 1, value: 10)

        #expect(result == true)
        #expect(collection.count == 1)

        checkIntegrity(collection)

        #expect(collection.search(key: 1) == 10)
    }

    // 按顺序插入
    func runTestInsertMultipleElementsInOrder() {
        let collection = factory()
        _ = collection.insert(key: -1, value: -10)
        _ = collection.insert(key: 2, value: 20)
        _ = collection.insert(key: 3, value: 30)
        _ = collection.insert(key: 4, value: 40)
        _ = collection.insert(key: 5, value: 50)
        _ = collection.insert(key: 6, value: 60)

        checkIntegrity(collection)
        #expect(collection.count == 6)
    }

    // 乱序插入
    func runTestInsertMultipleElementsOutOfOrder() {
        let collection = factory()
        _ = collection.insert(key: 6, value: 60)
        _ = collection.insert(key: 4, value: 40)
        _ = collection.insert(key: -5, value: -50)
        _ = collection.insert(key: 2, value: 20)
        _ = collection.insert(key: 3, value: 30)
        _ = collection.insert(key: 1, value: 10)

        checkIntegrity(collection)
        #expect(collection.count == 6)
    }

    // 插入重复键
    func runTestInsertDuplicateKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.insert(key: 1, value: 11) == false)
        #expect(collection.insert(key: 5, value: 55) == false)
        #expect(collection.insert(key: 3, value: 33) == false)
        #expect(collection.count == 5)
        checkIntegrity(collection)
    }

    // 更新现有键
    func runTestUpdateExistingKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])

        #expect(collection.update(key: 3, value: 33) == 30)
        #expect(collection.count == 5)
        checkIntegrity(collection)

        #expect(collection.search(key: 3) == 33)
    }

    // 更新不存在的键
    func runTestUpdateNonExistingKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])

        #expect(collection.update(key: 6, value: 66) == nil)
        #expect(collection.count == 5)
        checkIntegrity(collection)

        #expect(collection.contains(key: 6) == false)
    }

    // upsert 新键
    func runTestUpsertNewKey() {
        let collection = buildCollection([2, 4])

        // 最大值
        #expect(collection.upsert(key: 5, value: 55) == nil)
        #expect(collection.search(key: 5) == 55)
        checkIntegrity(collection)

        // 最小值
        #expect(collection.upsert(key: 1, value: 11) == nil)
        #expect(collection.search(key: 1) == 11)
        checkIntegrity(collection)

        // 中间值
        #expect(collection.upsert(key: 3, value: 33) == nil)
        #expect(collection.search(key: 3) == 33)
        checkIntegrity(collection)

        #expect(collection.count == 5)
        #expect(collection.elements == [(1, 11), (2, 20), (3, 33), (4, 40), (5, 55)])
    }

    // upsert 现有键
    func runTestUpsertExistingKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])

        // 最大值
        #expect(collection.upsert(key: 5, value: 55) == 50)
        #expect(collection.search(key: 5) == 55)
        checkIntegrity(collection)

        // 最小值
        #expect(collection.upsert(key: 1, value: 11) == 10)
        #expect(collection.search(key: 1) == 11)
        checkIntegrity(collection)

        // 中间值
        #expect(collection.upsert(key: 3, value: 33) == 30)
        #expect(collection.search(key: 3) == 33)
        checkIntegrity(collection)

        #expect(collection.count == 5)
        #expect(collection.elements == [(1, 11), (2, 20), (3, 33), (4, 40), (5, 55)])
    }

    // 删除现有键
    func runTestRemoveExistingKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.remove(key: 1) == 10)
        #expect(collection.remove(key: 5) == 50)
        #expect(collection.remove(key: 3) == 30)

        checkIntegrity(collection)
        #expect(collection.count == 2)
        #expect(collection.elements == [(2, 20), (4, 40)])
    }

    // 删除不存在的键
    func runTestRemoveNonExistingKey() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.remove(key: 6) == nil)
        #expect(collection.remove(key: 0) == nil)

        checkIntegrity(collection)
        #expect(collection.count == 5)
        #expect(collection.elements == [(1, 10), (2, 20), (3, 30), (4, 40), (5, 50)])
    }
    
    // 删除所有元素
    func runTestRemoveAllElements() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        for key in collection.keys {
            collection.remove(key: key)
        }
        checkIntegrity(collection)
        #expect(collection.count == 0)
    }
    
}

// MARK: - subscript

extension OrderedCollectionTests {
    /// 这里的测试基本与 insert、update、remove、search 的重合

    // 下标取数
    func runTestSubscriptGet() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        // 最大值
        #expect(collection[5] == 50)
        checkIntegrity(collection)

        // 最小值
        #expect(collection[1] == 10)
        checkIntegrity(collection)

        // 中间值
        #expect(collection[3] == 30)
        checkIntegrity(collection)
    }

    // 下标设置新键
    func runTestSubscriptSetNewKey() {
        var collection = buildCollection([2, 4])
        // 最大值
        collection[5] = 50
        checkIntegrity(collection)
        #expect(collection.search(key: 5) == 50)

        // 最小值
        collection[1] = 10
        checkIntegrity(collection)
        #expect(collection.search(key: 1) == 10)

        // 中间值
        collection[3] = 33
        checkIntegrity(collection)
        #expect(collection.search(key: 3) == 33)

        #expect(collection.count == 5)
        #expect(collection.elements == [(1, 10), (2, 20), (3, 33), (4, 40), (5, 50)])
    }

    // 下标更新现有键
    func runTestSubscriptUpdateExistingKey() {
        var collection = buildCollection([1, 2, 3, 4, 5])

        // 最大值
        collection[5] = 55
        checkIntegrity(collection)
        #expect(collection.search(key: 5) == 55)

        // 最小值
        collection[1] = 11
        checkIntegrity(collection)
        #expect(collection.search(key: 1) == 11)

        // 中间值
        collection[3] = 33
        checkIntegrity(collection)
        #expect(collection.search(key: 3) == 33)

        #expect(collection.count == 5)
        #expect(collection.elements == [(1, 11), (2, 20), (3, 33), (4, 40), (5, 55)])
    }

    // 下标删除已存在的键
    func runTestSubscriptDeleteKey() {
        var collection = buildCollection([1, 2, 3, 4, 5])
        // 删除最大值
        collection[5] = nil
        checkIntegrity(collection)

        // 删除最小值
        collection[1] = nil
        checkIntegrity(collection)

        // 删除中间值
        collection[3] = nil
        checkIntegrity(collection)

        #expect(collection.count == 2)
        #expect(collection.elements == [(2, 20), (4, 40)])
    }

    // 下标删除不存在的键
    func runTestSubscriptDeleteNonExistingKey() {
        var collection = buildCollection([1, 2, 3, 4, 5])
        collection[6] = nil
        #expect(collection.count == 5)
        checkIntegrity(collection)
    }

    // 下标删除所有元素
    func runTestSubscriptDeleteAllElements() {
        var collection = buildCollection([1, 2, 3, 4, 5])
        for key in collection.keys {
            collection[key] = nil
        }
        checkIntegrity(collection)
        #expect(collection.count == 0)
    }
}

// MARK: - 遍历方法

extension OrderedCollectionTests {
    /// checkIntegrity 中已经覆盖了绝大部分的遍历方法以及序列的测试
    ///
    /// 这里应该只有 compactMap 方法没有进行功能上的测试。
    func runTestCompactMapTransformation() {
        let collection = buildCollection([1, 2, 3, 4, 5])

        #expect(collection.compactMap { $0.0 > 3 ? nil : $0.0 } == [1, 2, 3])
    }
}

// MARK: - floor、ceiling、predecessor、successor

extension OrderedCollectionTests {
    func runTestFloor_WhenKeyLessThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.floor(key: 0) == nil)

        checkIntegrity(collection)
    }

    func runTestFloor_WhenKeyEqual() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.floor(key: 1) == (1, 10))
        #expect(collection.floor(key: 9) == (9, 90))
        #expect(collection.floor(key: 5) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestFloor_WhenKeyBetween() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.floor(key: 2) == (1, 10))
        #expect(collection.floor(key: 4) == (3, 30))

        checkIntegrity(collection)
    }

    func runTestFloor_WhenKeyGreaterThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.floor(key: 10) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestCeiling_WhenKeyLessThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.ceiling(key: 0) == (1, 10))

        checkIntegrity(collection)
    }

    func runTestCeiling_WhenKeyEqual() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.ceiling(key: 1) == (1, 10))
        #expect(collection.ceiling(key: 3) == (3, 30))
        #expect(collection.ceiling(key: 5) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestCeiling_WhenKeyBetween() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.ceiling(key: 2) == (3, 30))
        #expect(collection.ceiling(key: 4) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestCeiling_WhenKeyGreaterThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.ceiling(key: 6) == nil)

        checkIntegrity(collection)
    }

    func runTestPredecessor_WhenKeyLessThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.predecessor(key: 0) == nil)

        checkIntegrity(collection)
    }

    func runTestPredecessor_WhenKeyEqual() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.predecessor(key: 1) == nil)
        #expect(collection.predecessor(key: 3) == (1, 10))
        #expect(collection.predecessor(key: 9) == (7, 70))

        checkIntegrity(collection)
    }

    func runTestPredecessor_WhenKeyBetween() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.predecessor(key: 2) == (1, 10))
        #expect(collection.predecessor(key: 4) == (3, 30))

        checkIntegrity(collection)
    }

    func runTestPredecessor_WhenKeyGreaterThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.predecessor(key: 7) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestSuccessor_WhenKeyLessThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.successor(key: 0) == (1, 10))

        checkIntegrity(collection)
    }

    func runTestSuccessor_WhenKeyEqual() {
        let collection = buildCollection([1, 3, 5, 7, 9])
        #expect(collection.successor(key: 1) == (3, 30))
        #expect(collection.successor(key: 3) == (5, 50))
        #expect(collection.successor(key: 5) == (7, 70))
        #expect(collection.successor(key: 9) == nil)

        checkIntegrity(collection)
    }

    func runTestSuccessor_WhenKeyBetween() {
        let collection = buildCollection([1, 3, 5, 7, 9])

        #expect(collection.successor(key: 2) == (3, 30))
        #expect(collection.successor(key: 4) == (5, 50))

        checkIntegrity(collection)
    }

    func runTestSuccessor_WhenKeyGreaterThanAll() {
        let collection = buildCollection([1, 2, 3, 4, 5])
        #expect(collection.successor(key: 7) == nil)

        checkIntegrity(collection)
    }
}

// MARK: - search、contains、range

extension OrderedCollectionTests {
    func runTestSearch() {
        let collection = buildCollection([1, 3, 4, 5, 6])

        #expect(collection.search(key: 1) == 10)
        #expect(collection.search(key: 6) == 60)

        _ = collection.update(key: 1, value: 11)
        #expect(collection.search(key: 1) == 11)

        _ = collection.remove(key: 1)
        #expect(collection.search(key: 1) == nil)

        checkIntegrity(collection)
    }

    func runTestContains() {
        let collection = buildCollection([1, 3, 4, 5, 6])

        #expect(collection.contains(key: 1) == true)
        #expect(collection.contains(key: 6) == true)
        #expect(collection.contains(key: 7) == false)

        _ = collection.remove(key: 1)
        #expect(collection.contains(key: 1) == false)

        checkIntegrity(collection)
    }

    /// 全范围
    func runTestRangeWithSomeElements() {
        let collection = buildCollection([1, 2, 3, 4, 5, 6])
        let expected = [(1, 10), (2, 20), (3, 30), (4, 40), (5, 50), (6, 60)]

        #expect(collection.range(in: 1...6) == expected)
        #expect(collection.range(in: 0...7) == expected)

        checkIntegrity(collection)
    }

    /// 部分范围
    func runTestRangeWithAllElements() {
        let collection = buildCollection([10, 20, 30, 40, 50, 60])

        /// minKey 存在并且是collection.min
        #expect(collection.range(in: 10...30) == [(10, 100), (20, 200), (30, 300)])
        /// maxKey 存在并且是collection.max
        #expect(collection.range(in: 40...60) == [(40, 400), (50, 500), (60, 600)])
        /// minKey 和 maxKey 存在且都是内部元素
        #expect(collection.range(in: 20...40) == [(20, 200), (30, 300), (40, 400)])

        /// minKey 不存在并且比 collection.min 小
        #expect(collection.range(in: 5...30) == [(10, 100), (20, 200), (30, 300)])
        /// maxKey 不存在并且比 collection.max 大
        #expect(collection.range(in: 40...65) == [(40, 400), (50, 500), (60, 600)])
        /// minKey 和 maxKey 都不存在且都在内部范围
        #expect(collection.range(in: 11...44) == [(20, 200), (30, 300), (40, 400)])

        checkIntegrity(collection)
    }

    /// 空范围
    func runTestRangeWithNoElements() {
        let collection = buildCollection([3, 4, 5, 6, 7, 8])

        #expect(collection.range(in: 1...2) == [])
        #expect(collection.range(in: 10...19) == [])
        checkIntegrity(collection)
    }
}

// MARK: - 边界测试

/// 其他类型的 key
extension OrderedCollectionTests {}

