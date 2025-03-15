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

import Foundation
@testable import Lumos
import Testing

@Suite("SkipList Tests")
struct SkipListTests {
    // MARK: - OrderedCollection 协议测试也是基础功能测试

    /// 通过此测试只能代表其基本功能没啥问题，一些跨节点的细节是测不到的。
    @Suite("SkipList OrderedCollection protocol tests")
    struct SkipListOrderedCollectionProtocolTests: OrderedCollectionTests {
        func factory() -> SkipList<Int, Int> {
            return SkipList<Int, Int>()
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

    /// SkipList 有一个问题需要注意，就是目标删除后，需要删除其在上层节点的引用，否则还能在上层中查询到。
    /// 这里使用随机删除的方式进行测试。
    @Test("test random remove")
    func TestRandomRemove() async throws {
        var referenceSet = Set<Int>()
        let list = SkipList<Int, Int>()
        while referenceSet.count < 120 {
            let key = Int.random(in: 0 ..< 1000)
            if referenceSet.insert(key).inserted {
                list.insert(key: key, value: key * 10)
            }
        }
        
        while referenceSet.isEmpty == false {
            let key = referenceSet.randomElement()!
            list.remove(key: key)
            referenceSet.remove(key)
            #expect(list.keys.count == list.count)
            #expect(list.contains(key: key) == false)
            #expect(list.matrixString.contains(where: {$0.contains("\(key)")}) == false)
        }
    }
    
    // MARK: - SkipList Exclusive Features

    @Suite("SkipList Exclusive Features")
    struct SkipListExclusiveFeaturesTests {
        /// 因为SkipList的随机性，无法确定的推断出其某一刻的具体状态，这里只能进行有限的测试
        /// 不过由于 OrderedCollection 已经保证了其有序容器的特性，和方法的正确性，这里只测试与 SkipList 强相关的。
        
        // 批量加载如果是乱序应该崩溃。
        /// @Test func TestBulkLoading_Crash() async throws {
        ///   _ = SkipList(contentsOf: [
        ///       (1, 10),
        ///       (3, 30),
        ///       (2, 20),
        ///   ])
        /// }
        
        @Test("test SkipList description")
        func TestSkipListDescription() async throws {
            let list = SkipList<Int, Int>()
            let expected = """
            SkipList:
            - Number of elements: 0
            - Maximum level: 32 (p = 0.50)
            - Current level: 1
            - Head next key: nil
            - Tail key: nil
            """
            #expect(list.description == expected)
            
            list.insert(key: 1, value: 10)
            #expect(list.description.contains("- Number of elements: 1"))
            #expect(list.description.contains("- Maximum level: 32 (p = 0.50)"))
            #expect(list.description.contains("- Head next key: 1"))
            #expect(list.description.contains("- Tail key: 1"))
        }

        /// 测试 SkipList 的层级分布
        /// 经测试：数据量越大其分布越均衡越符合几何分布，但是数据量较少时收到随机数的影响比较大
        @Test("test SkipList Level Distribution")
        func testSkipListLevelDistribution() async throws {
            let list = SkipList<Int, Int>()
            /// 在数据量为 100 时，仍然可能不太均衡。
            for i in 0 ..< 100 {
                list.insert(key: i, value: i * 10)
            }
            Swift.print(analyzeLevelDistribution(matrix: list.matrixString, p: 0.5))
        }

        // 分析 Level 分布并返回格式化结果
        func analyzeLevelDistribution(matrix: [[String]], p: Double = 0.5) -> String {
            func digitCount(_ number: Int) -> Int {
                if number == 0 { return 1 }
                return Int(log10(Double(abs(number)))) + 1
            }
            
            func padZero(_ number: Int, length: Int) -> String {
                String(repeating: "0", count: length - digitCount(number)) + String(number)
            }
            
            // 统计每一层的节点数
            var levelCounts: [Int: Int] = [:]
            let totalNodes = matrix.last!.filter { $0 != "-" && $0 != "nil" }.count
            let maxDigit = digitCount(totalNodes)
            
            // 从下往上统计每一层的实际节点数
            for (level, row) in matrix.reversed().enumerated() {
                let nodeCount = row.filter { $0 != "-" && $0 != "nil" }.count
                levelCounts[level + 1] = nodeCount
            }
            
            // 计算实际比例、理论比例和偏差
            let maxLevel = matrix.count
            var distributionTable: [[String]] = [["Level", "Nodes", "Ratio", "Ideal Ratio", "Deviation"]]

            for level in 1 ... maxLevel {
                let actualCount = Double(levelCounts[level] ?? 0)
                let actualRatio = actualCount / Double(totalNodes)
                let theoreticalRatio: Double
                if level == 1 {
                    theoreticalRatio = 1.0 // 最底层包含所有节点
                } else {
                    theoreticalRatio = pow(1 - p, Double(level - 2)) * p // 从 Level 2 开始几何分布
                }
                let deviation = actualRatio - theoreticalRatio
                
                let row = [
                    "\(level)",
                    String(format: "%d", Int(actualCount)),
                    String(format: "%.3f", actualRatio),
                    String(format: "%.3f", theoreticalRatio),
                    String(format: "%+.3f", deviation)
                ]
                distributionTable.append(row)
            }
            
            // 格式化输出矩阵
            var formattedOutput = "\nSkipList 层级分布分析: count == \(totalNodes) \n"
            
            // 计算每列最大宽度（包括表头）
            var colWidths = [Int](repeating: 0, count: 5)
            for row in distributionTable {
                for (i, cell) in row.enumerated() {
                    colWidths[i] = max(colWidths[i], cell.count)
                }
            }
            
            // 确保宽度为奇数并增加填充
            colWidths = colWidths.map { max($0 + ($0 % 2 == 0 ? 2 : 3), 7) } // 最小宽度7
            
            // 生成分隔线
            let separator = colWidths.map { String(repeating: "-", count: $0) }.joined(separator: "+")
            let headerSeparator = "+" + separator + "+"
            
            // 输出表格（表头和内容都居中对齐）
            for (i, row) in distributionTable.enumerated() {
                if i == 0 {
                    formattedOutput += headerSeparator + "\n"
                }
                let formattedRow = row.enumerated().map { j, cell in
                    if j == 1, cell != "Nodes" {
                        let m_tp = colWidths[j] - maxDigit
                        let m_l_tp = m_tp / 2
                        var m_r_tp = m_tp - m_l_tp
                        m_r_tp += maxDigit - cell.count
                        return String(repeating: " ", count: m_l_tp) + cell + String(repeating: " ", count: m_r_tp)
                    }
                    
                    let totalPadding = colWidths[j] - cell.count
                    let leftPadding = totalPadding / 2
                    let rightPadding = totalPadding - leftPadding
                    return String(repeating: " ", count: leftPadding) + cell + String(repeating: " ", count: rightPadding)
                }.joined(separator: "|")
                formattedOutput += "|" + formattedRow + "|\n"
                if i == 0 || i == distributionTable.count - 1 {
                    formattedOutput += headerSeparator + "\n"
                }
            }
            
            // 计算卡方值
            let chiSquare = distributionTable.dropFirst().reduce(0.0) { sum, row in
                let actual = Double(row[2])!
                let theoretical = Double(row[3])!
                let expectedCount = theoretical * Double(totalNodes)
                return expectedCount > 0 ? sum + pow(actual * Double(totalNodes) - expectedCount, 2) / expectedCount : sum
            }
            
            formattedOutput += "卡方值: \(String(format: "%.2f", chiSquare))\n"
            formattedOutput += "偏差评估: \(chiSquare < Double(totalNodes) * 0.1 ? "可接受" : "偏差较大")\n"
            
            return formattedOutput
        }
    }
}
