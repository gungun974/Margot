import gleam/dict
import gleam/list
import gleam/result
import gleam/string
import margot/internal/locale.{type Locale, type Translation}
import margot/internal/naming

pub fn default_locale(locales: List(Locale)) -> Result(Locale, Nil) {
  case list.find(locales, fn(locale) { locale.name == "en" }) {
    Ok(locale) -> Ok(locale)
    Error(_) -> list.first(locales) |> result.map(fn(locale) { locale })
  }
}

pub fn fallback_chain(
  locale: String,
  locales: List(String),
  default: String,
) -> List(String) {
  let language = naming.language_of(locale)

  let parent = case
    naming.is_region_locale(locale) && list.contains(locales, language)
  {
    True -> [language]
    False -> []
  }

  list.unique([locale, ..list.append(parent, [default])])
}

pub fn fallback_chains(
  locales: List(String),
  default: String,
) -> List(#(String, List(String))) {
  list.map(locales, fn(locale) {
    #(locale, fallback_chain(locale, locales, default))
  })
}

fn has_language_locale(locale: String, locales: List(String)) -> Bool {
  naming.is_region_locale(locale)
  && list.contains(locales, naming.language_of(locale))
}

pub type TranslationLocales {
  TranslationLocales(path: List(String), locales: List(TranslationLocale))
}

pub type TranslationLocale {
  TranslationLocale(locale: String, source: String, translation: Translation)
}

pub type Fallbacks {
  Fallbacks(translations: List(TranslationLocales), warnings: List(String))
}

pub fn resolve_fallbacks(
  locales: List(Locale),
  chains: List(#(String, List(String))),
  default: String,
  paths: List(List(String)),
) -> Fallbacks {
  let names = list.map(locales, fn(current) { current.name })
  let by_name =
    locales
    |> list.map(fn(current) { #(current.name, locale.by_path(current)) })
    |> dict.from_list()

  let resolved =
    list.map(locales, fn(current) {
      let assert Ok(chain) = list.key_find(chains, current.name)

      let #(translations, warnings) =
        list.fold(paths, #([], []), fn(acc, path) {
          let assert Ok(#(source, translation)) =
            list.find_map(chain, fn(name) {
              let assert Ok(candidate) = dict.get(by_name, name)
              dict.get(candidate, path)
              |> result.map(fn(translation) { #(name, translation) })
            })

          let warnings = case
            source == default
            && current.name != default
            && !has_language_locale(current.name, names)
          {
            True -> [
              current.file
                <> ": `"
                <> string.join(path, ".")
                <> "` is missing in `"
                <> current.name
                <> "`, `"
                <> default
                <> "` is used instead",
              ..acc.1
            ]
            False -> acc.1
          }

          #(
            [
              TranslationLocale(locale: current.name, source:, translation:),
              ..acc.0
            ],
            warnings,
          )
        })

      #(list.reverse(translations), list.reverse(warnings))
    })

  Fallbacks(
    translations: resolved
      |> list.map(fn(entry) { entry.0 })
      |> list.transpose()
      |> list.zip(paths, _)
      |> list.map(fn(entry) {
        TranslationLocales(path: entry.0, locales: entry.1)
      }),
    warnings: list.flat_map(resolved, fn(entry) { entry.1 }),
  )
}
