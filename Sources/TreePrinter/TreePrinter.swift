public protocol TreePrinter {
    associatedtype Node: TreeRepresentable
    
    var tree: Node { get }
    var options: TreePrintOptions { get set }

    init(_ tree: Node, options: TreePrintOptions)
    
    func print() -> String
}

extension TreePrinter {
    public func configure(_ block: (inout TreePrintOptions) -> Void) -> Self {
        var newPrinter = self
        block(&newPrinter.options)
        return newPrinter
    }
} 
