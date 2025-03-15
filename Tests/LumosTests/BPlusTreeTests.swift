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

private func buildTree(order: Int, keys: [Int]) -> BPlusTree<Int, Int> {
    let tree = BPlusTree<Int, Int>(order: order)
    for key in keys {
        tree.insert(key: key, value: key * 10)
    }
    return tree
}

private func buildTree(order: Int, range: ClosedRange<Int>) -> BPlusTree<Int, Int> {
    let tree = BPlusTree<Int, Int>(order: order)
    for key in range {
        tree.insert(key: key, value: key * 10)
    }
    return tree
}

@Suite("BPlusTree Tests")
struct BPlusTreeTests {
    // MARK: - 预估树的高度
    
    @Test("test estimatedTreeHeight")
    func testEstimatedTreeHeight() async throws {
        let tree = BPlusTree<Int, Int>()
        
        #expect(tree.estimatedHeight(order: 3, numberOfElements: 0) == 0)
        
        /// 如果 BPlusTree 的 order = 16 那么最大子节点数为 16，那么最小子节点数为 8
        /// 最坏情况：
        /// 第一层：8 个子节点
        /// 第二层：8 * 8 = 64 个子节点
        /// 第三层：64 * 8 = 512 个子节点
        /// 第四层：512 * 8 = 4096 个子节点
        /// 第五层：4096 * 8 = 32768 个子节点
        /// 第六层：32768 * 8 = 262144 个子节点
        /// 第七层：262144 * 8 = 2097152 个子节点
        /// 第八层：叶子节点存储：2097152 * 7 = 14680064 个元素
        /// 累计共8层：
        /// - 总元素数为：14680064    约 1400 万
        /// - 总节点数为：2396745     约 200  万
        /// - 叶子节点数：2097152     约 200  万
        /// - 中间节点数：299593      约 30   万
        /// - 元素总数大概是节点数的 7 倍大小
        /// - 叶子节点数大概是中间节点的 7 倍大小
        /// - 每个叶子节点的 children 内存都是浪费的，   共浪费 24 * 2097152 字节 = 384MB
        /// - 每个中间节点的 values 和前后指针都是浪费的，共浪费 40 * 299593  字节 = 96MB
        /// - 总浪费内存：484MB 同样高度下比 BTree 多浪费 96MB，
        ///   拆分节点可以减少内存浪费，但是会带来性能损失和代码复杂度提升。
        ///
        /// - 如果 children 改为 Optional 类型，那么
        ///   - 中间节点会增加 8 * 299593 字节的内存
        ///   - 叶子节点会减少 16 * 2097152 字节的内存
        ///   - 一来一回会减少 16 * 2097152 - 8 * 299593 字节的内存 = 237MB
        ///   - 仍然是浪费了 8 * 2396745 + 48 * 299593 字节的内存 = 245 MB，但是效果还是挺明显的。
        ///
        /// 最佳情况：
        /// 第一层：16 个子节点
        /// 第二层：16 * 16 = 256 个子节点
        /// 第三层：256 * 16 = 4096 个子节点
        /// 第四层：4096 * 16 = 65536 个子节点
        /// 第五层：65536 * 16 = 1048576 个子节点
        /// 第六层：1048576 * 16 = 16777216 个子节点
        /// 第七层：16777216 * 16 = 268435456 个子节点
        /// 第八层：叶子节点存储：268435456 * 15 = 4026531840 个元素
        /// 累计共8层：
        /// - 总元素数为：4026531840  约 40  亿元素
        /// - 总节点数为：286331153   约 2   亿
        /// - 叶子节点数：268435456   约 2   亿
        /// - 中间节点数：17895696    约 1.7 千万
        /// - 元素总数大概是节点数的 15 倍大小
        /// - 叶子节点数大概是中间节点的 15 倍大小
        /// - 每个叶子节点的 children 内存都是浪费的，共浪费 24 * 268435456 字节 = 48GB
        /// - 每个中间节点的 values 和前后指针都是浪费的，共浪费 40 * 17895696 字节 = 5.5GB
        /// - 总浪费内存：53.5GB 同样高度下比 BTree 多浪费 5.5GB
        ///
        /// 286331153 * 8
        /// 268435456 * 8 + 17895696 * 48
        /// 拆分节点相比不拆分 + children使用 Optional 类型节省大概 5G 的内存
        /// 摊下来
        /// - 一个元素多浪费 1.5 bytes
        /// - 一个节点多浪费 20  bytes
        ///
        
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
    
    // MARK: - 描述
    
    @Test("test description")
    func testDescription() async throws {
        /// 按顺序插入，基本上对于查询和内存是最坏情况，基本上每一个叶子节点元素都是最小值。
        let tree = BPlusTree<Int, Int>(order: 4)
        let expected = """
        BPlusTree:
        - Height: 0
        - Number of elements: 0
        - Order: 4 (maximum number of children per node)
        """
        #expect(tree.description == expected)
    }
    
    // MARK: - 树的高度
    @Test("test tree height")
    func testTreeHeight() async throws {
        /// 这里使用批量加载的方式测试，因为批量加载得到的树是满的，可以通过计算叶子节点数来计算树的高度。
        /// 因为 BPlusTree 所有内容都存储在叶子节点中，所以当满树时，叶子节点数 = 元素数 / (order - 1)
        /// 
        /// 8 阶树，order = 8，叶子节点数 = 元素数 / 7 所以当元素数为 7 的倍数时，树就是满树。
        /// 8 个节点创建一个上层节点，所以每层节点是 8 的幂次。
        /// 第一层： 1
        /// 第二层： 8
        /// 第三层： 64
        /// 第四层： 512
        /// 如果层高为 4 层，那么叶子节点数 = 512，元素数 = 512 * 7 = 3584
       
       let elements = [Int](0 ..< 3584).map { ($0, $0 * 10) }
       let tree = BPlusTree<Int, Int>(contentsOf: elements, order: 8)
       #expect(tree.height == 4)

       /// 此时插入一个元素，树的高度会变为 5 层
       tree.insert(key: 3584, value: 3584 * 10)
       #expect(tree.height == 5)

       /// clear
       tree.clear()
       #expect(tree.height == 0)
    }
    
    // MARK: - OrderedCollection 协议测试也是基础功能测试
    
    /// 通过此测试只能代表其基本功能没啥问题，一些跨节点的细节是测不到的。
    @Suite("BPlusTree OrderedCollection protocol tests")
    struct BPlusTreeOrderedCollectionProtocolTests: OrderedCollectionTests {
        func factory() -> BPlusTree<Int, Int> {
            return BPlusTree<Int, Int>(order: 3)
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
    

    // MARK: - Bottom-Up 插入
    /// case:
    ///  1. insert-没有分裂
    ///  2. insert-叶子节点分裂
    ///  3. insert-内部节点分裂
    ///  4. upsert-insert-没有分裂
    ///  5. upsert-insert-叶子节点分裂
    ///  6. upsert-insert-内部节点分裂
    ///
    ///  subscripts 只是对 search、upsert、insert 的封装，就不测试了。
    @Suite("BPlusTree bottom-up insert tests")
    struct BPlusTreeBottomUpInsertTests {
        func runInsertNotSplit(_ callback: (BPlusTree<Int, Int>, Int, Int) -> Void)  {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 8,13])
            var expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 34, 340)
            
            expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33 34
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
            
        }
        func runInsertLeafNodeSplit(_ callback: (BPlusTree<Int, Int>, Int, Int) -> Void)  {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 8,13])
            var expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 50, 500)
            
            expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38 46
                ├── 8 13 23
                ├── 33
                ├── 38
                └── 46 50 78
            """
            #expect(tree.debugDescription == expected)
        }
        func runInsertInnerNodeSplit(_ callback: (BPlusTree<Int, Int>, Int, Int) -> Void)  {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 8,13, 50])
            var expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38 46
                ├── 8 13 23
                ├── 33
                ├── 38
                └── 46 50 78
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 56, 560)
            
            expected = """
            8 38
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            ├── 33
            │   ├── 8 13 23
            │   └── 33
            └── 46 50
                ├── 38
                ├── 46
                └── 50 56 78
            """
            #expect(tree.debugDescription == expected)
        }
        
        func runInsertInnerNodeSplitContinuous(_ callback: (BPlusTree<Int, Int>, Int, Int) -> Void)  {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 8,13, 50, 56, 57, 61, 62])
            var expected = """
            8 38 50
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            ├── 33
            │   ├── 8 13 23
            │   └── 33
            ├── 46
            │   ├── 38
            │   └── 46
            └── 56 57 61
                ├── 50
                ├── 56
                ├── 57
                └── 61 62 78
            """
            #expect(tree.debugDescription == expected)
            
            callback(tree, 75, 750)
            
            expected = """
            38
            ├── 8
            │   ├── 5
            │   │   ├── 1 2 3
            │   │   └── 5
            │   └── 33
            │       ├── 8 13 23
            │       └── 33
            └── 50 57
                ├── 46
                │   ├── 38
                │   └── 46
                ├── 56
                │   ├── 50
                │   └── 56
                └── 61 62
                    ├── 57
                    ├── 61
                    └── 62 75 78
            """
            #expect(tree.debugDescription == expected)
        }
        

        @Test("test insert not split")
        func testInsertNotSplit() async throws {
            runInsertNotSplit { tree, key, value in
                tree.insert(key: key, value: value)
            }
        }

        @Test("test insert leaf node split")
        func testInsertLeafNodeSplit() async throws {
            runInsertLeafNodeSplit { tree, key, value in
                tree.insert(key: key, value: value)
            }
        }

        @Test("test insert inner node split")
        func testInsertInnerNodeSplit() async throws {
            runInsertInnerNodeSplit { tree, key, value in
                tree.insert(key: key, value: value)
            }
        }

        @Test("test insert inner node split continuous")
        func testInsertInnerNodeSplitContinuous() async throws {
            runInsertInnerNodeSplitContinuous { tree, key, value in
                tree.insert(key: key, value: value)
            }
        }

        @Test("test upsert insert not split")
        func testUpsertInsertNotSplit() async throws {
            runInsertInnerNodeSplit { tree, key, value in
                tree.upsert(key: key, value: value)
            }
        }

        @Test("test upsert insert leaf node split")
        func testUpsertInsertLeafNodeSplit() async throws {
            runInsertLeafNodeSplit { tree, key, value in
                tree.upsert(key: key, value: value)
            }
        }

        @Test("test upsert insert inner node split")
        func testUpsertInsertInnerNodeSplit() async throws {
            runInsertInnerNodeSplit { tree, key, value in
                tree.upsert(key: key, value: value)
            }
        }

        @Test("test upsert insert inner node split continuous")
        func testUpsertInsertInnerNodeSplitContinuous() async throws {
            runInsertInnerNodeSplitContinuous { tree, key, value in
                tree.upsert(key: key, value: value)
            }
        }
    }

    // MARK: - Top-Down 删除
    /// case:
    ///  1. remove-内部节点-触发左借用
    ///  2. remove-内部节点-触发右借用
    ///  3. remove-内部节点-触发左合并
    ///  4. remove-内部节点-触发右合并
    ///  5. remove-叶子节点-触发左借用
    ///  6. remove-叶子节点-触发右借用
    ///  7. remove-叶子节点-触发左合并
    ///  8. remove-叶子节点-触发右合并
    ///  9. remove-叶子节点-通过 prev 跨父节点借用
    ///  9. remove-不触发借用或合并
    /// 10. remove-目标 key 在内部节点出现，需要交互至叶子节点再删除
    ///
    /// subscript 只是对 search、upsert、remove 的封装，就不测试了。
    @Suite("BPlusTree top-down remove tests")
    struct BPlusTreeStructureChangeTests {
        @Test("test remove not trigger borrow or merge")
        func testRemoveNotTriggerBorrowOrMerge() async throws {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 8,13])
            var expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 46)
            
            expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 78
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove inner node trigger left borrow")
        func testRemoveInnerNodeTriggerLeftBorrow() async throws {
            let tree = buildTree(order: 4, keys: [5, 6, 17 , 19, 20, 21, 22, 23, 24,25 , 26, 27, 1, 2, 3, 4, 8, 9, 18])
            var expected = """
            17 20 22
            ├── 2 3 6
            │   ├── 1
            │   ├── 2
            │   ├── 3 4 5
            │   └── 6 8 9
            ├── 19
            │   ├── 17 18
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24 25
                ├── 22
                ├── 23
                ├── 24
                └── 25 26 27
            """
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 18)
            
            expected = """
            6 20 22
            ├── 2 3
            │   ├── 1
            │   ├── 2
            │   └── 3 4 5
            ├── 17 19
            │   ├── 6 8 9
            │   ├── 17
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24 25
                ├── 22
                ├── 23
                ├── 24
                └── 25 26 27
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test remove inner node trigger right borrow")
        func testRemoveInnerNodeTriggerRightBorrow() async throws {
            let tree = buildTree(order: 4, keys: [5, 8,9, 1, 38, 46,33,  3, 78, 2])
            var expected = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 9 33 38
                ├── 8
                ├── 9
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
            
            // 叶子节点无需借用或合并，但是内部节点需要右借用
            tree.remove(key: 3)
            
            expected = """
            9
            ├── 5 8
            │   ├── 1 2
            │   ├── 5
            │   └── 8
            └── 33 38
                ├── 9
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test remove inner node trigger left merge")
        func testRemoveInnerNodeTriggerLeftMerge() async throws {
            let tree = buildTree(order: 4, keys: [5, 6, 17 , 19, 20, 21, 22,  1, 2, 23, 24, 25, 26, 18])
            var expected = """
            17 20 22
            ├── 6
            │   ├── 1 2 5
            │   └── 6
            ├── 19
            │   ├── 17 18
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24
                ├── 22
                ├── 23
                └── 24 25 26
            """
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 18)
            
            expected = """
            20 22
            ├── 6 17 19
            │   ├── 1 2 5
            │   ├── 6
            │   ├── 17
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24
                ├── 22
                ├── 23
                └── 24 25 26
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test remove inner node trigger right merge")
        func testRemoveInnerNodeTriggerRightMerge() async throws {
            let tree = buildTree(order: 4, keys: [5, 6, 17 , 19, 20, 21, 22,  1, 2, 23, 24, 25, 26, 18])
            var expected = """
            17 20 22
            ├── 6
            │   ├── 1 2 5
            │   └── 6
            ├── 19
            │   ├── 17 18
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24
                ├── 22
                ├── 23
                └── 24 25 26
            """
            #expect(tree.debugDescription == expected)
            
            tree.remove(key: 5)
            
            expected = """
            20 22
            ├── 6 17 19
            │   ├── 1 2
            │   ├── 6
            │   ├── 17 18
            │   └── 19
            ├── 21
            │   ├── 20
            │   └── 21
            └── 23 24
                ├── 22
                ├── 23
                └── 24 25 26
            """
            #expect(tree.debugDescription == expected)
        }

        
        
        @Suite("target key in inner node")
        struct BPlusTreeRemoveTests1 {
            @Test("test remove leaf node trigger left borrow")
            func testRemoveLeafNodeTriggerLeftBorrow() async throws {
                let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 13])
                var expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 38
                    ├── 8 13 23
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
                
                /// 优先左借用
                tree.remove(key: 33)
                
                expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 23 38
                    ├── 8 13
                    ├── 23
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
            }

            @Test("test remove leaf node trigger right borrow")
            func testRemoveLeafNodeTriggerRightBorrow() async throws {
                let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33,  3, 78, 2])
                var expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 38
                    ├── 8
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
                
                tree.remove(key: 33)
                
                /// 按照借用的规则父节点会变为 33 46
                /// 为啥不更新为 38 46 呢，因为 B+Tree 允许被删除的 key 仍然存在于内部节点，因为此状态没有破坏 B+Tree 的定义。
                expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 46
                    ├── 8
                    ├── 38
                    └── 46 78
                """
                #expect(tree.debugDescription == expected)
                
                /// 插入一个值，可以观察到其结果都是正确的。
                tree.insert(key: 35, value: 350)
                
                expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 46
                    ├── 8
                    ├── 35 38
                    └── 46 78
                """
                #expect(tree.debugDescription == expected)
            }

            @Test("test remove leaf node trigger left merge")
            func testRemoveLeafNodeTriggerLeftMerge() async throws {
                let tree = buildTree(order: 4, keys: [5, 8,9, 1, 38, 46,33,  3, 78, 2])
                var expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 9 33 38
                    ├── 8
                    ├── 9
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
                
                /// 优先左合并
                tree.remove(key: 9)
                
                expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 38
                    ├── 8
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
            }

            @Test("test remove leaf node trigger right merge")
            func testRemoveLeafNodeTriggerRightMerge() async throws {
                let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33,  3, 78, 2])
                var expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 33 38
                    ├── 8
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
                
                tree.remove(key: 8)
                
                expected = """
                8
                ├── 5
                │   ├── 1 2 3
                │   └── 5
                └── 38
                    ├── 33
                    └── 38 46 78
                """
                #expect(tree.debugDescription == expected)
            }
        }
        

        @Suite("target key not in inner node")
        struct BPlusTreeRemoveTests2 {
            @Test("test remove leaf node trigger right borrow")
            func testRemoveLeafNodeTriggerRightBorrow() async throws {
                let tree = buildTree(order: 5, keys: [5, 8, 1, 38, 46,33,  3, 78, 2, 34, 76, 81, 83, 85, 87, 89, 91, 92, 93, 94, 95])
                var expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 89 92
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87
                    ├── 89 91
                    └── 92 93 94 95
                """
                #expect(tree.debugDescription == expected)
                
                tree.remove(key: 91)
                
                expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 89 93
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87
                    ├── 89 92
                    └── 93 94 95
                """
                #expect(tree.debugDescription == expected)
            }
            
            @Test("test remove leaf node trigger left borrow")
            func testRemoveLeafNodeTriggerLeftBorrow() async throws {
                let tree = buildTree(order: 5, keys: [5, 8, 1, 38, 46,33,  3, 78, 2, 34, 76, 81, 83, 85, 87, 89, 91, 92, 93, 94,88])
                var expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 89 92
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87 88
                    ├── 89 91
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
                
                tree.remove(key: 91)
                
                expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 88 92
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87
                    ├── 88 89
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
            }

            @Test("test remove leaf node trigger left merge")
            func testRemoveLeafNodeTriggerLeftMerge() async throws {
                
                let tree = buildTree(order: 5, keys: [5, 8, 1, 38, 46,33,  3, 78, 2, 34, 76, 81, 83, 85, 87, 89, 91, 92, 93, 94])
                var expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 89 92
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87
                    ├── 89 91
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
                
                /// 优先左合并
                tree.remove(key: 83)
                
                expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 85 89 92
                    ├── 76 78 81
                    ├── 85 87
                    ├── 89 91
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
            }

            @Test("test remove leaf node trigger right merge")
            func testRemoveLeafNodeTriggerRightMerge() async throws {
                let tree = buildTree(order: 5, keys: [5, 8, 1, 38, 46,33,  3, 78, 2, 34, 76, 81, 83, 85, 87, 89, 91, 92, 93, 94])
                var expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 81 85 89 92
                    ├── 76 78
                    ├── 81 83
                    ├── 85 87
                    ├── 89 91
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
                
                tree.remove(key: 78)
                
                expected = """
                76
                ├── 8 38
                │   ├── 1 2 3 5
                │   ├── 8 33 34
                │   └── 38 46
                └── 85 89 92
                    ├── 76 81 83
                    ├── 85 87
                    ├── 89 91
                    └── 92 93 94
                """
                #expect(tree.debugDescription == expected)
            }
        }
    }
    
    // MARK: - 批量加载
    @Suite("BPlusTree bulk load tests")
    struct BPlusTreeBulkLoadTests {
        /// case:
        /// 1. 插入的元素数量小于等于 order
        /// 2. 叶子节点的最后一个节点不满，需要与前一个节点进行再分配
        /// 3. 叶子节点的最后一个节点刚好满。
        /// 4. 某一层的内部节点最后一个节点不满，需要与前一个节点进行再分配
        /// 5. 某一层的内部节点最后一个节点刚好满
        /// 6. 某一层的内部节点数少于等于 order
        
        @Test("test bulk load with elements less than order")
        func testBulkLoadWithElementsLessThanOrder() async throws {
            /// 插入的数量小于 order 此时应该只创建一个叶子根节点
            let tree = BPlusTree<Int, Int>(contentsOf: Array(1...3).map({($0, $0 * 10)}), order: 4)
            let expected = "1 2 3"
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test bulk load with elements equal to order")
        func testBulkLoadWithElementsEqualOrder() async throws {
            /// 插入的数量等于 order 此时需要拆分成两个节点
            let tree = BPlusTree<Int, Int>(contentsOf: Array(1...5).map({($0, $0 * 10)}), order: 5)
            let expected = """
            3
            ├── 1 2
            └── 3 4 5
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test bulk load with leaf node last node not full")
        func testBulkLoadWithLeafNodeLastNodeNotFull() async throws {
            /// 批量加载时以 order-1 一组创建满叶子节点，如果最后一个叶子节点不足 minKeys 则需要与前一个节点进行再分配
            
            
            /// order = 5 minKeys = 2 此处刚好多一个需要再分配
            var tree = BPlusTree<Int, Int>(contentsOf: Array(1...13).map({($0, $0 * 10)}), order: 5)
            
            var expected = """
            5 9 11
            ├── 1 2 3 4
            ├── 5 6 7 8
            ├── 9 10
            └── 11 12 13
            """
            #expect(tree.debugDescription == expected)
            
            // order = 5 minKeys = 2 此处多两个刚好等于 minKeys 则无需再分配
            tree = BPlusTree<Int, Int>(contentsOf: Array(1...14).map({($0, $0 * 10)}), order: 5)
            expected = """
            5 9 13
            ├── 1 2 3 4
            ├── 5 6 7 8
            ├── 9 10 11 12
            └── 13 14
            """
            #expect(tree.debugDescription == expected)
        
        }
        
        @Test("test bulk load with leaf node last node full")
        func testBulkLoadWithLeafNodeLastNodeFull() async throws {
            let tree = BPlusTree<Int, Int>(contentsOf: Array(1...16).map({($0, $0 * 10)}), order: 5)
            
            let expected = """
            5 9 13
            ├── 1 2 3 4
            ├── 5 6 7 8
            ├── 9 10 11 12
            └── 13 14 15 16
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test bulk load with inner node last node not full")
        func testBulkLoadWithInnerNodeLastNodeNotFull() async throws {
            /// 此处元素 24 叶子节点满，内部节点数为 6 第二个内部节点只能分配一个子节点，小于 minChildren 3，需要再分配
            var tree = BPlusTree<Int, Int>(contentsOf: Array(1...24).map({($0, $0 * 10)}), order: 5)
            
            var expected = """
            13
            ├── 5 9
            │   ├── 1 2 3 4
            │   ├── 5 6 7 8
            │   └── 9 10 11 12
            └── 17 21
                ├── 13 14 15 16
                ├── 17 18 19 20
                └── 21 22 23 24
            """
            #expect(tree.debugDescription == expected)
            
            /// 此处第二个内部节点其子节点数小于 minChildren 但是等于 minKeys，需要再分配
            tree = BPlusTree<Int, Int>(contentsOf: Array(1...28).map({($0, $0 * 10)}), order: 5)
            
            expected = """
            13
            ├── 5 9
            │   ├── 1 2 3 4
            │   ├── 5 6 7 8
            │   └── 9 10 11 12
            └── 17 21 25
                ├── 13 14 15 16
                ├── 17 18 19 20
                ├── 21 22 23 24
                └── 25 26 27 28
            """
            #expect(tree.debugDescription == expected)
            
            /// 此处第二个内部节点子节点数等于 minChildren 无需再分配
            tree = BPlusTree<Int, Int>(contentsOf: Array(1...32).map({($0, $0 * 10)}), order: 5)
            
            expected = """
            21
            ├── 5 9 13 17
            │   ├── 1 2 3 4
            │   ├── 5 6 7 8
            │   ├── 9 10 11 12
            │   ├── 13 14 15 16
            │   └── 17 18 19 20
            └── 25 29
                ├── 21 22 23 24
                ├── 25 26 27 28
                └── 29 30 31 32
            """
            #expect(tree.debugDescription == expected)
        }
        
        @Test("test bulk load with inner node last node full")
        func testBulkLoadWithInnerNodeLastNodeFull() async throws {
            let tree = BPlusTree<Int, Int>(contentsOf: Array(1...40).map({($0, $0 * 10)}), order: 5)
            
            let expected = """
            21
            ├── 5 9 13 17
            │   ├── 1 2 3 4
            │   ├── 5 6 7 8
            │   ├── 9 10 11 12
            │   ├── 13 14 15 16
            │   └── 17 18 19 20
            └── 25 29 33 37
                ├── 21 22 23 24
                ├── 25 26 27 28
                ├── 29 30 31 32
                ├── 33 34 35 36
                └── 37 38 39 40
            """
            #expect(tree.debugDescription == expected)
        }

    }
    
    // MARK: - 跨节点的读操作
    /// BplusTree 的查询都是基于叶子节点的，而叶子节点通过指针连接，这里测试跨节点的读操作。
    /// case
    /// 1. range-起点与终点在不同的节点
    /// 2. range-起点与终点跨父节点范围。
    /// 3. successor-值在另一个节点
    /// 4. predecessor-值在另一个节点
    @Suite("BPlusTree cross-node read tests")
    struct BPlusTreeCrossNodeReadTests {
        @Test("test range", arguments: [
            /// 跨叶子节点
            (1, 5, [1, 2, 3, 5]),
            /// 跨父节点范围
            (1, 13, [1, 2, 3, 5, 8, 13]),
        ])
        func testRange(start: Int, end: Int, expected: [Int]) async throws {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 13])
            let debugDescription = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == debugDescription)
            
            
            let result = tree.range(in: start ... end)
            #expect(result.map({$0.0}) == expected)
        }

        @Test("test successor", arguments: [
            /// 跨叶子节点
            (3, 5),
            /// 跨父节点范围
            (5, 8),
            /// 不存在
            (78, nil),
        ])
        func testSuccessor(key: Int, expected: Int?) async throws {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 13])
            let debugDescription = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == debugDescription)
            
            #expect(tree.insert(key: 5, value: 50) == false)
            
            let result = tree.successor(key: key)
            #expect(tree.contains(key: key) == true)
            #expect(result?.0 == expected)
        }

        @Test("test predecessor", arguments: [
            /// 跨叶子节点
            (1, nil),
            /// 跨父节点范围
            (8, 6),
            /// 不存在
            (5, 3),
        ])
        func testPredecessor(key: Int, expected: Int?) async throws {
            let tree = buildTree(order: 4, keys: [5, 8, 1, 38, 46,33, 23, 3, 78, 2, 13, 6])
            let debugDescription = """
            8
            ├── 5
            │   ├── 1 2 3
            │   └── 5 6
            └── 33 38
                ├── 8 13 23
                ├── 33
                └── 38 46 78
            """
            #expect(tree.debugDescription == debugDescription)
            
            let result = tree.predecessor(key: key)
            #expect(result?.0 == expected)
        }
    }
}
