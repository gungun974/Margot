import gleam/int
import gleam/list
import gleam/string
import margot/internal/format
import margot/internal/link.{
  type Function, type Part, PartParameter, PartPlural, PartText,
}
import margot/internal/locale.{
  type PluralForms, type PluralKind, Float, Int, String,
}
import margot/internal/naming
import margot/internal/plural.{Exact, When}

fn pad(indent: Int) -> String {
  string.repeat("  ", indent)
}

fn quote(text: String) -> String {
  let escaped =
    text
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
    |> string.replace("\r", "\\r")
    |> string.replace("\t", "\\t")

  "\"" <> escaped <> "\""
}

fn render_tokens(parts: List(Part), indent: Int) -> List(String) {
  case parts {
    [] -> ["\"\""]
    [PartPlural(kind:, parameter:, language:, forms:)] -> [
      render_plural(kind, parameter, language, forms, indent),
    ]
    _ ->
      list.map(parts, fn(part) {
        case part {
          PartText(text) -> quote(text)
          PartParameter(name:, type_: String) ->
            naming.sanitize_identifier(name)
          PartParameter(name:, type_: Int) ->
            "int.to_string(" <> naming.sanitize_identifier(name) <> ")"
          PartParameter(name:, type_: Float) ->
            "float.to_string(" <> naming.sanitize_identifier(name) <> ")"
          PartPlural(kind:, parameter:, language:, forms:) ->
            "{\n"
            <> pad(indent + 1)
            <> render_plural(kind, parameter, language, forms, indent + 1)
            <> "\n"
            <> pad(indent)
            <> "}"
        }
      })
  }
}

fn render_parts(parts: List(Part), indent: Int) -> String {
  render_tokens(parts, indent) |> string.join(" <> ")
}

fn render_arm(head: String, parts: List(Part), indent: Int) -> String {
  let tokens = render_tokens(parts, indent + 1)
  let body = string.join(tokens, " <> ")
  let line = pad(indent) <> head <> " -> " <> body
  let next_line = pad(indent + 1) <> body
  let multiline = string.contains(body, "\n")

  case multiline, string.length(line) > 80, string.length(next_line) > 80 {
    False, False, _ -> line
    False, True, False -> pad(indent) <> head <> " ->\n" <> next_line
    _, _, _ ->
      pad(indent)
      <> head
      <> " ->\n"
      <> pad(indent + 1)
      <> case tokens {
        [token] -> token
        _ -> string.join(tokens, "\n" <> pad(indent + 1) <> "<> ")
      }
  }
}

fn render_guard_arm(guard: String, parts: List(Part), indent: Int) -> String {
  case string.length(pad(indent) <> "_ if " <> guard <> " ->") > 80 {
    False -> render_arm("_ if " <> guard, parts, indent)
    True -> {
      let operands =
        guard
        |> string.replace(" && ", "\n&& ")
        |> string.replace(" || ", "\n|| ")
        |> string.split("\n")

      let assert [first, ..rest] = operands

      string.join(
        [
          pad(indent) <> "_",
          pad(indent + 1) <> "if " <> first,
          ..list.append(
            list.map(rest, fn(operand) { pad(indent + 1) <> operand }),
            [
              pad(indent) <> "-> " <> render_parts(parts, indent),
            ],
          )
        ],
        "\n",
      )
    }
  }
}

fn render_plural(
  kind: PluralKind,
  parameter: String,
  language: String,
  forms: PluralForms(List(Part)),
  indent: Int,
) -> String {
  let variable = naming.sanitize_identifier(parameter)
  let other = forms.other

  case plural.plural_arms(kind, language, forms) {
    [] -> render_parts(other, indent)
    arms -> {
      let arms =
        list.map(arms, fn(arm) {
          case arm.0 {
            Exact(numbers) ->
              render_arm(
                numbers |> list.map(int.to_string) |> string.join(" | "),
                arm.1,
                indent + 1,
              )
            When(guard) -> render_guard_arm(guard(variable), arm.1, indent + 1)
          }
        })

      string.join(
        [
          "case " <> variable <> " {",
          ..list.append(arms, [
            render_arm("_", other, indent + 1),
            pad(indent) <> "}",
          ])
        ],
        "\n",
      )
    }
  }
}

fn used_parameters(parts: List(Part)) -> List(String) {
  list.flat_map(parts, fn(part) {
    case part {
      PartText(_) -> []
      PartParameter(name:, ..) -> [name]
      PartPlural(kind:, parameter:, language:, forms:) -> {
        let arms = plural.plural_arms(kind, language, forms)
        let reachable =
          list.flat_map(
            [forms.other, ..list.map(arms, fn(a) { a.1 })],
            used_parameters,
          )

        case arms {
          [] -> reachable
          _ -> [parameter, ..reachable]
        }
      }
    }
  })
}

fn variant_name(locale: String) -> String {
  locale
  |> string.split("-")
  |> list.map(fn(part) { string.capitalise(string.lowercase(part)) })
  |> string.concat()
}

fn group_branches(
  branches: List(#(String, List(Part))),
) -> List(#(List(String), List(Part))) {
  list.fold(
    branches,
    [],
    fn(groups: List(#(String, List(String), List(Part))), branch) {
      let #(variant, parts) = branch
      let code = render_parts(parts, 3)

      case list.any(groups, fn(group) { group.0 == code }) {
        True ->
          list.map(groups, fn(group) {
            case group.0 == code {
              True -> #(code, list.append(group.1, [variant]), group.2)
              False -> group
            }
          })
        False -> list.append(groups, [#(code, [variant], parts)])
      }
    },
  )
  |> list.map(fn(group) { #(group.1, group.2) })
}

fn render_function(function: Function) -> String {
  let used =
    list.flat_map(function.locales, fn(locale) { used_parameters(locale.1) })

  let arguments = [
    "locale_: Locale",
    ..list.map(function.parameters, fn(parameter) {
      let label = naming.sanitize_identifier(parameter.0)
      let variable = case list.contains(used, parameter.0) {
        True -> label
        False -> "_" <> label
      }

      label <> " " <> variable <> ": " <> link.type_name(parameter.1)
    })
  ]

  let name = naming.function_name(function.path)

  let signature = case
    string.length(
      "pub fn "
      <> name
      <> "("
      <> string.join(arguments, ", ")
      <> ") -> String {",
    )
    > 80
  {
    False ->
      "pub fn "
      <> name
      <> "("
      <> string.join(arguments, ", ")
      <> ") -> String {"
    True ->
      "pub fn "
      <> name
      <> "(\n"
      <> string.join(
        list.map(arguments, fn(argument) { "  " <> argument <> "," }),
        "\n",
      )
      <> "\n) -> String {"
  }

  let branches =
    function.locales
    |> list.map(fn(locale) { #(variant_name(locale.0), locale.1) })
    |> group_branches()
    |> list.map(fn(group) {
      render_arm(string.join(group.0, " | "), group.1, 2)
    })

  string.join(
    [signature, "  case locale_ {", ..list.append(branches, ["  }", "}"])],
    "\n",
  )
}

pub const ffi_content = "export function detect_locale() {
  let tag = \"\";

  if (typeof navigator !== \"undefined\") {
    if (Array.isArray(navigator.languages) && navigator.languages.length > 0) {
      tag = navigator.languages[0];
    } else if (navigator.language) {
      tag = navigator.language;
    }
  }

  try {
    return new Intl.Locale(tag).toString().toLowerCase();
  } catch (_error) {
    return tag.replace(\"_\", \"-\").toLowerCase();
  }
}
"

fn render_auto(locales: List(String), default: String) -> String {
  let #(regions, languages) = list.partition(locales, naming.is_region_locale)

  let default_variant = variant_name(default)

  let region_arms =
    list.map(regions, fn(locale) {
      pad(2)
      <> quote(string.lowercase(locale))
      <> " -> "
      <> variant_name(locale)
    })

  let language_arms =
    list.map(languages, fn(locale) {
      "["
      <> quote(string.lowercase(locale))
      <> ", ..] -> "
      <> variant_name(locale)
    })

  let by_language = fn(subject: String, indent: Int) {
    string.join(
      [
        pad(indent) <> "case string.split(" <> subject <> ", \"-\") {",
        ..list.append(
          list.map(language_arms, fn(arm) { pad(indent + 1) <> arm }),
          [pad(indent + 1) <> "_ -> " <> default_variant, pad(indent) <> "}"],
        )
      ],
      "\n",
    )
  }

  let body = case regions, languages {
    [], [] -> pad(1) <> default_variant
    [], _ -> by_language("detect_locale_()", 1)
    _, [] ->
      string.join(
        [
          pad(1) <> "case detect_locale_() {",
          ..list.append(region_arms, [
            pad(2) <> "_ -> " <> default_variant,
            pad(1) <> "}",
          ])
        ],
        "\n",
      )
    _, _ ->
      string.join(
        [
          pad(1) <> "case detect_locale_() {",
          ..list.append(region_arms, [
            pad(2) <> "tag ->\n" <> by_language("tag", 3),
            pad(1) <> "}",
          ])
        ],
        "\n",
      )
  }

  "pub fn auto_() -> Locale {\n" <> body <> "\n}"
}

pub fn ffi_file_name(module_name: String) -> String {
  module_name <> "_ffi.mjs"
}

pub fn render_module(
  module_name: String,
  locales: List(String),
  default: String,
  functions: List(Function),
) -> String {
  let locale_type =
    "pub type Locale {\n"
    <> string.join(
      list.map(locales, fn(locale) { "  " <> variant_name(locale) }),
      "\n",
    )
    <> "\n}"

  let ffi_file = ffi_file_name(module_name)

  let detect_locale =
    "@external(javascript, \"./"
    <> ffi_file
    <> "\", \"detect_locale\")\nfn detect_locale_() -> String {\n  \"\"\n}"

  let code =
    string.join(
      [
        locale_type,
        detect_locale,
        render_auto(locales, default),
        ..list.map(functions, render_function)
      ],
      "\n\n",
    )

  let imports =
    [
      #("gleam/float", "float.to_string("),
      #("gleam/int", "int.to_string("),
      #("gleam/string", "string.split("),
    ]
    |> list.filter(fn(module) { string.contains(code, module.1) })
    |> list.map(fn(module) { "import " <> module.0 })

  let header = "//// Generated by margot, do not edit.\n\n"

  let code = case imports {
    [] -> header <> code <> "\n"
    _ -> header <> string.join(imports, "\n") <> "\n\n" <> code <> "\n"
  }
  case format.format_gleam_code(code) {
    Ok(code) -> code
    Error(_) -> code
  }
}
