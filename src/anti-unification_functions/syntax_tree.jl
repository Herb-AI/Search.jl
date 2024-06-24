"""
    abstract type AST

Abstract type for Abstract Syntax Trees used on anti-unification
"""
abstract type AST end


"""
    mutable struct ExprAST <: AST

Abstract Syntax Trees from `Expr` class
Consists of:
- `index::Int`: index given to the AST node
- `value::Any`: value inside the AST node
- `size::Int`: number of child nodes
- `subtrees::Vector{ExprAST}`: the children of the node
"""
mutable struct ExprAST <: AST
    index::Int
    value::Any
    size::Int
    subtrees::Vector{ExprAST}
end

"""
    mutable struct RuleNodeAST <: AST

Abstract Syntax Trees from `RuleNode` class
Consists of:
- `index::Int`: index given to the AST node
- `value::Any`: value inside the AST node
- `size::Int`: number of child nodes
- `subtrees::Vector{RuleNodeAST}`: the children of the node
"""
# Define the RuleNodeAST struct
mutable struct RuleNodeAST <: AST
    index::Int
    value::Any
    size::Int
    subtrees::Vector{RuleNodeAST}
end


"""
    function createTreeFromExpr(expr::Any,index::Int)

Creates an `ExprAst` form a 'Expr'
"""
function createTreeFromExpr(expr::Any,index::Int) ::Tuple{Int, ExprAST}
    subtrees = Vector{ExprAST}()
    if typeof(expr) != Expr
        value = expr
        return index, ExprAST(index,value,0,Vector{ExprAST}())
    elseif typeof(expr) == Expr
        if expr.head == :call
            value = expr.args[1]
            start = 2
        else 
            error("Wrong input error: Expr is not call")
        end
        size = length(expr.args)
        _index = index
        for i in range(start, size)
            _index, newNode = createTreeFromExpr(expr.args[i], _index + 1)
            push!(subtrees, newNode)
        end
        return _index, ExprAST(index,value,length(subtrees),subtrees)
    end        
end

"""
    function createExprFromTree(node::ExprAST)

This function serves as the main entry point for transforming an `ExprAST` back into an `Expr`.
"""
function createExprFromTree(node::ExprAST) :: Expr
    index, expr = _createExprFromTree(node,0)
    return expr
end

"""
    function _createExprFromTree(node::ExprAST)

Transforms an `ExprAST` node and its subtrees into an `Expr`.
"""
function _createExprFromTree(node::ExprAST, index::Int) ::Tuple{Int, Expr}
    if node.value === nothing
        return index + 1, Symbol("placeholder$index")
    elseif length(node.subtrees) == 0
        return index, node.value
    else
        head = :call
        args = Vector{Any}()
        push!( args, node.value)

        for subtree in node.subtrees
            index, newExpr = _createExprFromTree(subtree, index)
            push!( args, newExpr)
        end

        return index, Expr(head,args...)
    end
end

"""
    function buildTreeExpr(expr::Any) ::ExprAST

This function serves as the main entry point for creating an `ExprAst` form an 'Expr'.
"""
function buildTreeExpr(expr::Any) ::ExprAST
    index, root = createTreeFromExpr(expr,0)
    return root
end

"""
    function createTreeFromRuleNode(ruleNode::AbstractRuleNode, index::Int)

Creates an `RuleNodeAST` form a 'AbstractRuleNode'
"""
function createTreeFromRuleNode(ruleNode::AbstractRuleNode, index::Int) ::Tuple{Int, RuleNodeAST}
    if(typeof(ruleNode) == Hole)
        value = ruleNode.domain
        error("Hole should not be in the tree")
    end

    subtrees = Vector{RuleNodeAST}()
    value = ruleNode.ind
    _index = index
    for child in ruleNode.children
        _index, newNode = createTreeFromRuleNode(child, _index + 1)
        push!(subtrees, newNode)
    end
    return _index, RuleNodeAST(index,value,length(ruleNode.children),subtrees)
end

"""
    function createRuleNodeFromTree(node::RuleNodeAST) :: AbstractRuleNode

Transforms a `RuleNodeAST` node and its subtrees into an `AbstractRuleNode`.
"""
function createRuleNodeFromTree(node::RuleNodeAST) :: AbstractRuleNode
    if node.value === nothing
        return Hole(BitVector())
    elseif length(node.subtrees) == 0
        if typeof(node.value) == BitVector
            error("Hole should not be in the tree")
            return Hole(node.value)
        else
            return RuleNode(node.value)
        end
    else
        children = Vector{AbstractRuleNode}()
        for subtree in node.subtrees
            push!( children, createRuleNodeFromTree(subtree))
        end
        return RuleNode(node.value,children)
    end
end


"""
    function buildTreeRuleNode(ruleNode::AbstractRuleNode) ::RuleNodeAST

This function serves as the main entry point for creating an `RuleNodeAst` form an 'AbstractRuleNode'.
"""
function buildTreeRuleNode(ruleNode::AbstractRuleNode) ::RuleNodeAST
    index, root = createTreeFromRuleNode(ruleNode, 0)
    return root
end

"""
    function addHoleTypes(ruleNode::RuleNode, grammar)

Determines the type that the Hole should have and updates its domain appropriately
"""
function addHoleTypes(ruleNode::RuleNode, grammar)
    childernTypes = child_types(grammar, ruleNode.ind)
    for (index, child) in enumerate(ruleNode.children)
      if isa(child, Hole)
            child.domain = get_domain(grammar, childernTypes[index])
      else
        addHoleTypes(child, grammar)
      end
    end    
end

"""
    function transform_to_grammr_rule(ruleNode::RuleNode, grammar)

Transforms a 'RuleNode' to the form required to be added to the grammar
"""
function transform_to_grammr_rule(ruleNode::RuleNode, grammar)
    type = return_type(grammar,ruleNode.ind)
    grammar.types
    addHoleTypes(ruleNode,grammar)
    body = rulenode2expr(ruleNode,grammar)
    expr = Expr(Symbol("="), type, body)
    return expr
end

"""
    function create_constraint(ruleNode::RuleNode)

Creates a 'Forbidden'constraint based on a `RuleNode` given
"""
function create_constraint(ruleNode::RuleNode)
    (ruleNodeTree, name) = _create_constraint(ruleNode, 0)
    println(ruleNodeTree)
    return Forbidden(ruleNodeTree)
end


"""
    function _create_constraint(ruleNode::RuleNode, name::Int)

Creates a new ruleNode with all of the requirments to become a grammar constraint
"""
function _create_constraint(ruleNode::RuleNode, name::Int)
    list = Vector{AbstractRuleNode}()
    for (index, child) in enumerate(ruleNode.children)
        if isa(child, Hole)
            push!(list, VarNode(Symbol(string("varName", 1))))
            name += 1
        else
            (newChild, newName) = _create_constraint(child, name)
            name = newName
            push!(list, newChild)
        end
    end
    return (RuleNode(ruleNode.ind, list), name)
end
