import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import greenwood.{NodeElement, TokenElement}
import gsv
import molt
import molt/cst
import molt/error as molt_error
import molt/types
import molt/value

pub type Format {
  Yaml
  Toml
  Json
  Csv
}

pub type ParseError {
  UnexpectedParsingError
  ParsingError(msg: String, loc: Option(ParseErrorLoc))
  MultipleDocuments
}

pub type ParseErrorLoc {
  ParseErrorLoc(line: Int, column: Int)
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

pub fn parse(format: Format, string: String) -> Result(Node, ParseError) {
  case format {
    Yaml -> parse_yaml(string)
    Toml -> parse_toml(string)
    Json -> parse_json(string)
    Csv -> parse_csv(string)
  }
}

pub fn parse_yaml(string: String) -> Result(Node, ParseError) {
  case parse_yaml_documents(string) {
    Ok([]) -> Ok(NodeNil)
    Ok([root]) -> Ok(root)
    Ok(_) -> Error(MultipleDocuments)
    Error(error) -> Error(error)
  }
}

pub fn parse_toml(string: String) -> Result(Node, ParseError) {
  use doc <- result.try(
    molt.parse(string) |> result.map_error(describe_molt_error),
  )

  case molt.document_errors(doc) {
    [error, ..] -> Error(describe_toml_syntax_error(error))
    [] ->
      list.try_fold(cst.from_document(doc).children, [], fn(tree, element) {
        insert_toml_element(tree, [], element)
      })
      |> result.map(tree_to_node)
  }
}

fn describe_molt_error(error: molt_error.MoltError) -> ParseError {
  ParsingError(msg: molt_error.describe_error(error), loc: None)
}

fn describe_toml_syntax_error(error: types.SyntaxError) -> ParseError {
  let msg = case error.kind {
    types.DuplicateKey(key:, ..) -> "the key `" <> key <> "` is defined twice"
    types.DuplicateTable(..) -> "the table is defined twice"
    types.KeyIsScalar(key:, ..) ->
      "the key `" <> key <> "` is a value, not a table"
    types.KeyIsInlineTable(key:, ..) ->
      "the key `" <> key <> "` is an inline table, it can't be extended"
    types.KeyIsArray(key:, ..) ->
      "the key `" <> key <> "` is an array, not a table"
    types.InvalidKeySyntax -> "the key is invalid"
    types.MissingValue -> "the key has no value"
    types.ExtraEquals -> "unexpected `=`"
    types.MultipleValues -> "the key has more than one value"
    types.EmptyTableHeader -> "the table name is empty"
    types.MalformedTableHeader -> "the table header is malformed"
    types.UnterminatedArray -> "the array is never closed"
    types.MisplacedArraySeparator -> "the array has a misplaced comma"
    types.UnterminatedInlineTable -> "the inline table is never closed"
    types.DuplicateKeyInInlineTable(key:) ->
      "the key `" <> key <> "` is defined twice in the inline table"
    types.InvalidBareValueInInlineTable ->
      "the inline table has an entry without a key or a value"
    types.MisplacedInlineTableSeparator ->
      "the inline table has a misplaced comma"
    types.UnterminatedString -> "the string is never closed"
    types.UnterminatedMultilineString -> "the multiline string is never closed"
    types.BadValue(text:) -> "unexpected `" <> text <> "`"
    types.UnparsableContent -> "the content can't be parsed"
    types.NoValidTomlStructure -> "the content is not TOML"
  }

  ParsingError(
    msg:,
    loc: Some(ParseErrorLoc(line: error.span.line, column: error.span.col)),
  )
}

fn insert_toml_element(
  tree: List(#(String, Tree)),
  table_path: List(String),
  element: greenwood.Element(types.TomlKind),
) -> Result(List(#(String, Tree)), ParseError) {
  case element {
    TokenElement(_) -> Ok(tree)
    NodeElement(node) ->
      case node.kind {
        types.KeyValue -> {
          let path =
            list.append(table_path, toml_key_parts(node.children, types.Equals))

          use value <- result.try(
            value.parse_value(cst.value_text(node))
            |> result.map_error(describe_molt_error),
          )
          use leaf <- result.try(toml_value_to_node(value))

          insert_tree(tree, path, Some(leaf), string.join(path, "."))
        }
        types.Table -> {
          let path = toml_key_parts(node.children, types.RightBracket)

          use tree <- result.try(insert_tree(
            tree,
            path,
            None,
            string.join(path, "."),
          ))

          list.try_fold(node.children, tree, fn(tree, child) {
            insert_toml_element(tree, path, child)
          })
        }
        types.ArrayOfTables ->
          Error(ParsingError(
            msg: "arrays of tables (`[[table]]`) aren't supported, a translation is a string or a group",
            loc: None,
          ))
        _ -> Ok(tree)
      }
  }
}

fn toml_key_parts(
  elements: List(greenwood.Element(types.TomlKind)),
  stop: types.TomlKind,
) -> List(String) {
  list.fold_until(elements, [], fn(parts, element) {
    case element {
      TokenElement(token) if token.kind == stop -> list.Stop(parts)
      TokenElement(token) ->
        case token.kind {
          types.BareKey | types.Integer | types.LiteralString ->
            list.Continue(list.append(parts, [token.text]))
          types.BasicString ->
            list.Continue(list.append(parts, [unescape_toml_key(token.text)]))
          _ -> list.Continue(parts)
        }
      NodeElement(node) if node.kind == types.Key ->
        list.Continue(list.append(parts, toml_key_parts(node.children, stop)))
      NodeElement(_) -> list.Continue(parts)
    }
  })
}

fn unescape_toml_key(text: String) -> String {
  case cst.parse_path("\"" <> text <> "\"") {
    Ok([types.KeySegment(key)]) -> key
    _ -> text
  }
}

fn toml_value_to_node(toml: value.Value) -> Result(Node, ParseError) {
  case value.type_of(toml) {
    "string" -> Ok(NodeStr(value.unwrap_string_or(toml, "")))
    "integer" -> Ok(NodeInt(value.unwrap_int_or(toml, 0)))
    "float" -> Ok(NodeFloat(value.unwrap_float_or(toml, 0.0)))
    "boolean" -> Ok(NodeBool(value.unwrap_bool_or(toml, False)))
    "array" -> {
      use items <- result.try(
        value.array_to_list(toml) |> result.map_error(describe_molt_error),
      )
      list.try_map(items, toml_value_to_node) |> result.map(NodeSeq)
    }
    "inline_table" | "table" -> {
      use entries <- result.try(
        value.table_to_list(toml) |> result.map_error(describe_molt_error),
      )
      list.try_map(entries, fn(entry) {
        use item <- result.map(toml_value_to_node(entry.1))
        #(NodeStr(entry.0), item)
      })
      |> result.map(NodeMap)
    }
    "infinity" | "nan" -> unsupported("`inf` and `nan`")
    "offset_datetime" | "local_datetime" | "local_date" | "local_time" ->
      unsupported("dates and times")
    _ -> Error(UnexpectedParsingError)
  }
}

fn unsupported(what: String) -> Result(Node, ParseError) {
  Error(ParsingError(
    msg: what <> " aren't supported, quote the value to keep it as text",
    loc: None,
  ))
}

@external(erlang, "margot_json_ffi", "parse_string")
pub fn parse_json(string: String) -> Result(Node, ParseError)

pub fn parse_csv(string: String) -> Result(Node, ParseError) {
  use rows <- result.try(
    gsv.to_lists(string, separator: ",")
    |> result.map_error(fn(error) {
      ParsingError(msg: describe_csv_error(error), loc: None)
    }),
  )

  use entries <- result.map(
    list.try_fold(rows, [], fn(entries, row) {
      case row {
        [key, value] -> insert_csv_row(entries, key, value)
        [key] ->
          Error(ParsingError(
            msg: "the row `"
              <> key
              <> "` has no value, expected a key and a value",
            loc: None,
          ))
        [key, ..fields] ->
          Error(ParsingError(
            msg: "the row `"
              <> key
              <> "` has "
              <> int.to_string(list.length(fields) + 1)
              <> " fields, expected a key and a value (quote the value if it contains a comma)",
            loc: None,
          ))
        [] -> Ok(entries)
      }
    }),
  )

  tree_to_node(entries)
}

fn describe_csv_error(error: gsv.Error) -> String {
  case error {
    gsv.UnescapedQuote(line:) ->
      "line "
      <> int.to_string(line)
      <> ": unescaped quote, double it (`\"\"`) or quote the whole field"
    gsv.MissingClosingQuote(starting_line:) ->
      "line "
      <> int.to_string(starting_line)
      <> ": the quote of this field is never closed"
  }
}

type Tree {
  Leaf(Node)
  Group(List(#(String, Tree)))
}

fn insert_csv_row(
  entries: List(#(String, Tree)),
  key: String,
  value: String,
) -> Result(List(#(String, Tree)), ParseError) {
  let path = string.split(key, ".")

  case list.any(path, fn(part) { part == "" }) {
    True ->
      Error(ParsingError(
        msg: "the key `" <> key <> "` is empty or has an empty part",
        loc: None,
      ))
    False -> insert_tree(entries, path, Some(NodeStr(value)), key)
  }
}

fn insert_tree(
  entries: List(#(String, Tree)),
  path: List(String),
  leaf: Option(Node),
  key: String,
) -> Result(List(#(String, Tree)), ParseError) {
  let found = path |> list.first() |> result.try(list.key_find(entries, _))

  case path, found, leaf {
    [], _, _ -> Ok(entries)
    [name], Error(Nil), Some(node) ->
      Ok(list.append(entries, [#(name, Leaf(node))]))
    [name], Error(Nil), None -> Ok(list.append(entries, [#(name, Group([]))]))
    [_], Ok(Group(_)), None -> Ok(entries)
    [_], Ok(Group(_)), Some(_) ->
      Error(ParsingError(
        msg: "the key `" <> key <> "` is both a translation and a group",
        loc: None,
      ))
    [_], Ok(Leaf(_)), _ ->
      Error(ParsingError(
        msg: "the key `" <> key <> "` is defined twice",
        loc: None,
      ))
    [name, ..], Ok(Leaf(_)), _ ->
      Error(ParsingError(
        msg: "the key `"
          <> key
          <> "` is inside `"
          <> name
          <> "` which is already a translation",
        loc: None,
      ))
    [name, ..rest], Ok(Group(children)), _ -> {
      use children <- result.map(insert_tree(children, rest, leaf, key))
      list.key_set(entries, name, Group(children))
    }
    [name, ..rest], Error(Nil), _ -> {
      use children <- result.map(insert_tree([], rest, leaf, key))
      list.append(entries, [#(name, Group(children))])
    }
  }
}

fn tree_to_node(entries: List(#(String, Tree))) -> Node {
  entries
  |> list.map(fn(entry) {
    case entry.1 {
      Leaf(node) -> #(NodeStr(entry.0), node)
      Group(children) -> #(NodeStr(entry.0), tree_to_node(children))
    }
  })
  |> NodeMap
}

@external(erlang, "margot_yaml_ffi", "parse_string")
fn parse_yaml_documents(string: String) -> Result(List(Node), ParseError)
