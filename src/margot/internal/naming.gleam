import gleam/list
import gleam/string

pub fn is_valid_gleam_name(value: String) -> Bool {
  value != ""
  && value
  |> string.to_utf_codepoints()
  |> list.all(fn(cp) {
    let n = string.utf_codepoint_to_int(cp)

    { n >= 97 && n <= 122 } || { n >= 48 && n <= 57 } || n == 95
  })
  && !list.any(string.to_graphemes("0123456789"), string.starts_with(value, _))
}

const gleam_keywords = [
  "as", "assert", "auto", "case", "const", "delegate", "derive", "echo", "else",
  "fn", "if", "implement", "import", "let", "macro", "opaque", "panic", "pub",
  "test", "todo", "type", "use",
]

pub fn sanitize_identifier(name: String) -> String {
  case list.contains(gleam_keywords, name) {
    True -> name <> "_"
    False -> name
  }
}

pub fn function_name(path: List(String)) -> String {
  sanitize_identifier(string.join(path, "__"))
}

pub fn valid_locale_name(name: String) -> Bool {
  string.split(name, "-")
  |> list.all(fn(part) {
    part != ""
    && list.all(string.to_graphemes(part), fn(char) {
      is_valid_gleam_name(string.lowercase(char)) && char != "_"
    })
  })
}

pub fn language_of(locale: String) -> String {
  case string.split_once(locale, "-") {
    Ok(#(language, _)) -> language
    Error(Nil) -> locale
  }
}

pub fn is_region_locale(locale: String) -> Bool {
  language_of(locale) != locale
}

pub fn path_error_message(message: String, path: List(String)) -> String {
  case path {
    [] -> message
    _ -> "`" <> string.join(path, ".") <> "`: " <> message
  }
}
