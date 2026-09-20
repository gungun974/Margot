import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import margot/internal/locale.{type Locale, type Translation, Locale}
import margot/internal/naming

type Segment {
  Fixed(String)
  Choice(List(String))
  Any
}

fn parse_choice(inside: String) -> Result(Segment, String) {
  let items = inside |> string.split(",") |> list.map(string.trim)

  case items {
    [""] -> Error("`[]` is empty, a wildcard looks like `[de,fr]` or `[any]`")
    ["any"] -> Ok(Any)
    _ ->
      case list.contains(items, "any") {
        True ->
          Error("`any` can't be mixed with other codes in `[" <> inside <> "]`")
        False ->
          case list.find(items, fn(item) { !naming.valid_locale_name(item) }) {
            Ok(item) ->
              Error(
                "`"
                <> item
                <> "` isn't a valid locale code in `["
                <> inside
                <> "]`, expected something like `en` or `en-US`",
              )
            Error(Nil) -> Ok(Choice(items))
          }
      }
  }
}

fn parse_template(name: String) -> Result(List(Segment), String) {
  do_parse_template(name, [])
  |> result.map(fn(segments) {
    segments
    |> list.reverse()
    |> list.filter(fn(segment) { segment != Fixed("") })
  })
}

fn do_parse_template(
  rest: String,
  segments: List(Segment),
) -> Result(List(Segment), String) {
  case string.split_once(rest, "[") {
    Error(Nil) ->
      case string.contains(rest, "]") {
        True -> Error("`]` has no matching `[`")
        False -> Ok([Fixed(rest), ..segments])
      }
    Ok(#(before, after)) ->
      case string.contains(before, "]") {
        True -> Error("`]` has no matching `[`")
        False ->
          case string.split_once(after, "]") {
            Error(Nil) ->
              Error(
                "`[` is never closed, a wildcard looks like `[de,fr]` or `[any]`",
              )
            Ok(#(inside, rest)) -> {
              use choice <- result.try(parse_choice(inside))

              do_parse_template(rest, [choice, Fixed(before), ..segments])
            }
          }
      }
  }
}

const unknown_part = "?"

fn is_script(part: String) -> Bool {
  string.length(part) == 4
  && list.all(string.to_graphemes(part), fn(char) {
    !string.contains("0123456789", char)
  })
}

fn positions_of(codes: List(String)) -> Dict(Int, List(String)) {
  list.fold(codes, dict.new(), fn(positions, code) {
    string.split(code, "-")
    |> list.index_fold(positions, fn(positions, part, index) {
      case part == unknown_part || { index > 0 && is_script(part) } {
        True -> positions
        False ->
          dict.upsert(positions, int.min(index, 1), fn(existing) {
            [part, ..option.unwrap(existing, [])]
          })
      }
    })
  })
  |> dict.map_values(fn(_, parts) {
    parts |> list.unique() |> list.sort(string.compare)
  })
}

fn expand_template(
  template: List(Segment),
  positions: Dict(Int, List(String)),
) -> List(String) {
  list.fold(template, [""], fn(codes, segment) {
    case segment {
      Fixed(text) -> list.map(codes, fn(code) { code <> text })
      Choice(items) ->
        list.flat_map(codes, fn(code) {
          list.map(items, fn(item) { code <> item })
        })
      Any ->
        list.flat_map(codes, fn(code) {
          let position = int.min(list.length(string.split(code, "-")) - 1, 1)

          dict.get(positions, position)
          |> result.unwrap([])
          |> list.map(fn(part) { code <> part })
        })
    }
  })
  |> list.unique()
}

fn has_any(template: List(Segment)) -> Bool {
  list.contains(template, Any)
}

fn precedence(template: List(Segment)) -> Int {
  case template {
    [Fixed(_)] | [] -> 0
    _ ->
      case has_any(template) {
        False -> 1
        True -> 2
      }
  }
}

fn overlaps(a: List(String), b: List(String)) -> Bool {
  let size = int.min(list.length(a), list.length(b))

  list.take(a, size) == list.take(b, size)
}

fn merge_translations(
  high: List(Translation),
  low: List(Translation),
) -> List(Translation) {
  let missing =
    list.filter(low, fn(other) {
      !list.any(high, fn(translation) { overlaps(translation.path, other.path) })
    })

  list.append(high, missing)
}

pub type Resolved {
  Resolved(locales: List(Locale), warnings: List(String))
}

pub fn resolve_locale_wildcards(
  files: List(Locale),
) -> Result(Resolved, List(String)) {
  let #(templates, errors) =
    list.map(files, fn(file) {
      parse_template(file.name)
      |> result.map(fn(template) { #(file, template) })
      |> result.map_error(fn(error) { file.file <> ": " <> error })
    })
    |> result.partition()

  case errors {
    [_, ..] -> Error(list.reverse(errors))
    [] -> {
      let templates = list.reverse(templates)

      let positions =
        templates
        |> list.flat_map(fn(entry) {
          expand_template(
            entry.1,
            dict.from_list([#(0, [unknown_part]), #(1, [unknown_part])]),
          )
        })
        |> positions_of()

      let expanded =
        list.map(templates, fn(entry) {
          #(entry.0, precedence(entry.1), expand_template(entry.1, positions))
        })

      let warnings =
        list.filter_map(expanded, fn(entry) {
          case entry.2 {
            [] ->
              Ok(
                { entry.0 }.file
                <> ": doesn't match any locale, there is no existing code where `any` is",
              )
            _ -> Error(Nil)
          }
        })

      let locales =
        expanded
        |> list.flat_map(fn(entry) { entry.2 })
        |> list.unique()
        |> list.sort(string.compare)
        |> list.map(fn(code) {
          let assert [first, ..rest] =
            expanded
            |> list.filter(fn(entry) { list.contains(entry.2, code) })
            |> list.sort(fn(a, b) {
              int.compare(a.1, b.1)
              |> order.break_tie(string.compare({ a.0 }.name, { b.0 }.name))
            })
            |> list.map(fn(entry) { entry.0 })

          Locale(
            name: code,
            file: first.file,
            translations: list.fold(rest, first.translations, fn(high, low) {
              merge_translations(high, low.translations)
            }),
          )
        })

      Ok(Resolved(locales:, warnings:))
    }
  }
}
