public protocol TreeRepresentable {}

// 二叉树节点表示
public protocol PrintableBinaryTreeProtocol: TreeRepresentable {
    /// 使用 Self 表示 Node，这样需要实现方是 final 的
    var lNode: Self? { get }
    var rNode: Self? { get }
    var displayName: String { get }
}

// 多叉树节点表示
public protocol PrintableMultiwayTreeProtocol: TreeRepresentable {
    /// 使用 Self 表示 Node，这样需要实现方是 final 的
    var subnodes: [Self] { get }
    var displayName: String { get }
}


