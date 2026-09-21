import gleam/list
import gleam/string
import margot/internal
import margot/internal/locale

pub type Locale {
  Locale(locale: String, content: String)
  TomlLocale(locale: String, content: String)
  JsonLocale(locale: String, content: String)
  CsvLocale(locale: String, content: String)
}

fn file_name(file: Locale) -> String {
  case file {
    Locale(..) -> file.locale <> ".i18n.yaml"
    TomlLocale(..) -> file.locale <> ".i18n.toml"
    JsonLocale(..) -> file.locale <> ".i18n.json"
    CsvLocale(..) -> file.locale <> ".i18n.csv"
  }
}

pub fn single(file: Locale) -> String {
  multi([file])
}

pub fn multi(files: List(Locale)) -> String {
  case
    internal.prepare(
      internal.Scan(
        files: list.map(files, fn(file) {
          locale.File(name: file_name(file), content: file.content)
        }),
      ),
    )
  {
    Error(errors) ->
      panic as {
        "failed to prepare locales:\n"
        <> list.map(errors, fn(error) { "- " <> error }) |> string.join("\n")
      }
    Ok(prepared) -> internal.generate(prepared, "t").module
  }
}

pub fn warnings(files: List(Locale)) -> String {
  case
    internal.prepare(
      internal.Scan(
        files: list.map(files, fn(file) {
          locale.File(name: file_name(file), content: file.content)
        }),
      ),
    )
  {
    Error(errors) ->
      panic as {
        "failed to prepare locales:\n"
        <> list.map(errors, fn(error) { "- " <> error }) |> string.join("\n")
      }
    Ok(prepared) ->
      list.map(internal.generate(prepared, "t").warnings, fn(warning) {
        "- " <> warning
      })
      |> string.join("\n")
  }
}

pub fn prepare_error(files: List(Locale)) -> String {
  case
    internal.prepare(
      internal.Scan(
        files: list.map(files, fn(file) {
          locale.File(name: file_name(file), content: file.content)
        }),
      ),
    )
  {
    Error(errors) ->
      list.map(errors, fn(error) { "- " <> error })
      |> string.join("\n")
    Ok(_) -> panic as "failed to produce prepare error"
  }
}
