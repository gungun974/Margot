import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/result
import gleam/string
import margot/internal/fallback.{type TranslationLocale, type TranslationLocales}
import margot/internal/locale.{
  type Pattern, type PluralForms, type PluralKind, type Type, Absolute, Float,
  Int, Link, Parameter, Plural, PluralForms, Relative, Simple, String, Text,
}
import margot/internal/naming

pub type Part {
  PartText(String)
  PartParameter(name: String, type_: Type)
  PartPlural(
    kind: PluralKind,
    parameter: String,
    language: String,
    forms: PluralForms(List(Part)),
  )
}

fn merge_texts(parts: List(Part)) -> List(Part) {
  case parts {
    [PartText(""), ..rest] -> merge_texts(rest)
    [PartText(a), PartText(b), ..rest] ->
      merge_texts([PartText(a <> b), ..rest])
    [part, ..rest] -> [part, ..merge_texts(rest)]
    [] -> []
  }
}

fn parent_path(path: List(String)) -> List(String) {
  list.take(path, list.length(path) - 1)
}

type Index =
  Dict(#(String, List(String)), TranslationLocale)

fn resolve_patterns(
  patterns: List(Pattern),
  scope: List(String),
  locale: String,
  index: Index,
  visiting: List(List(String)),
) -> Result(List(Part), String) {
  list.try_fold(patterns, [], fn(acc, pattern) {
    case pattern {
      Text(text) -> Ok([PartText(text), ..acc])
      Parameter(name:, type_:) -> Ok([PartParameter(name:, type_:), ..acc])
      Link(link) -> {
        use path <- result.try(case link {
          Absolute(path) -> Ok(path)
          Relative(up:, path:) ->
            case up > list.length(scope) {
              True ->
                Error(
                  "the link `@:{"
                  <> string.repeat(".", up + 1)
                  <> string.join(path, ".")
                  <> "}` goes above the root",
                )
              False ->
                Ok(list.append(list.take(scope, list.length(scope) - up), path))
            }
        })

        use parts <- result.try(resolve_link(path, locale, index, visiting))

        Ok(list.append(list.reverse(parts), acc))
      }
    }
  })
  |> result.map(fn(parts) { parts |> list.reverse() |> merge_texts() })
}

fn resolve_link(
  path: List(String),
  locale: String,
  index: Index,
  visiting: List(List(String)),
) -> Result(List(Part), String) {
  case list.contains(visiting, path) {
    True -> {
      let cycle =
        list.take_while(visiting, fn(visited) { visited != path })
        |> list.reverse()

      Error(
        "the links form a cycle: "
        <> [path, ..list.append(cycle, [path])]
        |> list.map(fn(path) { "`" <> string.join(path, ".") <> "`" })
        |> string.join(" → "),
      )
    }
    False ->
      case dict.get(index, #(locale, path)) {
        Ok(translation_locale) ->
          resolve_entry(translation_locale, index, [path, ..visiting])
        Error(Nil) -> {
          let is_group =
            dict.keys(index)
            |> list.any(fn(key) {
              key.0 == locale && list.take(key.1, list.length(path)) == path
            })

          case is_group {
            True ->
              Error(
                "the link `@:{"
                <> string.join(path, ".")
                <> "}` targets a group, a link must target a translation",
              )
            False ->
              Error(
                "the link `@:" <> string.join(path, ".") <> "` doesn't exist",
              )
          }
        }
      }
  }
}

fn resolve_entry(
  translation_locale: TranslationLocale,
  index: Index,
  visiting: List(List(String)),
) -> Result(List(Part), String) {
  let locale = translation_locale.locale

  let scope = parent_path(translation_locale.translation.path)

  case translation_locale.translation {
    Simple(patterns:, ..) ->
      resolve_patterns(patterns, scope, locale, index, visiting)
    Plural(kind:, parameter:, forms:, ..) -> {
      let resolve = fn(patterns) {
        resolve_patterns(patterns, scope, locale, index, visiting)
      }
      let resolve_optional = fn(patterns) {
        case patterns {
          Some(patterns) -> resolve(patterns) |> result.map(Some)
          None -> Ok(None)
        }
      }

      use zero <- result.try(resolve_optional(forms.zero))
      use one <- result.try(resolve_optional(forms.one))
      use two <- result.try(resolve_optional(forms.two))
      use few <- result.try(resolve_optional(forms.few))
      use many <- result.try(resolve_optional(forms.many))
      use other <- result.try(resolve(forms.other))

      Ok([
        PartPlural(
          kind:,
          parameter:,
          language: naming.language_of(translation_locale.source),
          forms: PluralForms(zero:, one:, two:, few:, many:, other:),
        ),
      ])
    }
  }
}

type ParameterSource {
  ParameterSource(name: String, type_: Type, locale: String)
}

pub fn type_name(type_: Type) -> String {
  case type_ {
    String -> "String"
    Int -> "Int"
    Float -> "Float"
  }
}

fn type_with_article(type_: Type) -> String {
  case type_ {
    String -> "a `String`"
    Int -> "an `Int`"
    Float -> "a `Float`"
  }
}

fn add_parameter(
  parameters: List(ParameterSource),
  name: String,
  type_: Type,
  locale: String,
) -> Result(List(ParameterSource), String) {
  case list.find(parameters, fn(parameter) { parameter.name == name }) {
    Ok(existing) if existing.type_ == type_ -> Ok(parameters)
    Ok(existing) -> {
      let example = "`{" <> name <> ": " <> type_name(existing.type_) <> "}`"

      case existing.locale == locale {
        True ->
          Error(
            "the parameter `"
            <> name
            <> "` is used as both "
            <> type_with_article(existing.type_)
            <> " and "
            <> type_with_article(type_)
            <> " in `"
            <> locale
            <> "`. A parameter must have the same type everywhere, links included, for example "
            <> example,
          )
        False ->
          Error(
            "the parameter `"
            <> name
            <> "` is "
            <> type_with_article(existing.type_)
            <> " in `"
            <> existing.locale
            <> "` but "
            <> type_with_article(type_)
            <> " in `"
            <> locale
            <> "`. A parameter must have the same type in every locale, for example "
            <> example,
          )
      }
    }
    Error(Nil) ->
      Ok(list.append(parameters, [ParameterSource(name:, type_:, locale:)]))
  }
}

fn collect_parameters(
  parts: List(Part),
  locale: String,
  parameters: List(ParameterSource),
) -> Result(List(ParameterSource), String) {
  list.try_fold(parts, parameters, fn(parameters, part) {
    case part {
      PartText(_) -> Ok(parameters)
      PartParameter(name:, type_:) ->
        add_parameter(parameters, name, type_, locale)
      PartPlural(parameter:, forms:, ..) -> {
        use parameters <- result.try(add_parameter(
          parameters,
          parameter,
          Int,
          locale,
        ))

        [forms.zero, forms.one, forms.two, forms.few, forms.many]
        |> option.values()
        |> list.append([forms.other])
        |> list.try_fold(parameters, fn(parameters, parts) {
          collect_parameters(parts, locale, parameters)
        })
      }
    }
  })
}

pub type Function {
  Function(
    path: List(String),
    parameters: List(#(String, Type)),
    locales: List(#(String, List(Part))),
  )
}

fn build_function(
  path: List(String),
  translation_locales: List(TranslationLocale),
  index: Index,
  default: String,
) -> Result(Function, List(#(String, String))) {
  let #(resolved, errors) =
    list.map(translation_locales, fn(translation_locale) {
      let locale = translation_locale.locale

      resolve_entry(translation_locale, index, [path])
      |> result.map(fn(parts) { #(locale, parts) })
      |> result.map_error(fn(message) {
        #(locale, naming.path_error_message(message, path))
      })
    })
    |> result.partition()
    |> pair.map_first(list.reverse)
    |> pair.map_second(list.reverse)

  case errors {
    [_, ..] -> Error(errors)
    [] -> {
      let #(defaults, others) =
        list.partition(resolved, fn(locale) { locale.0 == default })

      let parameters =
        list.try_fold(list.append(defaults, others), [], fn(parameters, locale) {
          collect_parameters(locale.1, locale.0, parameters)
          |> result.map_error(fn(message) {
            #(locale.0, naming.path_error_message(message, path))
          })
        })

      case parameters {
        Error(error) -> Error([error])
        Ok(parameters) ->
          case
            list.find(parameters, fn(parameter) { parameter.name == "locale_" })
          {
            Ok(reserved) ->
              Error([
                #(
                  reserved.locale,
                  naming.path_error_message(
                    "the parameter `locale_` is reserved, it is the first argument of every generated function. Rename it, for example `{language}`",
                    path,
                  ),
                ),
              ])
            Error(Nil) ->
              Ok(Function(
                path:,
                parameters: list.map(parameters, fn(parameter) {
                  #(parameter.name, parameter.type_)
                }),
                locales: resolved,
              ))
          }
      }
    }
  }
}

fn format_errors(
  errors: List(#(String, String)),
  default: String,
  files: Dict(String, String),
) -> List(String) {
  let #(from_default, others) =
    list.partition(errors, fn(error) { error.0 == default })

  list.append(from_default, others)
  |> list.fold(#([], []), fn(acc, error) {
    case list.contains(acc.0, error.1) {
      True -> acc
      False -> #([error.1, ..acc.0], [
        { dict.get(files, error.0) |> result.unwrap(error.0) }
          <> ": "
          <> error.1,
        ..acc.1
      ])
    }
  })
  |> fn(acc) { list.reverse(acc.1) }
}

pub fn resolve_links(
  translations: List(TranslationLocales),
  default: String,
  files: Dict(String, String),
) -> Result(List(Function), List(String)) {
  let index =
    translations
    |> list.flat_map(fn(translation) { translation.locales })
    |> list.map(fn(translation_locale) {
      #(
        #(translation_locale.locale, translation_locale.translation.path),
        translation_locale,
      )
    })
    |> dict.from_list()

  let #(functions, errors) =
    translations
    |> list.map(fn(translation) {
      build_function(translation.path, translation.locales, index, default)
    })
    |> result.partition()
    |> pair.map_first(list.reverse)
    |> pair.map_second(list.reverse)

  case errors {
    [] -> Ok(functions)
    _ -> Error(format_errors(list.flatten(errors), default, files))
  }
}
