import gleam/bool
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import margot/internal/naming
import margot/internal/yaml

pub type File {
  File(name: String, content: String)
}

fn describe_yaml_key(key: yaml.Node) -> String {
  case key {
    yaml.NodeInt(value) ->
      "the key `"
      <> int.to_string(value)
      <> "` is an integer, keys must be strings, quote it"
    yaml.NodeFloat(value) ->
      "the key `"
      <> float.to_string(value)
      <> "` is a float, keys must be strings, quote it"
    yaml.NodeBool(value) ->
      "the key `"
      <> case value {
        True -> "true"
        False -> "false"
      }
      <> "` is a boolean, keys must be strings, quote it (YAML reads `yes`, `no`, `on` and `off` as booleans)"
    _ -> "a key is " <> describe_yaml_node(key) <> ", keys must be strings"
  }
}

fn describe_yaml_node(node: yaml.Node) -> String {
  case node {
    yaml.NodeNil -> "empty"
    yaml.NodeStr(_) -> "a string"
    yaml.NodeBool(_) -> "a boolean"
    yaml.NodeInt(_) -> "an integer"
    yaml.NodeFloat(_) -> "a float"
    yaml.NodeSeq(_) -> "a list"
    yaml.NodeMap(_) -> "a map"
  }
}

fn describe_yaml_error(error: yaml.YamlError) -> String {
  case error {
    yaml.UnexpectedParsingError -> "the file couldn't be parsed as YAML"
    yaml.ParsingError(msg:, loc:) ->
      "line "
      <> int.to_string(loc.line)
      <> ", column "
      <> int.to_string(loc.column)
      <> ": "
      <> msg
  }
}

pub type Locale {
  Locale(name: String, file: String, translations: List(Translation))
}

pub fn by_path(locale: Locale) -> Dict(List(String), Translation) {
  locale.translations
  |> list.map(fn(translation) { #(translation.path, translation) })
  |> dict.from_list()
}

pub fn parse_locale(file: File) -> Result(Locale, List(String)) {
  let error_prefix = file.name <> ": "

  use translations <- result.try(case yaml.parse_string(file.content) {
    Ok([]) -> Ok([])
    Ok([yaml.Document(root: yaml.NodeNil)]) -> Ok([])
    Ok([yaml.Document(root: yaml.NodeMap(entries))]) ->
      case parse_entries(entries, []) {
        Ok(ok) -> Ok(ok)
        Error(errors) ->
          Error(list.map(errors, fn(error) { error_prefix <> error }))
      }
    Ok([yaml.Document(root: root)]) ->
      Error([
        error_prefix
        <> "the file should be a map of translations, found "
        <> describe_yaml_node(root),
      ])
    Ok(_) ->
      Error([error_prefix <> "the file should contain only one YAML document"])
    Error(error) -> Error([error_prefix <> describe_yaml_error(error)])
  })

  Ok(Locale(
    name: string.remove_suffix(file.name, ".i18n.yaml"),
    file: file.name,
    translations:,
  ))
}

fn split_key_and_raw_modifier(key: String) -> #(String, Result(String, Nil)) {
  case string.split_once(key, "(") {
    Ok(#(name, modifier)) ->
      case string.ends_with(modifier, ")") {
        True -> #(name, Ok(string.drop_end(modifier, 1)))
        False -> #(key, Error(Nil))
      }
    Error(Nil) -> #(key, Error(Nil))
  }
}

fn parse_entries(
  entries: List(#(yaml.Node, yaml.Node)),
  path: List(String),
) -> Result(List(Translation), List(String)) {
  let #(translations, errors) =
    list.map(entries, fn(entry) {
      case entry {
        #(yaml.NodeStr(raw_key), value) -> {
          let #(key, modifier) = split_key_and_raw_modifier(raw_key)
          let path = list.append(path, [key])

          use <- bool.guard(
            when: !naming.is_valid_gleam_name(key),
            return: Error([
              naming.path_error_message(
                "the key `"
                  <> key
                  <> "` should be snake case: lowercase letters, digits and `_`, without starting with a digit",
                path,
              ),
            ]),
          )

          let is_plural = case modifier {
            Ok(modifier) ->
              string.starts_with(modifier, "ordinal")
              || string.starts_with(modifier, "cardinal")
            _ -> False
          }

          case value, modifier, is_plural {
            yaml.NodeStr(value), Error(Nil), _ ->
              parse_translation(path, value)
              |> result.map(fn(translation) { [translation] })
              |> result.map_error(fn(error) {
                [naming.path_error_message(error, path)]
              })

            yaml.NodeStr(_), Ok(modifier), True ->
              Error([
                naming.path_error_message(
                  "`("
                    <> modifier
                    <> ")` for making a plural, it should be a map of forms like `one` and `other`",
                  path,
                ),
              ])

            yaml.NodeMap(children), Ok(modifier), True -> {
              use #(kind, parameter) <- result.try(
                parse_plural_modifier(modifier)
                |> result.map_error(fn(error) {
                  [naming.path_error_message(error, path)]
                }),
              )

              parse_plural(children, path, kind, parameter)
              |> result.map(fn(translation) { [translation] })
            }

            yaml.NodeStr(_), Ok(modifier), _
            | yaml.NodeMap(_), Ok(modifier), _
            ->
              Error([
                naming.path_error_message(
                  "`(" <> modifier <> ")` unknown modifier",
                  path,
                ),
              ])

            yaml.NodeMap(children), Error(Nil), False ->
              case parse_plural(children, path, Cardinal, "n") {
                Ok(translation) -> Ok([translation])
                Error(_) -> parse_entries(children, path)
              }

            yaml.NodeNil, _, _ ->
              Error([
                naming.path_error_message(
                  "the value is empty, expected a string or a map",
                  path,
                ),
              ])

            value, _, _ ->
              Error([
                naming.path_error_message(
                  "the value is "
                    <> describe_yaml_node(value)
                    <> ", expected a string or a map (quote it to keep it as text)",
                  path,
                ),
              ])
          }
        }
        #(key, _) ->
          Error([naming.path_error_message(describe_yaml_key(key), path)])
      }
    })
    |> result.partition()

  case errors {
    [] -> Ok(translations |> list.reverse() |> list.flatten())
    _ -> Error(errors |> list.reverse() |> list.flatten())
  }
}

pub type Translation {
  Simple(path: List(String), patterns: List(Pattern))
  Plural(
    path: List(String),
    kind: PluralKind,
    parameter: String,
    forms: PluralForms(List(Pattern)),
  )
}

fn parse_translation(
  path: List(String),
  value: String,
) -> Result(Translation, String) {
  use patterns <- result.map(parse_pattern(value, None))

  Simple(path:, patterns:)
}

pub type PluralKind {
  Cardinal
  Ordinal
}

pub type PluralForm {
  Zero
  One
  Two
  Few
  Many
  Other
}

pub type PluralForms(a) {
  PluralForms(
    zero: Option(a),
    one: Option(a),
    two: Option(a),
    few: Option(a),
    many: Option(a),
    other: a,
  )
}

fn parse_plural_modifier(
  modifier: String,
) -> Result(#(PluralKind, String), String) {
  let #(kind, parameter) = case string.split_once(modifier, "=") {
    Ok(#(kind, parameter)) -> #(string.trim(kind), string.trim(parameter))
    Error(Nil) -> #(modifier, "n")
  }

  use kind <- result.try(case kind {
    "cardinal" -> Ok(Cardinal)
    "ordinal" -> Ok(Ordinal)
    _ ->
      Error(
        "unknown modifier `("
        <> modifier
        <> ")`, expected `(cardinal)`, `(ordinal)`, `(cardinal=name)` or `(ordinal=name)`",
      )
  })

  case naming.is_valid_gleam_name(parameter) {
    True -> Ok(#(kind, parameter))
    False ->
      Error(
        "`"
        <> parameter
        <> "` isn't a valid plural parameter, a name is snake case like `(cardinal=count)`",
      )
  }
}

fn parse_plural(
  map: List(#(yaml.Node, yaml.Node)),
  path: List(String),
  kind: PluralKind,
  parameter: String,
) -> Result(Translation, List(String)) {
  use forms <- result.try({
    let #(forms, errors) =
      list.map(map, fn(entry) {
        case entry {
          #(yaml.NodeStr(key), yaml.NodeStr(value)) ->
            case key {
              "zero" -> Ok(#(Zero, key, value))
              "one" -> Ok(#(One, key, value))
              "two" -> Ok(#(Two, key, value))
              "few" -> Ok(#(Few, key, value))
              "many" -> Ok(#(Many, key, value))
              "other" -> Ok(#(Other, key, value))
              _ ->
                Error(naming.path_error_message(
                  "isn't a plural form, expected `zero`, `one`, `two`, `few`, `many` or `other`",
                  list.append(path, [key]),
                ))
            }
          #(yaml.NodeStr(key), value) ->
            Error(naming.path_error_message(
              "the value is "
                <> describe_yaml_node(value)
                <> ", expected a string",
              list.append(path, [key]),
            ))
          #(key, _) ->
            Error(naming.path_error_message(describe_yaml_key(key), path))
        }
      })
      |> result.partition()

    case errors {
      [] -> Ok(list.reverse(forms))
      _ -> Error(list.reverse(errors))
    }
  })

  let #(forms, errors) =
    list.map(forms, fn(form) {
      let #(form, key, value) = form

      parse_pattern(value, Some(parameter))
      |> result.map(fn(patterns) { #(form, patterns) })
      |> result.map_error(fn(error) {
        naming.path_error_message(error, list.append(path, [key]))
      })
    })
    |> result.partition()

  case errors {
    [_, ..] -> Error(list.reverse(errors))
    [] ->
      case list.key_find(forms, Other) {
        Ok(other) -> {
          let find = fn(form) {
            list.key_find(forms, form) |> option.from_result
          }

          Ok(Plural(
            path:,
            kind:,
            parameter:,
            forms: PluralForms(
              zero: find(Zero),
              one: find(One),
              two: find(Two),
              few: find(Few),
              many: find(Many),
              other:,
            ),
          ))
        }
        Error(Nil) ->
          Error([
            naming.path_error_message("a plural needs an `other` form", path),
          ])
      }
  }
}

fn parse_pattern(
  value: String,
  plural_parameter: Option(String),
) -> Result(List(Pattern), String) {
  do_parse_pattern(value, plural_parameter, False, "", [])
  |> result.map(list.reverse)
}

fn do_parse_pattern(
  rest: String,
  plural_parameter: Option(String),
  in_parameter: Bool,
  acc: String,
  values: List(Pattern),
) -> Result(List(Pattern), String) {
  case string.pop_grapheme(rest) {
    Error(Nil) ->
      case in_parameter, acc, values {
        True, _, [Text(previous), ..values] ->
          Ok([Text(previous <> "{" <> acc), ..values])
        True, _, _ -> Ok([Text("{" <> acc), ..values])
        False, "", _ -> Ok(values)
        False, _, _ -> Ok([Text(acc), ..values])
      }

    Ok(#("{", rest)) if !in_parameter -> {
      let values = case acc {
        "" -> values
        _ -> [Text(acc), ..values]
      }

      do_parse_pattern(rest, plural_parameter, True, "", values)
    }

    Ok(#("}", rest)) if in_parameter -> {
      use parameter <- result.try(parse_parameter(acc, plural_parameter))

      do_parse_pattern(rest, plural_parameter, False, "", [parameter, ..values])
    }

    Ok(#("\\", rest)) if in_parameter ->
      do_parse_pattern(rest, plural_parameter, in_parameter, acc, values)

    Ok(#("\\", "@:{" <> rest)) ->
      do_parse_pattern(
        rest,
        plural_parameter,
        in_parameter,
        acc <> "@:{",
        values,
      )

    Ok(#("\\", rest)) ->
      case string.pop_grapheme(rest) {
        Ok(#(escaped, rest)) ->
          do_parse_pattern(
            rest,
            plural_parameter,
            in_parameter,
            acc <> escaped,
            values,
          )
        Error(Nil) ->
          do_parse_pattern(rest, plural_parameter, in_parameter, acc, values)
      }

    Ok(#("@", ":{" <> link)) if !in_parameter -> {
      case
        {
          use #(path, rest) <- result.try(string.split_once(link, "}"))
          use path <- result.try(parse_link_path(path))
          Ok(#(path, rest))
        }
      {
        Ok(#(path, rest)) -> {
          let values = case acc {
            "" -> values
            _ -> [Text(acc), ..values]
          }

          do_parse_pattern(rest, plural_parameter, False, "", [
            Link(path),
            ..values
          ])
        }
        Error(Nil) ->
          do_parse_pattern(
            ":{" <> link,
            plural_parameter,
            in_parameter,
            acc <> "@",
            values,
          )
      }
    }

    Ok(#(char, rest)) ->
      do_parse_pattern(
        rest,
        plural_parameter,
        in_parameter,
        acc <> char,
        values,
      )
  }
}

fn parse_link_path(path: String) -> Result(LinkPath, Nil) {
  let #(dots, path) = count_leading_dots(path, 0)

  let segments = string.split(path, ".")

  case list.all(segments, naming.is_valid_gleam_name) {
    False -> Error(Nil)
    True ->
      case dots {
        0 -> Ok(Absolute(segments))
        _ -> Ok(Relative(up: dots - 1, path: segments))
      }
  }
}

fn count_leading_dots(path: String, dots: Int) -> #(Int, String) {
  case path {
    "." <> rest -> count_leading_dots(rest, dots + 1)
    _ -> #(dots, path)
  }
}

pub type Pattern {
  Text(String)
  Parameter(name: String, type_: Type)
  Link(LinkPath)
}

pub type LinkPath {
  Absolute(List(String))
  Relative(up: Int, path: List(String))
}

pub type Type {
  String
  Int
  Float
}

fn parse_parameter(
  raw: String,
  plural_parameter: Option(String),
) -> Result(Pattern, String) {
  let #(name, type_) = case string.split_once(raw, ":") {
    Ok(#(name, type_)) -> #(string.trim(name), Ok(string.trim(type_)))
    Error(Nil) -> #(string.trim(raw), Error(Nil))
  }

  case naming.is_valid_gleam_name(name) {
    False ->
      Error(
        "`{"
        <> raw
        <> "}` isn't a valid parameter, a name is snake case like `{first_name}`. Use `\\{` to write a brace",
      )
    True ->
      case type_ {
        Ok("String") -> Ok(Parameter(name, String))
        Ok("Int") -> Ok(Parameter(name, Int))
        Ok("Float") -> Ok(Parameter(name, Float))
        Ok(type_) ->
          Error(
            "`{"
            <> raw
            <> "}` has an unknown type `"
            <> type_
            <> "`, expected `String`, `Int` or `Float`",
          )
        Error(Nil) if Some(name) == plural_parameter -> Ok(Parameter(name, Int))
        Error(Nil) if name == "n" -> Ok(Parameter(name, Int))
        Error(Nil) -> Ok(Parameter(name, String))
      }
  }
}
