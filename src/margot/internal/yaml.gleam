pub type YamlError {
  UnexpectedParsingError
  ParsingError(msg: String, loc: YamlErrorLoc)
}

pub type YamlErrorLoc {
  YamlErrorLoc(line: Int, column: Int)
}

pub type Document {
  Document(root: Node)
}

pub type Node {
  NodeNil
  NodeStr(String)
  NodeBool(Bool)
  NodeInt(Int)
  NodeFloat(Float)
  NodeSeq(List(Node))
  NodeMap(List(#(Node, Node)))
}

@external(erlang, "margot_yaml_ffi", "parse_string")
pub fn parse_string(string: String) -> Result(List(Document), YamlError)
