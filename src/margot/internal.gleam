import filepath
import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import margot/internal/check
import margot/internal/code
import margot/internal/fallback
import margot/internal/link.{type Function}
import margot/internal/locale.{type File, File}
import margot/internal/wildcard
import simplifile

fn find_project_root_path() -> Result(String, String) {
  use current_directory <- result.try(
    simplifile.current_directory()
    |> result.map_error(fn(error) {
      "the current directory couldn't be read: "
      <> simplifile.describe_error(error)
    }),
  )

  find_project_root_path_loop(current_directory, current_directory)
}

fn find_project_root_path_loop(
  path: String,
  start: String,
) -> Result(String, String) {
  case simplifile.is_file(filepath.join(path, "gleam.toml")) {
    Ok(True) -> Ok(path)
    _ -> {
      let parent = filepath.directory_name(path)

      case parent == path || parent == "" {
        True ->
          Error(
            "`gleam.toml` couldn't be found in `"
            <> start
            <> "` or its parents, margot should run inside a Gleam project",
          )
        False -> find_project_root_path_loop(parent, start)
      }
    }
  }
}

pub fn find_project_root() -> Result(String, String) {
  find_project_root_path()
}

pub type Scan {
  Scan(files: List(File))
}

pub fn scan(root_path: String) -> Result(Scan, List(String)) {
  let lang_path = filepath.join(root_path, "lang")

  use files <- result.try(
    simplifile.read_directory(lang_path)
    |> result.map_error(fn(error) {
      [
        "the `lang` directory couldn't be read ("
        <> simplifile.describe_error(error)
        <> "), create it next to `gleam.toml` with a `<locale>.i18n.yaml` (or `.i18n.toml`, `.i18n.json`, `.i18n.csv`) file per language",
      ]
    }),
  )

  let #(files, errors) =
    files
    |> list.filter(locale.is_locale_file)
    |> list.filter_map(fn(file) {
      case simplifile.read(filepath.join(lang_path, file)) {
        Error(error) ->
          Ok(Error(
            "lang/"
            <> file
            <> ": the file couldn't be read ("
            <> simplifile.describe_error(error)
            <> ")",
          ))
        Ok(content) -> Ok(Ok(File(name: file, content:)))
      }
    })
    |> result.partition()

  case errors {
    [] ->
      Ok(
        Scan(
          files: list.sort(files, fn(a, b) { string.compare(a.name, b.name) }),
        ),
      )
    errors -> Error(errors)
  }
}

pub type Prepared {
  Prepared(
    functions: List(Function),
    locales: List(String),
    default_locale: String,
    warnings: List(String),
  )
}

pub fn prepare(scanned: Scan) -> Result(Prepared, List(String)) {
  let #(raw_locales, errors) =
    list.map(scanned.files, locale.parse_locale)
    |> result.partition()

  use _ <- result.try(case errors {
    [] -> Ok(Nil)
    _ -> Error(errors |> list.reverse() |> list.flatten())
  })

  let raw_locales = list.reverse(raw_locales)

  use _ <- result.try(check.check_duplicate_files(raw_locales))

  use resolved <- result.try(wildcard.resolve_locale_wildcards(raw_locales))

  use default_locale <- result.try(
    fallback.default_locale(resolved.locales)
    |> result.replace_error([
      "no locale file found in `lang`, add one, for example `lang/en.i18n.yaml` (or `.i18n.toml`, `.i18n.json`, `.i18n.csv`)",
    ]),
  )

  use _ <- result.try(check.check_locales(resolved.locales, default_locale.name))

  let names = list.map(resolved.locales, fn(locale) { locale.name })

  let chains = fallback.fallback_chains(names, default_locale.name)

  use _ <- result.try(check.check_keys(resolved.locales, default_locale))
  use _ <- result.try(check.check_kinds(resolved.locales, default_locale))

  let paths =
    list.map(default_locale.translations, fn(translation) { translation.path })
  use _ <- result.try(check.check_names(paths, default_locale.file))

  let fallbacks =
    fallback.resolve_fallbacks(
      resolved.locales,
      chains,
      default_locale.name,
      paths,
    )

  let files =
    resolved.locales
    |> list.map(fn(locale) { #(locale.name, locale.file) })
    |> dict.from_list()

  use functions <- result.map(link.resolve_links(
    fallbacks.translations,
    default_locale.name,
    files,
  ))

  Prepared(
    functions:,
    locales: names,
    default_locale: default_locale.name,
    warnings: list.append(resolved.warnings, fallbacks.warnings),
  )
}

pub type Generated {
  Generated(module: String, ffi: String, warnings: List(String))
}

pub fn generate(prepared: Prepared, module_name: String) -> Generated {
  Generated(
    module: code.render_module(
      module_name,
      prepared.locales,
      prepared.default_locale,
      prepared.functions,
    ),
    ffi: code.ffi_content,
    warnings: prepared.warnings,
  )
}
