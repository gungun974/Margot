import gleam/list
import gleam/string
import margot/internal
import margot/internal/locale

pub type Locale {
  Locale(locale: String, content: String)
}

pub fn single(file: Locale) -> String {
  multi([file])
}

pub fn multi(files: List(Locale)) -> String {
  case
    internal.prepare(
      internal.Scan(
        files: list.map(files, fn(file) {
          locale.File(name: file.locale <> ".i18n.yaml", content: file.content)
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
          locale.File(name: file.locale <> ".i18n.yaml", content: file.content)
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
          locale.File(name: file.locale <> ".i18n.yaml", content: file.content)
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
