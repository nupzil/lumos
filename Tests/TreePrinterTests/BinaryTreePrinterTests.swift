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

import Testing
@testable import TreePrinter

/// 用于测试的二叉树节点实现
private final class BinaryTreeNode {
    var key: Int
    var left: BinaryTreeNode?
    var right: BinaryTreeNode?

    init(key: Int, left: BinaryTreeNode? = nil, right: BinaryTreeNode? = nil) {
        self.key = key
        self.left = left
        self.right = right
    }
}

/// 为测试的二叉树实现可打印协议
extension BinaryTreeNode: PrintableBinaryTreeProtocol {
    var lNode: BinaryTreeNode? { self.left }
    var rNode: BinaryTreeNode? { self.right }
    var displayName: String { self.key.description }
}

/// 二叉树测试数据工厂
private enum BinaryTreeFactory {
    /// 创建基本的三节点树
    static func createBasicTree() -> BinaryTreeNode {
        let root = BinaryTreeNode(key: 1)
        root.left = BinaryTreeNode(key: 2)
        root.right = BinaryTreeNode(key: 3)
        return root
    }
    
    /// 创建完全二叉树
    static func createCompleteBinaryTree() -> BinaryTreeNode {
        let root = BinaryTreeNode(key: 1)
        root.left = BinaryTreeNode(key: 2)
        root.right = BinaryTreeNode(key: 3)
        root.left?.left = BinaryTreeNode(key: 4)
        root.left?.right = BinaryTreeNode(key: 5)
        root.right?.left = BinaryTreeNode(key: 6)
        root.right?.right = BinaryTreeNode(key: 7)
        return root
    }
    
    /// 创建不平衡的右偏树
    static func createRightSkewedTree() -> BinaryTreeNode {
        let root = BinaryTreeNode(key: 1)
        root.left = BinaryTreeNode(key: 2)
        root.right = BinaryTreeNode(key: 3)
        root.right?.right = BinaryTreeNode(key: 4)
        root.right?.right?.right = BinaryTreeNode(key: 5)
        return root
    }
}

@Suite("Binary Tree Printer Tests")
struct BinaryTreePrinterTests {
    // MARK: - 目录样式测试
    
    @Suite("Directory Style Tests")
    struct DirectoryStyleTests {
        @Test("test print single node")
        func testPrintSingleNode() async throws {
            let root = BinaryTreeNode(key: 1)
            #expect(BinaryTreePrinter(root).print(style: .directory) == "└── 1")
        }
        
        @Test("test print basic tree")
        func testPrintBasicTree() async throws {
            let root = BinaryTreeFactory.createBasicTree()
            let expected = """
            └── 1
                ├── 2
                └── 3
            """
            #expect(BinaryTreePrinter(root).print(style: .directory) == expected)
        }
        
        @Test("test print complete binary tree")
        func testPrintCompleteBinaryTree() async throws {
            let root = BinaryTreeFactory.createCompleteBinaryTree()
            let expected = """
            └── 1
                ├── 2
                │   ├── 4
                │   └── 5
                └── 3
                    ├── 6
                    └── 7
            """
            #expect(BinaryTreePrinter(root).print(style: .directory) == expected)
        }

        @Test("test print right skewed tree")
        func testPrintRightSkewedTree() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
            └── 1
                ├── 2
                └── 3
                    ├── nil
                    └── 4
                        ├── nil
                        └── 5
            """
            #expect(BinaryTreePrinter(root).print(style: .directory) == expected)
        }

        @Test("test print with custom character")
        func testPrintWithCustomCharacter() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
            \\-- 1
                |-- 2
                \\-- 3
                    |-- 空
                    \\-- 4
                        |-- 空
                        \\-- 5
            """
            let printer = BinaryTreePrinter(root)
                .configure {
                    $0.characters.horizontal = "-"
                    $0.characters.cornerTopLeft = "/"
                    $0.characters.teeLeft = "|"
                    $0.characters.cornerBottomLeft = "\\"
                    $0.nilFiller = "空"
                }
            #expect(printer.print(style: .directory) == expected)
        }
    }
    
    // MARK: - 缩进样式测试
    
    @Suite("Indented Style Tests")
    struct IndentedStyleTests {
        @Test("test print single node")
        func testPrintSingleNode() async throws {
            let root = BinaryTreeNode(key: 1)
            #expect(BinaryTreePrinter(root).print(style: .indented) == "└── 1")
        }
        
        @Test("test print basic tree")
        func testPrintBasicTree() async throws {
            let root = BinaryTreeFactory.createBasicTree()
            let expected = """
            │   ┌── 3
            └── 1
                └── 2
            """
            #expect(BinaryTreePrinter(root).print(style: .indented) == expected)
        }
        
        @Test("test print complete binary tree")
        func testPrintCompleteBinaryTree() async throws {
            let root = BinaryTreeFactory.createCompleteBinaryTree()
            let expected = """
            │       ┌── 7
            │   ┌── 3
            │   │   └── 6
            └── 1
                │   ┌── 5
                └── 2
                    └── 4
            """
            #expect(BinaryTreePrinter(root).print(style: .indented) == expected)
        }

        @Test("test print right skewed tree")
        func testPrintRightSkewedTree() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
            │           ┌── 5
            │       ┌── 4
            │       │   └── nil
            │   ┌── 3
            │   │   │
            │   │   └── nil
            │   │
            └── 1
                │
                │
                │
                └── 2
            """
            #expect(BinaryTreePrinter(root).print(style: .indented) == expected)
        }

        @Test("test print with custom character")
        func testPrintWithCustomCharacter() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
            |           /-- 5
            |       /-- 4
            |       |   \\-- 空
            |   /-- 3
            |   |   |
            |   |   \\-- 空
            |   |
            \\-- 1
                |
                |
                |
                \\-- 2
            """
            let printer = BinaryTreePrinter(root)
                .configure {
                    $0.characters.horizontal = "-"
                    $0.characters.vertical = "|"
                    $0.characters.cornerTopLeft = "/"
                    $0.characters.cornerBottomLeft = "\\"
                    $0.nilFiller = "空"
                }
            #expect(printer.print(style: .indented) == expected)
        }
    }
    
    // MARK: - 垂直样式测试
    
    @Suite("Vertical Style Tests")
    struct VerticalStyleTests {
        @Test("test print single node")
        func testPrintSingleNode() async throws {
            let root = BinaryTreeNode(key: 1)
            #expect(BinaryTreePrinter(root).print(style: .vertical) == "1")
        }
        
        @Test("test print basic tree")
        func testPrintBasicTree() async throws {
            let root = BinaryTreeFactory.createBasicTree()
            let expected = """
             1
            ┌┴┐
            2 3
            """
            #expect(BinaryTreePrinter(root).print(style: .vertical) == expected)
        }

        @Test("test print complete binary tree")
        func testPrintCompleteBinaryTree() async throws {
            let root = BinaryTreeFactory.createCompleteBinaryTree()
            let expected = """
               1
             ┌─┴─┐
             2   3
            ┌┴┐ ┌┴┐
            4 5 6 7
            """
            #expect(BinaryTreePrinter(root).print(style: .vertical) == expected)
        }

        @Test("test print right skewed tree")
        func testPrintRightSkewedTree() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
                         1
             ┌───────────┴───────────┐
             2                       3
                               ┌─────┴─────┐
                              nil          4
                                        ┌──┴──┐
                                       nil    5
            """
            #expect(BinaryTreePrinter(root).print(style: .vertical) == expected)
        }
        
        @Test("test print with custom nil filler")
        func testPrintWithCustomNilFiller() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            let expected = """
                1
            ┌───┴───┐
            2       3
                  ┌─┴─┐
                  -   4
                     ┌┴┐
                     - 5
            """
            
            let printer = BinaryTreePrinter(root)
                .configure {
                    $0.nilFiller = "-"
                }
            
            #expect(printer.print(style: .vertical) == expected)
        }
        
        @Test("test print with custom character")
        func testPrintWithCustomCharacter() async throws {
            let root = BinaryTreeFactory.createRightSkewedTree()
            /// 输出中对不同内容是有不一样的字符串填充方式的
            /// - 如果是 ┴ 会左右填充 ─
            /// - 如果是 ┐ 会在左边填充 ─ 右边填充空格
            /// - 如果是 ┌ 会在左边填充空格，右边填充 ─
            /// - 其他字符会在左右两边都填充空格
            /// - 内容的左空格是不会被删除的：如 2 左边存在空格
            let expected = """
                         1
             /-----------+-----------`
             2                       3
                               /-----+-----`
                              nil          4
                                        /--+--`
                                       nil    5
            """
            
            let printer = BinaryTreePrinter(root)
                .configure {
                    $0.nilFiller = "nil"
                    $0.characters.horizontal = "-"
                    $0.characters.cornerTopLeft = "/"
                    $0.characters.cornerTopRight = "`"
                    $0.characters.teeBottom = "+"
                }
            #expect(printer.print(style: .vertical) == expected)
        }
    }
}
