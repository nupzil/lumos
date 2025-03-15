///
///  Created by vvgvjks on 2025/1/18.
///
///  Copyright © 2025 vvgvjks <vvgvjks@gmail.com>.
///
///  Permission is hereby granted, free of charge, to any person obtaining a copy
///  of this software and associated documentation files (the "Software"), to deal
///  in the Software without restriction, including without limitation the rights
///  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
///  copies of the Software, and to permit persons to whom the Software is
///  furnished to do so, subject to the following conditions:
///
///  The above copyright notice and this permission notice
///  (including the next paragraph) shall be included in all copies or substantial
///  portions of the Software.
///
///  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
///  ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
///  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
///  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
///  OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
///  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
///  THE SOFTWARE.
///

import Foundation
@testable import Lumos
import Testing

private func buildTree(_ order: Int, _ range: ClosedRange<Int>) -> BTree<Int, Int> {
    let tree = BTree<Int, Int>(order: order)
    for key in range {
        tree.insert(key: key, value: key * 10)
    }
    return tree
}

private func buildTree(_ order: Int, _ keys: [Int]) -> BTree<Int, Int> {
    let tree = BTree<Int, Int>(order: order)
    for key in keys {
        tree.insert(key: key, value: key * 10)
    }
    return tree
}

private func buildTreeWithBulkLoading(_ order: Int, _ range: ClosedRange<Int>) -> BTree<Int, Int> {
    BTree<Int, Int>(contentsOf: range.map { ($0, $0 * 10) }, order: order)
}

@Suite("BTreeTests Tests")
struct BTreeTests {
    @Test("test description")
    func testDescription() async throws {
        let tree = buildTree(3, 1...30)

        let expected = """
        BTree:
        - Height: 4
        - Number of elements: 30
        - Order: 3 (maximum number of children per node)
        """
        
        #expect(tree.description == expected)
    }

    @Test("test tree height")
    func testTreeHeight() async throws {
        #expect(BTree<Int, Int>(order: 3).height == 0)

        let tree = buildTree(3, 1...30)
        let expected = """
        8 16
        ├── 4
        │   ├── 2
        │   │   ├── 1
        │   │   └── 3
        │   └── 6
        │       ├── 5
        │       └── 7
        ├── 12
        │   ├── 10
        │   │   ├── 9
        │   │   └── 11
        │   └── 14
        │       ├── 13
        │       └── 15
        └── 20 24
            ├── 18
            │   ├── 17
            │   └── 19
            ├── 22
            │   ├── 21
            │   └── 23
            └── 26 28
                ├── 25
                ├── 27
                └── 29 30
        """
        #expect(tree.debugDescription == expected)
        #expect(tree.height == 4)
    }

    // MARK: - 预估树的高度

    @Test("test estimatedTreeHeight")
    func testEstimatedTreeHeight() async throws {
        let tree = BPlusTree<Int, Int>()
        
        #expect(tree.estimatedHeight(order: 3, numberOfElements: 0) == 0)
        
        /// 如果 BTree 的 order = 16 那么最大子节点数为 16，那么最小子节点数为 8
        /// 最坏情况：
        /// 第一层：7 个元素，8 个子节点 （累计 7 个元素）
        /// 第二层：8 * 7 = 56 个元素， 8 * 8 = 64 个子节点 （累计 63 个元素）
        /// 第三层：64 * 7 = 448 个元素， 64 * 8 = 512 个子节点 （累计 511 个元素）
        /// 第四层：512 * 7 = 3584 个元素， 512 * 8 = 4096 个子节点 （累计 4095 个元素）
        /// 第五层：4096 * 7 = 28672 个元素， 4096 * 8 = 32768 个子节点 （累计 32767 个元素）
        /// 第六层：32768 * 7 = 229376 个元素， 32768 * 8 = 262144 个子节点 （累计 262143 个元素）
        /// 第七层：262144 * 7 = 1835008 个元素， 262144 * 8 = 2097152 个子节点 （累计 2097151 个元素）
        /// 第八层：2097152 * 7 = 14680064 个元素 （累计 16777215 个元素）
        /// 累计共8层：
        /// - 总元素数为：16777215    约 1600 万
        /// - 总节点数为：2396745     约 200  万
        /// - 叶子节点数：2097152     约 200  万
        /// - 中间节点数：299593      约 30   万
        /// - 元素总数大概是节点数的 7 倍大小
        /// - 叶子节点数大概是中间节点的 7 倍大小
        /// - 每个叶子节点的 children 内存都是浪费的，共浪费 24 * 2097152 字节 = 384MB
        /// - 如果 children 改为 Optional 类型，那么
        ///   - 中间节点会增加 8 * 299593 字节的内存
        ///   - 叶子节点会减少 16 * 2097152 字节的内存
        ///   - 一来一回会减少 16 * 2097152 - 8 * 299593 字节的内存 = 237MB
        ///   - 仍然是浪费了 8 * 2396745 字节的内存 = 146 MB，但是效果还是挺明显的。
        ///
        /// 最佳情况：
        /// 第一层：15 个元素，16 个子节点 （累计 15 个元素）
        /// 第二层：16 * 15 = 240 个元素， 16 * 16 = 256 个子节点 （累计 255 个元素）
        /// 第三层：256 * 15 = 3840 个元素， 256 * 16 = 4096 个子节点 （累计 4095 个元素）
        /// 第四层：4096 * 15 = 61440 个元素， 4096 * 16 = 65536 个子节点 （累计 65535 个元素）
        /// 第五层：65536 * 15 = 983040 个元素， 65536 * 16 = 1048576 个子节点 （累计 1048575 个元素）
        /// 第六层：1048576 * 15 = 15728640 个元素， 1048576 * 16 = 16777216 个子节点 （累计 16777215 个元素）
        /// 第七层：16777216 * 15 = 251658240 个元素， 16777216 * 16 = 268435456 个子节点 （累计 268435455 个元素）
        /// 第八层：268435456 * 15 = 4026531840 个元素 （累计 4294967295 个元素）
        /// 累计共8层：
        /// - 总元素数为：4294967295  约 42 亿元素
        /// - 总节点数为：286331153   约 2 亿
        /// - 叶子节点数：268435456   约 2 亿
        /// - 中间节点数：17895696    约 1.7 千万
        /// - 元素总数大概是节点数的 15 倍大小
        /// - 叶子节点数大概是中间节点的 15 倍大小
        /// - 每个叶子节点的 children 内存都是浪费的，共浪费 24 * 8 * 268435456 = 48GB
        
        /// 根据上述推算得出，这个计算方式是准确的。
        /// 我们发现 order = 16 时最佳情况 6 层就可以容纳 最坏情况 8 层 的元素了。
        
        /// 内部计算的是最差情况的高度-所以传入的 m 需要乘 2
        func t1(_ m: Int, _ n: Int) -> Int {
            return tree.estimatedHeight(order: m * 2, numberOfElements: n)
        }
        /// 依赖 Foundation 需要 + 1 向上取整
        func t2(_ m: Int, _ n: Int) -> Int {
            Int(log(Double(n)) / log(Double(m))) + 1
        }
        #expect(t2(8, 14680064) == 8)
        #expect(t2(16, 4294967295) == 8)
        
        #expect(t1(3, 1000000) == t2(3, 1000000))
        #expect(t1(6, 1000000) == t2(6, 1000000))
        #expect(t1(8, 1000000) == t2(8, 1000000))
        #expect(t1(16, 1000000) == t2(16, 1000000))
        #expect(t1(64, 1000000) == t2(64, 1000000))
        #expect(t1(128, 1000000) == t2(128, 1000000))
    }
    
    // MARK: - OrderedCollection 协议测试也是基础功能测试

    /// 通过此测试只能代表其基本功能没啥问题，一些跨节点的细节是测不到的。
    @Suite("BTree OrderedCollection protocol tests")
    struct BTreeOrderedCollectionProtocolTests: OrderedCollectionTests {
        func factory() -> BTree<Int, Int> {
            return BTree<Int, Int>(order: 3)
        }
        
        @Test("test basic operations")
        func TestBasicOperationsTests() async throws {
            runBasicOperationsTests()
        }
        
        @Test("test insertion and deletion")
        func TestInsertionAndDeletionTests() async throws {
            runInsertionAndDeletionTests()
        }
        
        @Test("test subscript")
        func TestSubscriptOperationsTests() async throws {
            runSubscriptOperationsTests()
        }
        
        @Test("test traversal operations")
        func TestTraversalTests() async throws {
            runTraversalTests()
        }
        
        @Test("test floor、ceiling、predecessor、successor")
        func TestFloorCeilingPredecessorSuccessorTests() async throws {
            runFloorCeilingPredecessorSuccessorTests()
        }
        
        @Test("test search、contains、range")
        func TestSearchContainsRangeTests() async throws {
            runSearchContainsRangeTests()
        }
        
        @Test("test random operations")
        func TestRandomOperations() async throws {
            for _ in 0..<10 {
                runTestRandomOperations()
            }
        }
    }
    
    // MARK: - 结构变化测试

    @Suite("BTree Top-Down insert tests")
    struct BTreeTopDownInsertTests {
        /// 测试使用 _insert 方法 build 一个树
        @Test("test build tree with top-down insert")
        func testBuildTreeWithTopDownInsert() async throws {
            let tree = BTree<Int, Int>(order: 5)
            for i in 1...18 {
                tree._insert(key: i, value: i * 10)
            }
            let expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18
            """
            #expect(tree.debugDescription == expected)
        }

        /// _insert 是 Top-Down 的实现，这里需要测试其功能和结构
        @Test("test top-down insert feature")
        func testTopDownInsertFeature() async throws {
            let collection = BTree<Int, Int>(order: 4)

            /// 插入不存在的键
            #expect(collection._insert(key: 1, value: 10) == true)
            #expect(collection.search(key: 1) == 10)
            #expect(collection.elements == [(1, 10)])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)

            /// 插入已存在的键
            #expect(collection._insert(key: 1, value: 20) == false)
            #expect(collection.search(key: 1) == 10)
            #expect(collection.elements == [(1, 10)])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)

            /// 乱序插入一批

            collection.clear()

            collection._insert(key: 5, value: 50)
            collection._insert(key: 1, value: 10)
            collection._insert(key: 2, value: 20)
            collection._insert(key: 4, value: 40)
            collection._insert(key: 3, value: 30)

            #expect(collection.keys == [1, 2, 3, 4, 5])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
        }

        /// 下降过程中没有发现需要分裂的节点
        @Test("test top-down insert not split")
        func testTopDownInsertNotSplit() async throws {
            let tree = buildTree(5, 1...18)
            var expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18
            """
            #expect(tree.debugDescription == expected)

            tree._insert(key: 19, value: 190)

            expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18 19
            """
            #expect(tree.debugDescription == expected)
        }

        /// 下降过程中只有最终的叶子节点需要分裂
        @Test("test top-down insert leaf node split")
        func testTopDownInsertLeafNodeSplit() async throws {
            let tree = buildTree(5, 1...19)
            var expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18 19
            """
            #expect(tree.debugDescription == expected)

            tree._insert(key: 20, value: 200)

            expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15 18
                ├── 10 11
                ├── 13 14
                ├── 16 17
                └── 19 20
            """
            #expect(tree.debugDescription == expected)
        }

        /// 下降过程中发现中间子节点需要分裂
        @Test("test top-down insert inner node split")
        func testTopDownInsertInnerNodeSplit() async throws {
            let tree = buildTree(5, [1, 30, 40, 50, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 5, 6, 7, 8, 9, 11, 12])
            var expected = """
            64
            ├── 6 9 40 61
            │   ├── 1 5
            │   ├── 7 8
            │   ├── 11 12 30
            │   ├── 50 60
            │   └── 62 63
            └── 67 71
                ├── 65 66
                ├── 68 69
                └── 72 73 74
            """
            #expect(tree.debugDescription == expected)

            /// 叶子节点不触发分裂-内部节点触发分裂
            tree._insert(key: 31, value: 310)
            expected = """
            40 64
            ├── 6 9
            │   ├── 1 5
            │   ├── 7 8
            │   └── 11 12 30 31
            ├── 61
            │   ├── 50 60
            │   └── 62 63
            └── 67 71
                ├── 65 66
                ├── 68 69
                └── 72 73 74
            """
            #expect(tree.debugDescription == expected)
        }
    }

    @Suite("BTree Top-Down remove tests")
    struct BTreeTopDownRemoveTests {
        /// remove: 默认的删除是 Top-Down 的
        /// 0. 下降过程无需借用与合并
        /// 1. 目标在内部节点，需要交换至叶子节点
        /// 2. 下降时发现中间节点-左借用
        /// 3. 下降时发现中间节点-右借用
        /// 4. 下降时发现中间节点-左合并
        /// 5. 下降时发现中间节点-右合并
        /// 6. 下降时发现叶子节点-左借用
        /// 7. 下降时发现叶子节点-右借用
        /// 8. 下降时发现叶子节点-左合并
        /// 9. 下降时发现叶子节点-右合并
        @Test("test remove after no need to merge and borrow")
        func TestRemoveWithNoNeedToBorrowAndMerge() async throws {
            let tree = buildTree(4, 1...10)
            var expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 8
                ├── 5
                ├── 7
                └── 9 10
            """
            #expect(tree.debugDescription == expected)

            _ = tree.remove(key: 10)
            expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 8
                ├── 5
                ├── 7
                └── 9
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove leaf nodes need to be left borrow")
        func TestRemoveWithLeafNodesNeedToBeLeftBorrow() async throws {
            let tree = buildTree(4, [1, 2, 3, 4, 5, 6, 70, 80, 90, 100, 75])
            tree.remove(key: 100)
            
            var expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 80
                ├── 5
                ├── 70 75
                └── 90
            """
            
            #expect(tree.debugDescription == expected)

            /// 触发借用
            tree.remove(key: 90)
            
            expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 75
                ├── 5
                ├── 70
                └── 80
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove leaf nodes need to be right borrow")
        func TestRemoveWithLeafNodesNeedToBeRightBorrow() async throws {
            let tree = buildTree(4, [1, 2, 3, 4, 5, 6, 70, 80, 90, 100, 75])
            _ = tree.remove(key: 75)
            var expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 80
                ├── 5
                ├── 70
                └── 90 100
            """
            
            #expect(tree.debugDescription == expected)
            
            // 触发右借用
            _ = tree.remove(key: 70)
            
            expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 90
                ├── 5
                ├── 80
                └── 100
            """
            
            #expect(tree.debugDescription == expected)
        }

        @Test("test remove leaf nodes need to be left merge")
        func TestRemoveWithLeafNodesNeedToBeLeftMerge() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 15, 18, 20, 21, 22, 23, 24, 70, 80, 75])
            var expected = """
            10
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9
            └── 15 21 24
                ├── 11 12
                ├── 18 20
                ├── 22 23
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 20)
            
            expected = """
            10
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9
            └── 21 24
                ├── 11 12 15 18
                ├── 22 23
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove leaf nodes need to be right merge")
        func TestRemoveWithLeafNodesNeedToBeRightMerge() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 15, 18, 20, 21, 22, 23, 24, 70, 80, 75])
            var expected = """
            10
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9
            └── 15 21 24
                ├── 11 12
                ├── 18 20
                ├── 22 23
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 11)
            
            expected = """
            10
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9
            └── 21 24
                ├── 12 15 18 20
                ├── 22 23
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove internal nodes need to be left borrow")
        func TestRemoveWithInternalNodesNeedToBeLeftBorrow() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 70, 80, 75, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 9, 10, 11, 12])
            var expected = """
            30 44
            ├── 3 6 10
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 8 9
            │   └── 11 12 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            /// Bottom-up 是无需修改结构的，Top-Down 需要触发左借用（优先左边）
            _ = tree.remove(key: 39)
            expected = """
            10 44
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9
            ├── 30 33 36
            │   ├── 11 12 29
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove internal nodes need to be right borrow")
        func TestRemoveWithInternalNodesNeedToBeRightBorrow() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 9, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 70, 80, 75, 10, 11])
            var expected = """
            14
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 9 10 11
            └── 17 21 24
                ├── 15 16
                ├── 18 20
                ├── 22 23
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            /// Buttom-up 是无无需调整结构的，但是 Top-Down 在 3,6 这个节点会触发右借用。
            tree.remove(key: 11)
            
            expected = """
            17
            ├── 3 6 14
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 8 9 10
            │   └── 15 16
            └── 21 24
                ├── 18 20
                ├── 22 23
                └── 70 75 80
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove internal nodes need to be left merge")
        func TestRemoveWithInternalNodesNeedToBeLeftMerge() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39])
            var expected = """
            30 44
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51
                ├── 45 46
                ├── 48 50
                └── 52 53
            """
            
            #expect(tree.debugDescription == expected)
            
            /// 叶子节点无需借用或合并，中间节点需要左合并（优先）
            tree.remove(key: 39)
            
            expected = """
            44
            ├── 3 6 30 33 36
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 8 29
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38
            └── 47 51
                ├── 45 46
                ├── 48 50
                └── 52 53
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove internal nodes need to be right merge")
        func TestRemoveWithInternalNodesNeedToBeRightMerge() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 8, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 28])
            var expected = """
            30 44
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 8 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51
                ├── 45 46
                ├── 48 50
                └── 52 53
            """
            
            #expect(tree.debugDescription == expected)
            
            /// 删除叶子节点，但是中间节点触发了右合并
            tree.remove(key: 29)
            expected = """
            44
            ├── 3 6 30 33 36
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 8 28
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51
                ├── 45 46
                ├── 48 50
                └── 52 53
            """
            
            #expect(tree.debugDescription == expected)
        }

        @Test("test remove internal nodes need to exchange")
        func TestRemoveInternalNodesNeedToExchange() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 28, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 70, 80, 75, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 9, 10, 15, 17, 11])
            var expected = """
            30 44
            ├── 3 6 15
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 9 10 11
            │   └── 17 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            /// 只是交互+删除，没有触发借用与合并
            tree.remove(key: 15)
            expected = """
            30 44
            ├── 3 6 11
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 9 10
            │   └── 17 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove leaf nodes no need to exchange and borrow")
        func TestRemoveLeafNodesNoNeedToExchangeAndBorrow() async throws {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 28, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 70, 80, 75, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 9, 10, 15, 17, 11])
            var expected = """
            30 44
            ├── 3 6 15
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 9 10 11
            │   └── 17 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            
            /// 直接删除不触发合并或借用
            tree.remove(key: 11)
            expected = """
            30 44
            ├── 3 6 15
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 9 10
            │   └── 17 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
        }
    }

    @Suite("BTree Bottom-Up insert tests")
    struct BTreeBottomUpInsertTests {
        /// 这里的所有测试都只测试结构的变化
        func runTestInsertWithNoNeedToSplit(_ callback: (BTree<Int, Int>, Int, Int) -> Void) {
            let tree = buildTree(4, 1...2)
            #expect(tree.debugDescription == "1 2")
            
            callback(tree, 3, 30)
            
            #expect(tree.debugDescription == "1 2 3")
        }

        func runTestInsertWithLeafNodesNeedToBeSplit(_ callback: (BTree<Int, Int>, Int, Int) -> Void) {
            let tree = buildTree(4, 1...5)
            /// order  = 4 其最小子节点数为 2，那么最小键数就是 1，那么分割点就会从下标 1 的位置分割
            var expected = """
            2
            ├── 1
            └── 3 4 5
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 6, 60)
            
            expected = """
            2 4
            ├── 1
            ├── 3
            └── 5 6
            """
            #expect(tree.debugDescription == expected)
        }

        func runTestInsertWithInternalNodesNeedToBeSplit(_ callback: (BTree<Int, Int>, Int, Int) -> Void) {
            let tree = buildTree(4, 1...9)
            var expected = """
            2 4 6
            ├── 1
            ├── 3
            ├── 5
            └── 7 8 9
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 10, 100)
            
            expected = """
            4
            ├── 2
            │   ├── 1
            │   └── 3
            └── 6 8
                ├── 5
                ├── 7
                └── 9 10
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// insert: 默认的插入是 Bottom-up 的
        /// 1. 插入后无需分裂
        /// 2. 插入后叶子节点需要分裂
        /// 3. 插入后中间节点需要分裂
        @Test("test insert after no need to split")
        func TestInsertWithNoNeedToSplit() async throws {
            runTestInsertWithNoNeedToSplit { tree, key, value in
                _ = tree.insert(key: key, value: value)
            }
        }

        @Test("test insert after leaf nodes need to be split")
        func TestInsertWithLeafNodesNeedToBeSplit() async throws {
            runTestInsertWithLeafNodesNeedToBeSplit { tree, key, value in
                _ = tree.insert(key: key, value: value)
            }
        }

        @Test("test insert after internal nodes need to be split")
        func TestInsertWithInternalNodesNeedToBeSplit() async throws {
            runTestInsertWithInternalNodesNeedToBeSplit { tree, key, value in
                _ = tree.insert(key: key, value: value)
            }
        }
        
        /// upsert: 插入操作是 Bottom-up 的
        @Test("test upsert-insert after no need to split")
        func TestUpsertInsertWithNoNeedToSplit() async throws {
            runTestInsertWithNoNeedToSplit { tree, key, value in
                _ = tree.upsert(key: key, value: value)
            }
        }
        
        @Test("test upsert-insert leaf nodes need to be split")
        func TestUpsertInsertWithLeafNodesNeedToBeSplit() async throws {
            runTestInsertWithLeafNodesNeedToBeSplit { tree, key, value in
                _ = tree.upsert(key: key, value: value)
            }
        }
        
        @Test("test upsert-insert internal nodes need to be split")
        func TestUpsertInsertWithInternalNodesNeedToBeSplit() async throws {
            runTestInsertWithInternalNodesNeedToBeSplit { tree, key, value in
                _ = tree.upsert(key: key, value: value)
            }
        }
    }

    @Suite("BTree Bottom-Up remove tests")
    struct BTreeBottomUpRemoveTests {
        /// _remove 是 Bottom-Up 的实现，这里需要测试其功能和结构
        @Test("test bottom-up remove feature")
        func testBottomUpRemoveFeature() async throws {
            /// _insert 是 Top-Down 的最少需要 order = 4 Bottom-up 可以支持 order = 3
            let collection = BTree<Int, Int>(order: 4)
            collection._insert(key: 5, value: 50)
            collection._insert(key: 1, value: 10)
            collection._insert(key: 2, value: 20)
            collection._insert(key: 4, value: 40)
            collection._insert(key: 3, value: 30)
            
            /// 删除最小的键
            #expect(collection._remove(key: 1) == 10)
            #expect(collection.contains(key: 1) == false)
            print(collection.debugDescription)
            #expect(collection.keys == [2, 3, 4, 5])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
            
            /// 删除最大的键
            #expect(collection._remove(key: 5) == 50)
            #expect(collection.contains(key: 5) == false)
            #expect(collection.keys == [2, 3, 4])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
            
            /// 删除中间的键
            #expect(collection._remove(key: 3) == 30)
            #expect(collection.contains(key: 3) == false)
            #expect(collection.keys == [2, 4])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
            
            /// 删除不存在的键
            #expect(collection._remove(key: 3) == nil)
            #expect(collection.contains(key: 3) == false)
            #expect(collection.keys == [2, 4])
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
            
            /// 删光了
            #expect(collection._remove(key: 2) == 20)
            #expect(collection._remove(key: 4) == 40)
            #expect(collection.keys == [])
            #expect(collection.root == nil)
            BTreeOrderedCollectionProtocolTests().checkIntegrity(collection)
        }
        
        /// 无需借用和合并
        @Test("test bottom-up remove no borrowing or merging required")
        func testBottomUpRemoveNoBorrowingOrMergingRequired() async throws {
            let tree = buildTree(5, 1...18)
            var expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 18)
            
            expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 无需借用与合并，但是目标键在内部节点，需要交互至叶子节点
        @Test("test bottom-up remove no borrowing or merging required but target key in inner node")
        func testBottomUpRemoveNoBorrowingOrMergingRequiredButTargetKeyInInnerNode() async throws {
            let tree = buildTree(5, 1...18)
            var expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 15)
            
            expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 16
                ├── 10 11
                ├── 13 14
                └── 17 18
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 叶子节点需要左借用
        @Test("test bottom-up remove leaf node left borrow")
        func testBottomUpRemoveLeafNodeLeftBorrow() async throws {
            let tree = buildTree(5, [1, 30, 40, 50, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 5, 6, 7, 8, 9, 11, 12])
            var expected = """
            64
            ├── 6 9 40 61
            │   ├── 1 5
            │   ├── 7 8
            │   ├── 11 12 30
            │   ├── 50 60
            │   └── 62 63
            └── 67 71
                ├── 65 66
                ├── 68 69
                └── 72 73 74
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 60)
            
            expected = """
            64
            ├── 6 9 30 61
            │   ├── 1 5
            │   ├── 7 8
            │   ├── 11 12
            │   ├── 40 50
            │   └── 62 63
            └── 67 71
                ├── 65 66
                ├── 68 69
                └── 72 73 74
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 叶子节点需要右借用
        @Test("test bottom-up remove leaf node right borrow")
        func testBottomUpRemoveLeafNodeRightBorrow() async throws {
            let tree = buildTree(5, 1...18)
            var expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 15
                ├── 10 11
                ├── 13 14
                └── 16 17 18
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 14)
            expected = """
            9
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            └── 12 16
                ├── 10 11
                ├── 13 15
                └── 17 18
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 叶子节点需要合并左兄弟
        @Test("test bottom-up remove leaf node left merge")
        func testBottomUpRemoveLeafNodeLeftMerge() async throws {
            let tree = buildTree(5, 1...30)
            var expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24 27
                ├── 19 20
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 23)
            
            expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 24 27
                ├── 19 20 21 22
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 叶子节点需要合并右兄弟
        @Test("test bottom-up remove leaf node right merge")
        func testBottomUpRemoveLeafNodeRightMerge() async throws {
            let tree = buildTree(5, 1...30)
            var expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24 27
                ├── 19 20
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 20)
            
            expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 24 27
                ├── 19 21 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 中间节点需要借用左兄弟
        @Test("test bottom-up remove internal node left borrow")
        func testBottomUpRemoveInnerNodeLeftBorrow() async throws {
            let tree = buildTree(5, [1, 30, 40, 50, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 5, 6, 7, 8, 9, 11, 12, 75, 76, 77, 78, 79, 81, 82, 83, 84])
            var expected = """
            64 74
            ├── 6 9 40 61
            │   ├── 1 5
            │   ├── 7 8
            │   ├── 11 12 30
            │   ├── 50 60
            │   └── 62 63
            ├── 67 71
            │   ├── 65 66
            │   ├── 68 69
            │   └── 72 73
            └── 77 81
                ├── 75 76
                ├── 78 79
                └── 82 83 84
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 65)
            
            expected = """
            61 74
            ├── 6 9 40
            │   ├── 1 5
            │   ├── 7 8
            │   ├── 11 12 30
            │   └── 50 60
            ├── 64 71
            │   ├── 62 63
            │   ├── 66 67 68 69
            │   └── 72 73
            └── 77 81
                ├── 75 76
                ├── 78 79
                └── 82 83 84
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 中间节点需要借用右兄弟
        @Test("test bottom-up remove internal node right borrow")
        func testBottomUpRemoveInnerNodeRightBorrow() async throws {
            let tree = buildTree(5, 1...30)
            var expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24 27
                ├── 19 20
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 11)
            
            expected = """
            9 21
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 15 18
            │   ├── 10 12 13 14
            │   ├── 16 17
            │   └── 19 20
            └── 24 27
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 中间节点需要合并左兄弟
        @Test("test bottom-up remove internal node left merge")
        func testBottomUpRemoveInnerNodeLeftMerge() async throws {
            let tree = buildTree(5, 1...26)
            var expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24
                ├── 19 20
                ├── 22 23
                └── 25 26
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 11)
            
            expected = """
            18
            ├── 3 6 9 15
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 7 8
            │   ├── 10 12 13 14
            │   └── 16 17
            └── 21 24
                ├── 19 20
                ├── 22 23
                └── 25 26
            """
            #expect(tree.debugDescription == expected)
        }
        
        /// 中间节点需要合并右兄弟
        @Test("test bottom-up remove internal node right merge")
        func testBottomUpRemoveInnerNodeRightMerge() async throws {
            let tree = buildTree(5, 1...30)
            var expected = """
            9 18
            ├── 3 6
            │   ├── 1 2
            │   ├── 4 5
            │   └── 7 8
            ├── 12 15
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24 27
                ├── 19 20
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
            
            tree._remove(key: 2)
            
            expected = """
            18
            ├── 6 9 12 15
            │   ├── 1 3 4 5
            │   ├── 7 8
            │   ├── 10 11
            │   ├── 13 14
            │   └── 16 17
            └── 21 24 27
                ├── 19 20
                ├── 22 23
                ├── 25 26
                └── 28 29 30
            """
            #expect(tree.debugDescription == expected)
        }
    }
    
    // MARK: - bulk-loading
    
    @Suite("BTree bulk-loading tests")
    struct BTreeBulkLoadingTests {
        /// bulk-loading 的测试涉及到内部细节了，需要测试以下几种情况：
        /// 1. 插入的数量小于或等于 maxElements 的情况
        /// 2. 最后一个叶子节点的元素数量 等于 order - 1 （叶子节点都是满的）
        /// 3. 最后一个叶子节点的元素数量 等于 order（需要重新分配）
        /// 4. 最后一个叶子节点的元素数量 小于 order - 1（需要重新分配）
        /// 5. 内部节点最上层的数量小于或等于 maxElements
        /// 6. 内部节点最后一个节点的元素数量 等于 order - 1 （这一层节点都是满的）
        /// 7. 内部节点最后一个节点的元素数量 等于 order（需要重新分配）
        /// 8. 内部节点最后一个节点的元素数量 小于 order - 1（需要重新分配）
        
        /// 测试 bulk-loading 时，插入的数量小于等于 maxElements 的情况
        @Test("test bulk loading with elements less than or equal to maxElements")
        func testBulkLoadingWithElementsLessThanOrEqualMaxElements() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...2)
            let expected = """
            1 2
            """
            #expect(tree.debugDescription == expected)

            let tree2 = buildTreeWithBulkLoading(4, 1...3)
            let expected2 = """
            1 2 3
            """
            #expect(tree2.debugDescription == expected2)
        }

        /// 测试 bulk-loading 时，最后一个叶子节点刚好满的情况
        @Test("test bulk loading with last leaf node full")
        func testBulkLoadingWithLastLeafNodeFull() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...7)
            let expected = """
            4
            ├── 1 2 3
            └── 5 6 7
            """
            #expect(tree.debugDescription == expected)
        }

        /// 测试 bulk-loading 时，存在多个叶子节点并且最后一个叶子节点小于 order - 1 的情况
        @Test("test bulk loading with last leaf node less than order - 1")
        func testBulkLoadingWithLastLeafNodeLessThanOrderMinusOne() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...6)
            let expected = """
            4
            ├── 1 2 3
            └── 5 6
            """
            #expect(tree.debugDescription == expected)
        }

        /// 测试 bulk-loading 时，最后一个叶子节点刚好等于 order 的情况
        @Test("test bulk loading with last leaf node equal to order")
        func testBulkLoadingWithLastLeafNodeEqualOrder() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...8)
            let expected = """
            4 7
            ├── 1 2 3
            ├── 5 6
            └── 8
            """
            #expect(tree.debugDescription == expected)
        }

        /// 测试 bulk-loading 时，中间节点只有一个节点并且元素小于等于 maxElements 的情况
        @Test("test bulk loading with inner node top level less than or equal to maxElements")
        func testBulkLoadingWithInnerNodeTopLevelLessThanOrEqualMaxElements() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...11)
            let expected = """
            4 8
            ├── 1 2 3
            ├── 5 6 7
            └── 9 10 11
            """

            #expect(tree.debugDescription == expected)

            let tree2 = buildTreeWithBulkLoading(4, 1...12)
            let expected2 = """
            4 8 11
            ├── 1 2 3
            ├── 5 6 7
            ├── 9 10
            └── 12
            """

            #expect(tree2.debugDescription == expected2)
        }

        /// 测试 bulk-loading 时，中间节点的最后一个节点刚好满的情况（也就是 == order - 1）
        @Test("test bulk loading with inner node last node full")
        func testBulkLoadingWithInnerNodeLastNodeFull() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...31)
            let expected = """
            16
            ├── 4 8 12
            │   ├── 1 2 3
            │   ├── 5 6 7
            │   ├── 9 10 11
            │   └── 13 14 15
            └── 20 24 28
                ├── 17 18 19
                ├── 21 22 23
                ├── 25 26 27
                └── 29 30 31
            """
            #expect(tree.debugDescription == expected)
        }

        /// 测试 bulk-loading 时，中间节点的最后一个节点刚好等于 order 的情况
        @Test("test bulk loading with inner node last node equal to order")
        func testBulkLoadingWithInnerNodeLastNodeEqualOrder() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...19)
            let expected = """
            12
            ├── 4 8
            │   ├── 1 2 3
            │   ├── 5 6 7
            │   └── 9 10 11
            └── 16
                ├── 13 14 15
                └── 17 18 19
            """
            #expect(tree.debugDescription == expected)
        }

        /// 测试 bulk-loading 时，中间节点存在多个节点并且的最后一个节点小于 order - 1 的情况
        @Test("test bulk loading with inner node last node less than order - 1")
        func testBulkLoadingWithInnerNodeLastNodeLessThanOrderMinusOne() async throws {
            let tree = buildTreeWithBulkLoading(4, 1...23)
            let expected = """
            12
            ├── 4 8
            │   ├── 1 2 3
            │   ├── 5 6 7
            │   └── 9 10 11
            └── 16 20
                ├── 13 14 15
                ├── 17 18 19
                └── 21 22 23
            """
            #expect(tree.debugDescription == expected)
        }
    }
    
    // MARK: - 跨节点的读操作

    @Suite("BTree cross-node read tests")
    struct BTreeCrossNodeReadTests {
        /// 跨节点的读操作：
        /// - floor、predecessor 在兄弟节点
        /// - floor、predecessor 在前一个位置
        /// - ceiling、successor 在兄弟节点
        /// - ceiling、successor 在下一个位置
        /// - search、contains   目标在内部节点
        /// - search、contains   目标在叶子节点
        /// - range lower 存在，在内部节点
        /// - range lower 存在，在叶子节点
        /// - range lower 不存在，需要从后继开始-后继在下一个位置
        /// - range lower 不存在，需要从后继开始-后继在兄弟节点
        /// - range upper 存在，在不同的内部节点
        /// - range upper 存在，在不同的叶子节点
        /// - range upper 不存在，需要再其前驱终止-前驱在不同的中间节点
        /// - range upper 不存在，需要再其前驱终止-前驱在不同的叶子节点
        
        /// 构建一个包含多个节点的树
        func buildTreeWithMultipleNodes() -> BTree<Int, Int> {
            let tree = buildTree(5, [1, 2, 3, 4, 5, 6, 28, 29, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54, 70, 80, 75, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 9, 10, 15, 17, 11])
            let expected = """
            30 44
            ├── 3 6 15
            │   ├── 1 2
            │   ├── 4 5
            │   ├── 9 10 11
            │   └── 17 28 29
            ├── 33 36
            │   ├── 31 32
            │   ├── 34 35
            │   └── 37 38 39
            └── 47 51 54
                ├── 45 46
                ├── 48 50
                ├── 52 53
                └── 70 75 80
            """
            
            #expect(tree.debugDescription == expected)
            BTreeOrderedCollectionProtocolTests().checkIntegrity(tree)
            return tree
        }

        @Test("test floor、predecessor", arguments: [
            /// 目标落于叶子节点、后继位于父级
            (16, (15, 150)),
            /// 目标落于叶子节点、后继位于前一项
            (27, (17, 170)),
            /// 目标落于内层节点、后继位于子节点最后一项
            (12, (11, 110)),
        ])
        func testFloorPredecessor(key: Int, expected: (Int, Int)) async throws {
            let tree = buildTreeWithMultipleNodes()
            
            #expect(tree.floor(key: key) == expected)
            #expect(tree.predecessor(key: key) == expected)
        }

        @Test("test ceiling、successor", arguments: [
            /// 目标落于叶子节点、后继位于后一项
            (18, (28, 280)),
            /// 目标落于叶子节点、后继位于其父级
            (12, (15, 150)),
            /// 目标落于内层节点、后继位于子节点第一项
            (55, (70, 700)),
        ])
        func testCeilingSuccessor(key: Int, expected: (Int, Int)) async throws {
            let tree = buildTreeWithMultipleNodes()
            
            #expect(tree.ceiling(key: key) == expected)
            #expect(tree.successor(key: key) == expected)
        }

        @Test("test search、contains", arguments: [
            /// in inner node
            (51, 510),
            /// in leaf node
            (50, 500),
        ])
        func testSearchContains(key: Int, expected: Int) async throws {
            let tree = buildTreeWithMultipleNodes()
            
            #expect(tree.search(key: key) == expected)
            #expect(tree.contains(key: key) == true)
        }

        @Test("test range", arguments: [
            /// lower exists, in inner node center
            (51...54, [51, 52, 53, 54]),
            /// lower exists, in leaf node center
            (10...33, [10, 11, 15, 17, 28, 29, 30, 31, 32, 33]),
            /// lower not exists, need to start from successor, successor in next position
            (18...33, [28, 29, 30, 31, 32, 33]),
            /// lower not exists, need to start from successor, successor in parent node
            (12...33, [15, 17, 28, 29, 30, 31, 32, 33]),
            /// upper exists, in different inner node
            (15...36, [15, 17, 28, 29, 30, 31, 32, 33, 34, 35, 36]),
            /// upper exists, in different leaf node
            (15...32, [15, 17, 28, 29, 30, 31, 32]),
            /// upper not exists, need to end at predecessor, predecessor in different inner node
            (35...55, [35, 36, 37, 38, 39, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54]),
            /// lower is right tree's max value, also means to skip parent node and search in parent's sibling node
            (39...55, [39, 44, 45, 46, 47, 48, 50, 51, 52, 53, 54]),
            /// upper not exists, need to end at predecessor, predecessor in different leaf node
            (5...20, [5, 6, 9, 10, 11, 15, 17]),
        ])
        func testRange(range: ClosedRange<Int>, expected: [Int]) async throws {
            let tree = buildTreeWithMultipleNodes()
            
            #expect(tree.range(in: range).map { $0.0 } == expected)
        }
    }
}
