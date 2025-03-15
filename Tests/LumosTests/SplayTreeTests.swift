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

@testable import Lumos
import Testing
@testable import TreePrinter

/// 测试用辅助方法
private enum SplayTreeFactory {
    static func build(values: [Int]) -> SplayTree<Int, Int> {
        let tree = SplayTree<Int, Int>()
        for value in values {
            _ = tree.insert(key: value, value: value)
        }
        return tree
    }
}

@Suite("SplayTree Tests")
struct SplayTreeTests {
    @Test("test SplayTree description")
    func testSplayTreeDescription() async throws {
        let tree = SplayTree<Int, Int>()
        var expected = """
        SplayTree:
        - Number of elements: 0
        - Root key: nil
        """
        #expect(tree.description == expected)

        tree.insert(key: 6, value: 60)
        expected = """
        SplayTree:
        - Number of elements: 1
        - Root key: 6
        """
        #expect(tree.description == expected)

        tree.insert(key: 2, value: 20)
        expected = """
        SplayTree:
        - Number of elements: 2
        - Root key: 2
        """
        #expect(tree.description == expected)

        tree.remove(key: 2)
        expected = """
        SplayTree:
        - Number of elements: 1
        - Root key: 6
        """
        #expect(tree.description == expected)
    }

    // MARK: - OrderedCollection 协议测试

    /// 通过此测试只能代表其基本功能没啥问题，一些跨节点的细节是测不到的。
    @Suite("SplayTree OrderedCollection protocol tests")
    struct SplayTreeOrderedCollectionProtocolTests: OrderedCollectionTests {
        func factory() -> SplayTree<Int, Int> {
            return SplayTree<Int, Int>()
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

    // MARK: - 可能导致 SplayTree 树结构发生变化的场景

    @Suite("SplayTree Structure change tests")
    struct SplayTreeStructureChangeTests {
        // 核心的 splay 操作的一些场景，SplayTree 的结构变更主要是由此方法控制。

        @Test("test splay case 1 zig - right rotation")
        func testSplayCase1() async throws {
            let tree = SplayTreeFactory.build(values: [2, 3])
            var expected = """
            │   ┌── nil
            └── 3
                └── 2
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 2)

            expected = """
            │   ┌── 3
            └── 2
                └── nil
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test splay case 2 zag - left rotation")
        func testSplayCase2() async throws {
            let tree = SplayTreeFactory.build(values: [2, 3])
            _ = tree.search(key: 2)
            var expected = """
            │   ┌── 3
            └── 2
                └── nil
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 3)
            expected = """
            │   ┌── nil
            └── 3
                └── 2
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test splay case 3 zig-zig - two right rotation")
        func testSplayCase3() async throws {
            let tree = SplayTreeFactory.build(values: [2, 3, 4])
            var expected = """
            │   ┌── nil
            │   │
            └── 4
                │   ┌── nil
                └── 3
                    └── 2
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 2)
            expected = """
            │       ┌── 4
            │   ┌── 3
            │   │   └── nil
            └── 2
                │
                └── nil
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test splay case 4 zig-zag - two left rotation")
        func testSplayCase4() async throws {
            let tree = SplayTreeFactory.build(values: [2, 3, 4])
            _ = tree.search(key: 2)
            var expected = """
            │       ┌── 4
            │   ┌── 3
            │   │   └── nil
            └── 2
                │
                └── nil
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 4)
            expected = """
            │   ┌── nil
            │   │
            └── 4
                │   ┌── nil
                └── 3
                    └── 2
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test splay case 5 zag-zig - left + right")
        func testSplayCase5() async throws {
            let tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15, 50])
            var expected = """
            │   ┌── nil
            │   │
            │   │
            │   │
            │   │
            │   │
            │   │
            │   │
            └── 50
                │
                │
                │
                │   ┌── nil
                │   │
                │   │
                │   │
                └── 40
                    │
                    │   ┌── nil
                    │   │
                    └── 30
                        │   ┌── 20
                        └── 15
                            └── 10
            """

            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 20)
            expected = """
            │       ┌── 50
            │   ┌── 40
            │   │   └── 30
            └── 20
                │   ┌── nil
                └── 15
                    └── 10
            """
            #expect(tree.debugDescription == expected)
        }

        @Test("test splay case 6 zag-zag - right + left")
        func testSplayCase6() async throws {
            let tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            var expected = """
            │       ┌── 40
            │   ┌── 30
            │   │   └── 20
            └── 15
                │
                └── 10
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 20)
            expected = """
            │       ┌── 40
            │   ┌── 30
            │   │   └── nil
            └── 20
                │   ┌── nil
                └── 15
                    └── 10
            """
            #expect(tree.debugDescription == expected)
        }

        // 一个 splay 操作的重要特性：最后访问的元素会位于 root
        @Test("test splay case 7 element not in tree")
        func testSplayCase7() async throws {
            var tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            var expected = """
            │       ┌── 40
            │   ┌── 30
            │   │   └── 20
            └── 15
                │
                └── 10
            """
            #expect(tree.debugDescription == expected)

            _ = tree.search(key: 0)
            expected = """
            │           ┌── 40
            │       ┌── 30
            │       │   └── 20
            │   ┌── 15
            │   │   │
            │   │   └── nil
            │   │
            └── 10
                │
                │
                │
                └── nil
            """
            #expect(tree.debugDescription == expected)

            tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            _ = tree.search(key: 50)
            expected = """
            │   ┌── nil
            │   │
            │   │
            │   │
            └── 40
                │
                │   ┌── nil
                │   │
                └── 30
                    │   ┌── 20
                    └── 15
                        └── 10
            """
            #expect(tree.debugDescription == expected)

            tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            _ = tree.search(key: 16)
            expected = """
            │       ┌── 40
            │   ┌── 30
            │   │   └── nil
            └── 20
                │   ┌── nil
                └── 15
                    └── 10
            """
            #expect(tree.debugDescription == expected)

            tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            _ = tree.search(key: 29)
            expected = """
            │       ┌── 40
            │   ┌── 30
            │   │   └── nil
            └── 20
                │   ┌── nil
                └── 15
                    └── 10
            """
            #expect(tree.debugDescription == expected)

            tree = SplayTreeFactory.build(values: [10, 20, 30, 40, 15])
            _ = tree.search(key: 14)
            expected = """
            │           ┌── 40
            │       ┌── 30
            │       │   └── 20
            │   ┌── 15
            │   │   │
            │   │   └── nil
            │   │
            └── 10
                │
                │
                │
                └── nil
            """
            #expect(tree.debugDescription == expected)
        }

        /// SplayTree 的大部分操作都会修改树结构
    }

    // MARK: - Test Self-adjusting

    @Suite("SplayTree Self-Adjusting Tests")
    struct SplayTreeSelfAdjustingTests {
        func verifySplayBehavior(_ tree: SplayTree<Int, Int>, expected: Int, message: String) {
            #expect(tree.root?.key == expected, "\(message)")
        }

        @Test("test SplayTree Behavior")
        func testSplayBehavior() async throws {
            let testCases: [((SplayTree<Int, Int>) -> Void, Int, String)] = [
                /// min、max、keys、values、elements、reversed、elementsSequence、reversedSequence 都是只读的
                ({ tree in _ = tree.min }, 4, "min"),
                ({ tree in _ = tree.max }, 4, "max"),
                /// search、contains、floor、ceiling、predecessor、successor 都会对传入的 key 进行 splay
                ({ tree in _ = tree.search(key: 3) }, 3, "search(key: 3)"),
                // 此时 root 不一定会是最接近它的值，可能是它的上一层的值。
                ({ tree in _ = tree.search(key: 8) }, 7, "search(key: 8)"),
                ({ tree in _ = tree.contains(key: 3) }, 3, "contains(key: 3)"),
                ({ tree in _ = tree.contains(key: 8) }, 7, "contains(key: 8)"),
                ({ tree in _ = tree.floor(key: 3) }, 3, "floor(key: 3)"),
                ({ tree in _ = tree.ceiling(key: 3) }, 3, "ceiling(key: 3)"),
                ({ tree in _ = tree.predecessor(key: 3) }, 3, "predecessor(key: 3)"),
                ({ tree in _ = tree.successor(key: 3) }, 3, "successor(key: 3)"),
                /// range 会对 lowerBound 执行 splay
                ({ tree in _ = tree.range(in: 3 ... 7) }, 3, "successor(key: 3)"),
                ({ tree in _ = tree.range(in: 8 ... 10) }, 7, "successor(key: 3)"),
                /// traverse、reversedTraverse、map、compactMap、reduce、reduce(into:) 都是只读的
            ]

            for (operation, expected, message) in testCases {
                let tree = SplayTree<Int, Int>()
                tree.insert(key: 1, value: 10)
                tree.insert(key: 2, value: 20)
                tree.insert(key: 5, value: 50)
                tree.insert(key: 6, value: 60)
                tree.insert(key: 7, value: 70)
                tree.insert(key: 3, value: 30)
                tree.insert(key: 4, value: 40)

                operation(tree)
                verifySplayBehavior(tree, expected: expected, message: message)
            }
        }
    }

    // MARK: - 树的分割与合并测试

    @Suite("SplayTree Split And Join Tests")
    struct SplayTreeSplitAndJoinTests {
        @Test("test split")
        func testSplit() async throws {
            var tree = SplayTree<Int, Int>()

            // 对空树进行 split 返回两颗空树
            let (l, r) = tree.split(at: 5)

            #expect(tree.isEmpty)
            #expect(tree.count == 0)
            #expect(l.isEmpty)
            #expect(l.count == 0)

            #expect(r.isEmpty)
            #expect(r.count == 0)

            tree = SplayTreeFactory.build(values: [1, 2, 3, 4, 6, 7, 8, 9])

            #expect(tree.count == 8)

            // 测试以存在于 tree 中的 key 作为参数
            let (left, right) = tree.split(at: 6)

            // 树 split 后原树将不可用
            #expect(tree.isEmpty)
            #expect(tree.count == 0)

            #expect(left.count == 4)
            #expect(left.keys == [1, 2, 3, 4])
            #expect(left.values == [1, 2, 3, 4])
            #expect(left.elements.elementsEqual([(1, 1), (2, 2), (3, 3), (4, 4)], by: ==))

            var expected = """
            │   ┌── nil
            │   │
            │   │
            │   │
            └── 4
                │
                │   ┌── nil
                │   │
                └── 3
                    │   ┌── nil
                    └── 2
                        └── 1
            """

            #expect(left.debugDescription == expected)

            #expect(right.count == 4)
            #expect(right.keys == [6, 7, 8, 9])
            #expect(right.values == [6, 7, 8, 9])
            #expect(right.elements.elementsEqual([(6, 6), (7, 7), (8, 8), (9, 9)], by: ==))

            expected = """
            │       ┌── 9
            │   ┌── 8
            │   │   └── 7
            └── 6
                │
                └── nil
            """

            #expect(right.debugDescription == expected)

            tree = SplayTreeFactory.build(values: [1, 2, 3, 4, 6, 7, 8, 9])

            // 测试不存在于 tree 中的 key 作为参数（结果应该与 key == 6 相同）
            let (left2, right2) = tree.split(at: 5)

            // 树 split 后原树将不可用
            #expect(tree.isEmpty)
            #expect(tree.count == 0)

            #expect(left2.count == 4)
            #expect(left2.keys == [1, 2, 3, 4])
            #expect(left2.values == [1, 2, 3, 4])
            #expect(left2.elements.elementsEqual([(1, 1), (2, 2), (3, 3), (4, 4)], by: ==))
            expected = """
            │   ┌── nil
            │   │
            │   │
            │   │
            └── 4
                │
                │   ┌── nil
                │   │
                └── 3
                    │   ┌── nil
                    └── 2
                        └── 1
            """

            #expect(left2.debugDescription == expected)

            #expect(right2.count == 4)
            #expect(right2.keys == [6, 7, 8, 9])
            #expect(right2.values == [6, 7, 8, 9])
            #expect(right2.elements.elementsEqual([(6, 6), (7, 7), (8, 8), (9, 9)], by: ==))
            expected = """
            │   ┌── 9
            │   │
            └── 8
                │   ┌── 7
                └── 6
                    └── nil
            """

            #expect(right2.debugDescription == expected)
        }

        @Test("test join")
        func testJoin() async throws {
            let tree = SplayTree<Int, Int>()

            let right1 = SplayTreeFactory.build(values: [1, 2, 3])

            /// 空树 join
            #expect(tree.join(with: right1))

            // 右树合并后将不可用
            #expect(right1.isEmpty)
            #expect(right1.count == 0)

            // 左树即 self 将增加节点
            #expect(tree.count == 3)
            #expect(tree.keys == [1, 2, 3])

            var expected = """
            │   ┌── nil
            │   │
            └── 3
                │   ┌── nil
                └── 2
                    └── 1
            """
            #expect(tree.debugDescription == expected)

            // join 一棵空树
            let right2 = SplayTree<Int, Int>()
            #expect(tree.join(with: right2))
            #expect(tree.count == 3)
            #expect(tree.keys == [1, 2, 3])

            // join 一棵非法的树（左树最大值大于等于右树最小值）
            let right3 = SplayTreeFactory.build(values: [3, 4, 5])
            #expect(tree.join(with: right3) == false)
            #expect(tree.count == 3)
            #expect(tree.keys == [1, 2, 3])

            // 左树非空时 join
            let right4 = SplayTreeFactory.build(values: [5, 6, 7, 4])
            #expect(tree.join(with: right4) == true)

            #expect(right4.isEmpty)
            #expect(right4.count == 0)

            #expect(tree.count == 7)
            #expect(tree.keys == [1, 2, 3, 4, 5, 6, 7])

            expected = """
            │               ┌── 7
            │           ┌── 6
            │           │   └── nil
            │       ┌── 5
            │       │   │
            │       │   └── nil
            │       │
            │   ┌── 4
            │   │   │
            │   │   │
            │   │   │
            │   │   └── nil
            │   │
            │   │
            │   │
            └── 3
                │
                │
                │
                │   ┌── nil
                │   │
                │   │
                │   │
                └── 2
                    │
                    │
                    │
                    └── 1
            """

            #expect(tree.debugDescription == expected)
        }
    }

    // MARK: - SplayTree 一些不存在 OrderedCollection 协议中的只读功能

    @Suite("SplayTree deep clone tests")
    struct SplayTreeDeepCloneTests {
        @Test("test clone")
        func testClone() async throws {
            let tree = SplayTreeFactory.build(values: [1, 3, 4, 2])
            #expect(tree.keys == [1, 2, 3, 4])
            #expect(tree.values == [1, 2, 3, 4])
            let expected = """
            │       ┌── 4
            │   ┌── 3
            │   │   └── nil
            └── 2
                │
                └── 1
            """
            #expect(tree.debugDescription == expected)

            let tree2 = tree.clone()
            // 验证新的 tree 结构是否正确
            #expect(tree.elements.elementsEqual(tree2.elements, by: ==))
            #expect(tree.debugDescription == expected)

            // 修改 tree 的值，看指向的数据是否没有关系了。
            for value in 1 ... 4 {
                tree.update(key: value, value: value * 10)
            }
            // 修改是否成功
            #expect(tree.values == [10, 20, 30, 40])

            // 值是否没有影响
            #expect(tree2.values == [1, 2, 3, 4])
            // 结构是否没有影响
            #expect(tree2.debugDescription == expected)
        }
    }
}
