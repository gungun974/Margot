import gleam/dict.{type Dict}
import gleam/list
import gleam/result
import gleam/string
import margot/internal/locale.{
  type Locale, type Translation, Cardinal, Ordinal, Plural, Simple,
}
import margot/internal/naming

pub fn check_locales(
  locales: List(Locale),
  default: String,
) -> Result(Nil, List(String)) {
  let errors =
    list.filter_map(locales, fn(locale) {
      case naming.valid_locale_name(locale.name) {
        True -> Error(Nil)
        False ->
          Ok(
            locale.file
            <> ": `"
            <> locale.name
            <> "` isn't a valid locale name, expected something like `en` or `en-US`",
          )
      }
    })

  let errors = case list.any(locales, fn(locale) { locale.name == default }) {
    True -> errors
    False -> ["the default locale `" <> default <> "` doesn't exist", ..errors]
  }

  case errors {
    [] -> Ok(Nil)
    _ -> Error(errors)
  }
}

fn is_path_prefix(prefix: List(String), path: List(String)) -> Bool {
  list.take(path, list.length(prefix)) == prefix
}

fn proper_prefixes(path: List(String)) -> List(List(String)) {
  path
  |> list.index_map(fn(_, size) { list.take(path, size) })
  |> list.drop(1)
}

fn describe_translation(translation: Translation) -> String {
  case translation {
    Simple(..) -> "a string"
    Plural(kind: Cardinal, parameter:, ..) ->
      "a cardinal plural on `" <> parameter <> "`"
    Plural(kind: Ordinal, parameter:, ..) ->
      "an ordinal plural on `" <> parameter <> "`"
  }
}

fn describe_unknown_key(
  current: Locale,
  translation: Translation,
  default: Locale,
  default_by_path: Dict(List(String), Translation),
) -> String {
  let path = translation.path
  let same_everywhere = ". A key must be the same in every locale"
  let in_default = " in the default locale `" <> default.name <> "`"

  let translation_above =
    list.find_map(proper_prefixes(path), fn(prefix) {
      dict.get(default_by_path, prefix)
      |> result.map(fn(default_translation) { #(prefix, default_translation) })
    })

  let group_in_default =
    list.any(dict.keys(default_by_path), is_path_prefix(path, _))

  current.file
  <> ": `"
  <> case translation_above, group_in_default {
    Ok(#(prefix, default_translation)), _ ->
      string.join(prefix, ".")
      <> "` is a group, but it is "
      <> describe_translation(default_translation)
      <> in_default
      <> same_everywhere
    Error(Nil), True ->
      string.join(path, ".")
      <> "` is "
      <> describe_translation(translation)
      <> ", but it is a group"
      <> in_default
      <> same_everywhere
    Error(Nil), False ->
      string.join(path, ".")
      <> "` doesn't exist"
      <> in_default
      <> ", add it to "
      <> default.file
      <> " or remove it"
  }
}

pub fn check_keys(
  locales: List(Locale),
  default: Locale,
) -> Result(Nil, List(String)) {
  let default_by_path = locale.by_path(default)

  let errors =
    list.flat_map(locales, fn(current) {
      list.filter_map(current.translations, fn(translation) {
        case dict.has_key(default_by_path, translation.path) {
          True -> Error(Nil)
          False ->
            Ok(describe_unknown_key(
              current,
              translation,
              default,
              default_by_path,
            ))
        }
      })
    })

  case errors {
    [] -> Ok(Nil)
    _ -> Error(list.unique(errors))
  }
}

pub fn check_kinds(
  locales: List(Locale),
  default: Locale,
) -> Result(Nil, List(String)) {
  let default_by_path = locale.by_path(default)

  let errors =
    list.flat_map(locales, fn(current) {
      list.filter_map(current.translations, fn(translation) {
        let assert Ok(default_translation) =
          dict.get(default_by_path, translation.path)

        case
          describe_translation(default_translation)
          == describe_translation(translation)
        {
          True -> Error(Nil)
          False ->
            Ok(
              current.file
              <> ": `"
              <> string.join(translation.path, ".")
              <> "` is "
              <> describe_translation(translation)
              <> ", but it is "
              <> describe_translation(default_translation)
              <> " in the default locale `"
              <> default.name
              <> "`. A key must be the same in every locale",
            )
        }
      })
    })

  case errors {
    [] -> Ok(Nil)
    _ -> Error(list.unique(errors))
  }
}

fn join_paths(paths: List(List(String))) -> String {
  let paths = list.map(paths, fn(path) { "`" <> string.join(path, ".") <> "`" })

  case list.reverse(paths) {
    [last, second_to_last, ..before] ->
      string.join(list.reverse([second_to_last, ..before]), ", ")
      <> " and "
      <> last
    _ -> string.join(paths, ", ")
  }
}

const reserved_function_names = ["auto_", "detect_locale_"]

pub fn check_names(
  paths: List(List(String)),
  default_file: String,
) -> Result(Nil, List(String)) {
  let file = default_file <> ": "

  let reserved =
    list.filter_map(paths, fn(path) {
      let name = naming.function_name(path)

      case list.contains(reserved_function_names, name) {
        True ->
          Ok(
            file
            <> naming.path_error_message(
              "would generate the function `"
                <> name
                <> "`, which is already used by margot. Rename the key",
              path,
            ),
          )
        False -> Error(Nil)
      }
    })

  let names = list.map(paths, naming.function_name)

  let duplicated =
    names
    |> list.unique()
    |> list.filter_map(fn(name) {
      let same =
        list.zip(paths, names)
        |> list.filter(fn(entry) { entry.1 == name })
        |> list.map(fn(entry) { entry.0 })

      case same {
        [_, _, ..] ->
          Ok(
            file
            <> join_paths(same)
            <> " generate the same function `"
            <> name
            <> "`. Rename one of them",
          )
        _ -> Error(Nil)
      }
    })

  case list.flatten([reserved, duplicated]) {
    [] -> Ok(Nil)
    errors -> Error(list.unique(errors))
  }
}
