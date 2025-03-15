/// 多叉树和二叉树的打印配置是相同的，但是一些配置项只适用于二叉树
public struct TreePrintOptions: Sendable {
    /// 空节点输出内容
    /// 仅在其兄弟节点存在时，空节点才会输出内容
    public var nilFiller: String = "nil"
   
    /// 对齐方式
    /// 目前只支持 center
    public var alignment: Alignment = .center
    
    /// 字符配置
    public var characters = Characters.default
    
    public enum Alignment: Sendable {
        case left
        case center
        case right
    }

    public struct Characters: Sendable {
        /// swiftformat: disable all
        /// swiftlint: disable all
        public var vertical             = "│"
        public var horizontal           = "─"
        public var cornerTopLeft        = "┌"
        public var cornerTopRight       = "┐"
        public var cornerBottomLeft     = "└"
        public var cornerBottomRight    = "┘"
        public var crossJunction        = "┼"
        public var teeBottom            = "┴"
        public var teeLeft              = "├"
        /// swiftlint: enable all
        /// swiftformat: enable all
        
        public static let `default` = Characters()
    }
    
    public static let `default` = TreePrintOptions()
} 
