//
//  Created by vvgvjks on 2025/2/16.
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

import Testing
@testable import TreePrinter

/// 用于测试的多叉树节点实现
private final class MultiwayTreeNode {
    var keys: [Int] = []
    var children: [MultiwayTreeNode] = []

    init(keys: [Int] = [], children: [MultiwayTreeNode] = []) {
        self.keys = keys
        self.children = children
    }

    func addChild(_ child: MultiwayTreeNode) {
        children.append(child)
    }
}

/// 为测试多叉树实现可打印协议
extension MultiwayTreeNode: PrintableMultiwayTreeProtocol {
    var subnodes: [MultiwayTreeNode] { children }
    var displayName: String { keys.map { "\($0)" }.joined(separator: " ") }
}

@Suite("MultiwayTreePrinter Tests")
struct MultiwayTreePrinterTests {
    // MARK: - 辅助方法
    
    /// 创建测试树的辅助方法
    fileprivate func createTestTree() -> MultiwayTreeNode {
        let root = MultiwayTreeNode(keys: [1, 2, 3])
        let child1 = MultiwayTreeNode(keys: [4, 5])
        let child2 = MultiwayTreeNode(keys: [6, 7])
        root.addChild(child1)
        root.addChild(child2)
        return root
    }
    
    /// 打印树的辅助方法
    fileprivate func printTree(_ root: MultiwayTreeNode) -> String {
        MultiwayTreePrinter(root).print()
    }
    
    // MARK: - 基本打印测试
    
    @Test("test print single node")
    func testPrintSingleNode() async throws {
        let root = MultiwayTreeNode(keys: [1, 2, 3])
        #expect(printTree(root) == "1 2 3")
    }
    
    @Test("test print with one child")
    func testPrintWithOneChild() async throws {
        let root = MultiwayTreeNode(keys: [1, 2, 3])
        let child = MultiwayTreeNode(keys: [4, 5])
        root.addChild(child)

        let expected = """
        1 2 3
        └── 4 5
        """
        #expect(printTree(root) == expected)
    }
    
    @Test("test print with multiple children")
    func testPrintWithMultipleChildren() async throws {
        let root = MultiwayTreeNode(keys: [1, 2, 3])
        let child1 = MultiwayTreeNode(keys: [4, 5])
        let child2 = MultiwayTreeNode(keys: [6, 7])
        root.addChild(child1)
        root.addChild(child2)
        
        let expected = """
        1 2 3
        ├── 4 5
        └── 6 7
        """
        #expect(printTree(root) == expected)
    }
    
    // MARK: - 多层级树测试
    
    @Test("test print with nested children - right side")
    func testPrintWithNestedChildrenRight() async throws {
        let root = createTestTree()
        root.children[1].addChild(MultiwayTreeNode(keys: [8, 9]))
        
        let expected = """
        1 2 3
        ├── 4 5
        └── 6 7
            └── 8 9
        """
        #expect(printTree(root) == expected)
    }
    
    @Test("test print with nested children - left side")
    func testPrintWithNestedChildrenLeft() async throws {
        let root = createTestTree()
        root.children[0].addChild(MultiwayTreeNode(keys: [10, 11]))
        
        let expected = """
        1 2 3
        ├── 4 5
        │   └── 10 11
        └── 6 7
        """
        #expect(printTree(root) == expected)
    }
    
    @Test("test print with multiple nested children")
    func testPrintWithMultipleNestedChildren() async throws {
        let root = createTestTree()
        root.children[0].addChild(MultiwayTreeNode(keys: [10, 11]))
        root.children[0].addChild(MultiwayTreeNode(keys: [12, 13]))
        root.children[1].addChild(MultiwayTreeNode(keys: [8, 9]))
        
        let expected = """
        1 2 3
        ├── 4 5
        │   ├── 10 11
        │   └── 12 13
        └── 6 7
            └── 8 9
        """
        #expect(printTree(root) == expected)
    }
}
