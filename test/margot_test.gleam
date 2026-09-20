import birdie
import gleam/list
import gleeunit
import simulate.{Locale}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn readme_example_test() {
  simulate.multi([
    Locale(
      locale: "en",
      content: "
home:
  title: \"Welcome back!\"
  greeting: \"Hello {name}\"
  unread_messages:
    one: \"You have {n} unread message\"
    other: \"You have {n} unread messages\"

buttons:
  save: \"Save\"
  cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "fr",
      content: "
home:
  title: \"Bon retour !\"
  greeting: \"Bonjour {name}\"
  unread_messages:
    one: \"Vous avez {n} message non lu\"
    other: \"Vous avez {n} messages non lus\"

buttons:
  save: \"Enregistrer\"
  cancel: \"Annuler\"
",
    ),
  ])
  |> birdie.snap("README example")
}

pub fn simple_literal_test() {
  simulate.single(Locale(
    locale: "fr",
    content: "
title: \"titre\"
",
  ))
  |> birdie.snap("simple literal")
}

//! PARAMETER -------------------------------------------------------------------

pub fn basic_parameter_test() {
  simulate.single(Locale(
    locale: "fr",
    content: "
edit_track: \"Modifier le morceau {name}\"
",
  ))
  |> birdie.snap("basic parameter")
}

pub fn multi_parameters_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
hello: \"Hello {name}. I am {height}m.\"
",
  ))
  |> birdie.snap("multi parameters")
}

pub fn custom_parameter_type_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
greet: \"Hello {name}, you are {age: Int} years old\"
",
  ))
  |> birdie.snap("custom parameter type")
}

pub fn default_n_parameter_test() {
  simulate.single(Locale(
    locale: "fr",
    content: "
nb: \"{n}\"
",
  ))
  |> birdie.snap("default n parameter")
}

pub fn escape_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
greet: \"Hello \\\\{name}, you are \\\\{age: Int} years old\"
",
  ))
  |> birdie.snap("escape parameter")
}

//! GROUP -----------------------------------------------------------------------

pub fn group_test() {
  simulate.single(Locale(
    locale: "fr",
    content: "
locale: \"Français\"
general:
  title: \"Titre\"
  create: \"Créer\"
",
  ))
  |> birdie.snap("group")
}

pub fn nested_group_test() {
  simulate.single(Locale(
    locale: "fr",
    content: "
locale: \"Français\"
notifications:
  created_track:
    title: \"Morceau créé\"
    message: \"Le morceau {name} a bien été créé\"
  edited_track:
    title: \"Morceau modifié\"
    message: \"Le morceau {name} a bien été modifié\"
",
  ))
  |> birdie.snap("nested group")
}

//! ABSOLUTE LINKED TRANSLATION -------------------------------------------------

pub fn absolute_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
fields:
  name: \"my name is {first_name}\"
  age: \"I am {age} years old\"
introduce: \"Hello, @:{fields.name} and @:{fields.age}\"
",
  ))
  |> birdie.snap("absolute linked translation")
}

pub fn absolute_merged_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
first: \"Hi {name}\"
second: \"Bye {name}\"
both: \"@:{first}, @:{second}\"
",
  ))
  |> birdie.snap("absolute merged linked translation")
}

pub fn absolute_deep_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
first: \"1@:{second}\"
second: \"2@:{third}\"
third: \"3\"
",
  ))
  |> birdie.snap("absolute deep linked translation")
}

pub fn absolute_recursive_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
zero: \"0\"
first: \"1@:{second}\"
second: \"2@:{third}\"
third: \"3@:{first}\"
loop: \"@:{loop}\"
",
    ),
  ])
  |> birdie.snap("absolute recursive linked translation")
}

pub fn absolute_invalid_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
fields:
  name: \"my name is {first_name}\"
  age: \"I am {age} years old\"
invalid: \"@:{fields}\"
",
    ),
  ])
  |> birdie.snap("absolute invalid linked translation")
}

pub fn escape_absolute_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
introduce: \"Hello, \\\\@:{fields.name} and \\\\@:{fields.age}\"
",
  ))
  |> birdie.snap("escape absolute linked translation")
}

pub fn not_a_absolute_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
introduce: \"Hello, @:fields.name and @{fields_age} :{fields_height}\"
",
  ))
  |> birdie.snap("not a absolute linked translation")
}

//! RELATIVE LINKED TRANSLATION -------------------------------------------------

pub fn relative_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
remaining_time:
  hours_unit: \"{h}h\"
  minutes_unit: \"{m}m\"
  hours: \"@:{.hours_unit} @:{.minutes_unit}\"
",
  ))
  |> birdie.snap("relative linked translation")
}

pub fn relative_merged_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
group:
  first: \"Hi {name}\"
  second: \"Bye {name}\"
  both: \"@:{.first}, @:{.second}\"
",
  ))
  |> birdie.snap("relative merged linked translation")
}

pub fn relative_deep_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
group:
  first: \"1@:{.second}\"
  second: \"2@:{.third}\"
  third: \"3\"
",
  ))
  |> birdie.snap("relative deep linked translation")
}

pub fn relative_traverse_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
first:
  floor: \"first floor\"
  second: 
    floor: \"second floor\"
    third:
      floor: \"third floor\"
    parent: \"@:{..floor}\"
    self: \"@:{.floor}\"
    child: \"@:{.third.floor}\"
",
  ))
  |> birdie.snap("relative traverse linked translation")
}

pub fn relative_parent_deep_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
floor: \"ground floor\"
first:
  floor: \"first floor\"
  second:
    floor: \"second floor\"
    third:
      parent: \"@:{..floor}\"
      grandparent: \"@:{...floor}\"
      root: \"@:{....floor}\"
",
  ))
  |> birdie.snap("relative parent deep linked translation")
}

pub fn relative_parent_child_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
first:
  other:
    floor: \"other floor\"
  second:
    cousin: \"@:{..other.floor}\"
",
  ))
  |> birdie.snap("relative parent child linked translation")
}

pub fn relative_parent_recursive_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
group:
  first: \"1@:{.sub.back}\"
  sub:
    back: \"2@:{..first}\"
",
    ),
  ])
  |> birdie.snap("relative parent recursive linked translation")
}

pub fn relative_parent_above_root_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
floor: \"ground floor\"
group:
  above: \"@:{...floor}\"
",
    ),
  ])
  |> birdie.snap("relative parent above root linked translation")
}

pub fn relative_parent_invalid_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
group:
  fields:
    name: \"my name\"
  sub:
    invalid: \"@:{..fields}\"
",
    ),
  ])
  |> birdie.snap("relative parent invalid linked translation")
}

pub fn relative_recursive_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
group:
  zero: \"0\"
  first: \"1@:{.second}\"
  second: \"2@:{.third}\"
  third: \"3@:{.first}\"
  loop: \"@:{.loop}\"
",
    ),
  ])
  |> birdie.snap("relative recursive linked translation")
}

pub fn relative_invalid_linked_translation_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
group:
  fields:
    name: \"my name is {first_name}\"
    age: \"I am {age} years old\"
  invalid: \"@:{.fields}\"
",
    ),
  ])
  |> birdie.snap("relative invalid linked translation")
}

pub fn escape_relative_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
group:
  introduce: \"Hello, \\\\@:{.fields.name} and \\\\@:{.fields.age}\"
",
  ))
  |> birdie.snap("escape relative linked translation")
}

//! CARDINAL PLURAL -------------------------------------------------------------

pub fn cardinal_plural_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apple:
  one: \"I have {n} apple.\"
  other: \"I have {n} apples.\"
",
  ))
  |> birdie.snap("cardinal plural")
}

pub fn cardinal_plural_modifier_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apple(cardinal):
  one: \"I have {n} apple.\"
  other: \"I have {n} apples.\"
",
  ))
  |> birdie.snap("cardinal plural modifier")
}

pub fn cardinal_plural_multi_parameters_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
playlist_track_count:
  one: \"\\\"{name}\\\" has {n} track.\"
  other: \"\\\"{name}\\\" has {n} tracks.\"
",
  ))
  |> birdie.snap("cardinal plural multi parameters")
}

pub fn cardinal_plural_partial_parameters_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
playlist_track_count:
  zero: \"There are no tracks.\"
  one: \"\\\"{name}\\\" has one track.\"
  other: \"There are {n} tracks.\"
",
  ))
  |> birdie.snap("cardinal plural partial parameters")
}

pub fn cardinal_plural_unused_n_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
playlist_track_count:
  one: \"There is one track.\"
  other: \"There are several tracks.\"
",
  ))
  |> birdie.snap("cardinal plural unused n parameter")
}

pub fn cardinal_plural_custom_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apple(cardinal=count):
  one: \"I have {count} apple.\"
  other: \"I have {count} apples.\"
",
  ))
  |> birdie.snap("cardinal custom parameter")
}

pub fn cardinal_plural_custom_paramer_and_n_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apple(cardinal=count):
  one: \"I have {count} apple with a score of {n}.\"
  other: \"I have {count} apples with a score of {n}.\"
",
  ))
  |> birdie.snap("cardinal custom parameter and n")
}

pub fn cardinal_plural_merged_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apples:
  one: \"one apple\"
  other: \"{n} apples\"
bananas:
  one: \"one banana\"
  other: \"{n} bananas\"
absolue: \"I have @:{apples} and @:{bananas}\"
relative: \"I have @:{.apples} and @:{.bananas}\"
",
  ))
  |> birdie.snap("cardinal plural merged linked translation test")
}

pub fn cardinal_plural_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apples(cardinal=apple_count):
  one: \"one apple\"
  other: \"{apple_count} apples\"
bananas(cardinal=banana_count):
  one: \"one banana\"
  other: \"{banana_count} bananas\"
absolue: \"I have @:{apples} and @:{bananas}\"
relative: \"I have @:{.apples} and @:{.bananas}\"
",
  ))
  |> birdie.snap("cardinal plural linked translation test")
}

pub fn cardinal_plural_cldr_test() {
  // The languages supported out of the box, checked against
  // https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html
  let locales = [
    "ar", "cs", "de", "en", "es", "fr", "he", "id", "it", "ja", "ko", "ms", "pl",
    "pt", "ru", "sv", "th", "uk", "vi", "zh",
  ]

  list.map(locales, fn(locale) {
    Locale(
      locale:,
      content: "
day(cardinal=day_count):
  zero: \"zero\"
  one: \"one\"
  two: \"two\"
  few: \"few\"
  many: \"many\"
  other: \"other\"
",
    )
  })
  |> simulate.multi
  |> birdie.snap("cardinal plural cldr test")
}

pub fn cardinal_plural_region_test() {
  // The region is stripped to find the rules: `pt-PT` uses `pt`
  let locales = [
    "ar-EG",
    "en-GB",
    "fr-CA",
    "pl-PL",
    "pt-PT",
    "ru-RU",
    "zh-Hant-TW",
  ]

  list.map(locales, fn(locale) {
    Locale(
      locale:,
      content: "
day(cardinal=day_count):
  zero: \"zero\"
  one: \"one\"
  two: \"two\"
  few: \"few\"
  many: \"many\"
  other: \"other\"
",
    )
  })
  |> simulate.multi
  |> birdie.snap("cardinal plural region test")
}

//! ORDINAL PLURAL --------------------------------------------------------------

pub fn ordinal_plural_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal):
  one: \"{n}st place.\"
  two: \"{n}nd place.\"
  few: \"{n}rd place.\"
  other: \"{n}th place.\"
",
  ))
  |> birdie.snap("ordinal plural")
}

pub fn ordinal_plural_modifier_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal):
  one: \"{n}st place.\"
  two: \"{n}nd place.\"
  few: \"{n}rd place.\"
  other: \"{n}th place.\"
",
  ))
  |> birdie.snap("ordinal plural modifier")
}

pub fn ordinal_plural_multi_parameters_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
runner_place(ordinal):
  one: \"\\\"{name}\\\" is in {n}st place.\"
  two: \"\\\"{name}\\\" is in {n}nd place.\"
  few: \"\\\"{name}\\\" is in {n}rd place.\"
  other: \"\\\"{name}\\\" is in {n}th place.\"
",
  ))
  |> birdie.snap("ordinal plural multi parameters")
}

pub fn ordinal_plural_partial_parameters_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
runner_place(ordinal):
  one: \"\\\"{name}\\\" won.\"
  two: \"Second place.\"
  few: \"Third place.\"
  other: \"{n}th place.\"
",
  ))
  |> birdie.snap("ordinal plural partial parameters")
}

pub fn ordinal_plural_unused_n_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal):
  one: \"First place.\"
  two: \"Second place.\"
  few: \"Third place.\"
  other: \"Not on the podium.\"
",
  ))
  |> birdie.snap("ordinal plural unused n parameter")
}

pub fn ordinal_plural_custom_n_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal=rank):
  one: \"{rank}st place.\"
  two: \"{rank}nd place.\"
  few: \"{rank}rd place.\"
  other: \"{rank}th place.\"
",
  ))
  |> birdie.snap("ordinal custom n")
}

pub fn ordinal_plural_merged_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal):
  one: \"{n}st place\"
  two: \"{n}nd place\"
  few: \"{n}rd place\"
  other: \"{n}th place\"
floor(ordinal):
  one: \"{n}st floor\"
  two: \"{n}nd floor\"
  few: \"{n}rd floor\"
  other: \"{n}th floor\"
absolue: \"I am in @:{place} on the @:{floor}\"
relative: \"I am in @:{.place} on the @:{.floor}\"
",
  ))
  |> birdie.snap("ordinal plural merged linked translation test")
}

pub fn ordinal_plural_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
place(ordinal=place_rank):
  one: \"{place_rank}st place\"
  two: \"{place_rank}nd place\"
  few: \"{place_rank}rd place\"
  other: \"{place_rank}th place\"
floor(ordinal=floor_rank):
  one: \"{floor_rank}st floor\"
  two: \"{floor_rank}nd floor\"
  few: \"{floor_rank}rd floor\"
  other: \"{floor_rank}th floor\"
absolue: \"I am in @:{place} on the @:{floor}\"
relative: \"I am in @:{.place} on the @:{.floor}\"
",
  ))
  |> birdie.snap("ordinal plural linked translation test")
}

pub fn ordinal_plural_cldr_test() {
  // Ordinal rules of https://www.unicode.org/cldr/charts/48/supplemental/language_plural_rules.html
  let locales = [
    "ar", "cs", "de", "en", "es", "fr", "he", "id", "it", "ja", "ko", "ms", "pl",
    "pt", "ru", "sv", "th", "uk", "vi", "zh",
  ]

  list.map(locales, fn(locale) {
    Locale(
      locale:,
      content: "
place(ordinal=rank):
  zero: \"zero\"
  one: \"one\"
  two: \"two\"
  few: \"few\"
  many: \"many\"
  other: \"other\"
",
    )
  })
  |> simulate.multi
  |> birdie.snap("ordinal plural cldr test")
}

//! REGION EXTENSIONS -----------------------------------------------------------

pub fn region_extension_test() {
  // A region file only contains what differs from the language-only locale
  simulate.multi([
    Locale(
      locale: "en",
      content: "
buttons:
  save: \"Save\"
  cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "en-US",
      content: "
buttons:
  cancel: \"Cancel, buddy\"
",
    ),
    Locale(
      locale: "en-GB",
      content: "
buttons:
  cancel: \"Cancel, mate\"
",
    ),
  ])
  |> birdie.snap("region extension")
}

pub fn region_extension_readme_test() {
  simulate.multi([
    Locale(
      locale: "en",
      content: "
save: \"Save\"
cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "en-US",
      content: "
cancel: \"Cancel, buddy\"
",
    ),
    Locale(
      locale: "en-GB",
      content: "
cancel: \"Cancel, mate\"
",
    ),
    Locale(
      locale: "fr",
      content: "
save: \"Enregistrer\"
cancel: \"Annuler\"
",
    ),
    Locale(
      locale: "fr-CA",
      content: "
save: \"Sauvegarder\"
",
    ),
  ])
  |> birdie.snap("region extension readme")
}

pub fn region_extension_default_locale_test() {
  // Without `en` the default locale is the first one in alphabetical order
  simulate.multi([
    Locale(
      locale: "fr",
      content: "
save: \"Enregistrer\"
cancel: \"Annuler\"
",
    ),
    Locale(
      locale: "de",
      content: "
save: \"Speichern\"
cancel: \"Abbrechen\"
",
    ),
    Locale(
      locale: "fr-CA",
      content: "
save: \"Sauvegarder\"
",
    ),
  ])
  |> birdie.snap("region extension default locale")
}

pub fn region_extension_parameters_test() {
  simulate.multi([
    Locale(
      locale: "en",
      content: "
greeting: \"Hello {name}\"
unread_messages:
  one: \"You have {n} unread message\"
  other: \"You have {n} unread messages\"
",
    ),
    Locale(
      locale: "en-GB",
      content: "
greeting: \"Hello {name}, mate\"
",
    ),
  ])
  |> birdie.snap("region extension parameters")
}

pub fn region_extension_warnings_test() {
  // Only the language-only locales warn, a region locale never does
  simulate.warnings([
    Locale(
      locale: "en",
      content: "
save: \"Save\"
cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "en-US",
      content: "
cancel: \"Cancel, buddy\"
",
    ),
    Locale(
      locale: "fr",
      content: "
save: \"Enregistrer\"
",
    ),
    Locale(
      locale: "fr-CA",
      content: "
save: \"Sauvegarder\"
",
    ),
  ])
  |> birdie.snap("region extension warnings")
}

pub fn region_extension_without_language_warnings_test() {
  // `fr-CA` has no `fr` to fall back on so it falls back to the default locale
  simulate.warnings([
    Locale(
      locale: "en",
      content: "
save: \"Save\"
cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "fr-CA",
      content: "
save: \"Sauvegarder\"
",
    ),
  ])
  |> birdie.snap("region extension without language warnings")
}

//! WILDCARD LOCALES ------------------------------------------------------------

pub fn wildcard_codes_test() {
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "[de,fr]",
      content: "
title: \"Titre\"
",
    ),
  ])
  |> birdie.snap("wildcard codes")
}

pub fn wildcard_codes_with_region_test() {
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "[de,en-GB,fr-FR]",
      content: "
title: \"Titre\"
",
    ),
  ])
  |> birdie.snap("wildcard codes with region")
}

pub fn wildcard_any_test() {
  // `[any]` is every existing language
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "fr",
      content: "
title: \"Titre\"
",
    ),
    Locale(
      locale: "ja",
      content: "
title: \"タイトル\"
",
    ),
    Locale(
      locale: "[any]",
      content: "
subtitle: \"Subtitle\"
",
    ),
  ])
  |> birdie.snap("wildcard any")
}

pub fn wildcard_any_language_test() {
  // `[any]-FR` spreads to every language
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "de",
      content: "
title: \"Titel\"
",
    ),
    Locale(
      locale: "fr",
      content: "
title: \"Titre\"
",
    ),
    Locale(
      locale: "[any]-FR",
      content: "
title: \"Titre de France\"
",
    ),
  ])
  |> birdie.snap("wildcard any language")
}

pub fn wildcard_any_region_test() {
  // `en-[any]` spreads to every existing region
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "fr-CA",
      content: "
title: \"Titre\"
",
    ),
    Locale(
      locale: "de-CH",
      content: "
title: \"Titel\"
",
    ),
    Locale(
      locale: "en-[any]",
      content: "
title: \"Title of the region\"
",
    ),
  ])
  |> birdie.snap("wildcard any region")
}

pub fn wildcard_readme_test() {
  simulate.multi([
    Locale(
      locale: "de",
      content: "
title: \"Titel\"
",
    ),
    Locale(
      locale: "en",
      content: "
title: \"Title\"
subtitle: \"Subtitle\"
",
    ),
    Locale(
      locale: "fr",
      content: "
title: \"Titre\"
",
    ),
    Locale(
      locale: "[de,fr,ja]",
      content: "
subtitle: \"Untertitel\"
",
    ),
    Locale(
      locale: "[any]-FR",
      content: "
title: \"Titre de France\"
subtitle: \"Sous-titre de France\"
",
    ),
  ])
  |> birdie.snap("wildcard readme")
}

pub fn wildcard_precedence_test() {
  // The file named after the locale wins over the wildcards with codes,
  // which win over the wildcards with `any`
  simulate.multi([
    Locale(
      locale: "en",
      content: "
first: \"en first\"
second: \"en second\"
third: \"en third\"
",
    ),
    Locale(
      locale: "de",
      content: "
first: \"de first\"
",
    ),
    Locale(
      locale: "[de,fr]",
      content: "
first: \"codes first\"
second: \"codes second\"
",
    ),
    Locale(
      locale: "[any]",
      content: "
first: \"any first\"
second: \"any second\"
third: \"any third\"
",
    ),
  ])
  |> birdie.snap("wildcard precedence")
}

pub fn wildcard_precedence_group_test() {
  // The sources are merged translation by translation, even inside a group
  simulate.multi([
    Locale(
      locale: "en",
      content: "
buttons:
  save: \"Save\"
  cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "de",
      content: "
buttons:
  save: \"Speichern\"
",
    ),
    Locale(
      locale: "[any]",
      content: "
buttons:
  save: \"Any save\"
  cancel: \"Any cancel\"
",
    ),
  ])
  |> birdie.snap("wildcard precedence group")
}

pub fn wildcard_script_not_spread_test() {
  // `Hant` is a script so it is never spread
  simulate.multi([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "zh-Hant-TW",
      content: "
title: \"標題\"
",
    ),
    Locale(
      locale: "[any]-FR",
      content: "
title: \"Titre de France\"
",
    ),
  ])
  |> birdie.snap("wildcard script not spread")
}

pub fn wildcard_with_region_extension_test() {
  // The spread locales are region locales, they fall back to the language
  simulate.multi([
    Locale(
      locale: "en",
      content: "
save: \"Save\"
cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "fr",
      content: "
save: \"Enregistrer\"
cancel: \"Annuler\"
",
    ),
    Locale(
      locale: "[any]-CA",
      content: "
save: \"Save, eh\"
",
    ),
  ])
  |> birdie.snap("wildcard with region extension")
}

pub fn wildcard_any_without_code_warnings_test() {
  // There is no existing region where `any` is
  simulate.warnings([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
",
    ),
    Locale(
      locale: "en-[any]",
      content: "
title: \"Title of the region\"
",
    ),
  ])
  |> birdie.snap("wildcard any without code warnings")
}

//! SANITIZATION ----------------------------------------------------------------

pub fn sanitization_keyword_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
import: \"Import\"
type: \"Type\"
case: \"Case\"
fn: \"Function\"
use: \"Use\"
",
  ))
  |> birdie.snap("sanitization keyword")
}

pub fn sanitization_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
describe: \"A {type} of {case}, {use: Int} times\"
",
  ))
  |> birdie.snap("sanitization parameter")
}

pub fn sanitization_plural_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
apple(cardinal=type):
  one: \"I have {type} apple.\"
  other: \"I have {type} apples.\"
",
  ))
  |> birdie.snap("sanitization plural parameter")
}

pub fn sanitization_nested_group_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
general:
  import: \"Import\"
  type: \"Type\"
",
  ))
  |> birdie.snap("sanitization nested group")
}

pub fn sanitization_linked_translation_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
import: \"Import\"
general:
  import: \"General import\"
absolute: \"@:{import} and @:{general.import}\"
relative:
  import: \"Relative import\"
  link: \"@:{.import}\"
",
  ))
  |> birdie.snap("sanitization linked translation")
}

pub fn sanitization_duplicate_error_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
import: \"Import\"
import_: \"Import again\"
",
    ),
  ])
  |> birdie.snap("sanitization duplicate error")
}

pub fn sanitization_reserved_error_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
auto: \"Auto\"
",
    ),
  ])
  |> birdie.snap("sanitization reserved error")
}

//! ERRORS ----------------------------------------------------------------------

pub fn missing_keys_error_test() {
  // `fr` misses `cancel` (a warning) and `en`, the default locale, misses `save`
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
title: \"Title\"
cancel: \"Cancel\"
",
    ),
    Locale(
      locale: "fr",
      content: "
title: \"Titre\"
save: \"Enregistrer\"
",
    ),
  ])
  |> birdie.snap("missing keys error")
}

pub fn plural_parameter_type_error_test() {
  // The forms of a plural use `{count}` with different types
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
apple(cardinal=count):
  one: \"I have {count: Int} apple.\"
  other: \"I have {count: Float} apples.\"
",
    ),
  ])
  |> birdie.snap("plural parameter type error")
}

pub fn locale_parameter_type_error_test() {
  // The same parameter has a different type between `en` and `fr`
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
greet: \"Hello {name}, you are {age: Int} years old\"
",
    ),
    Locale(
      locale: "fr",
      content: "
greet: \"Bonjour {name}, vous avez {age: Float} ans\"
",
    ),
  ])
  |> birdie.snap("locale parameter type error")
}

pub fn invalid_yaml_test() {
  simulate.prepare_error([
    // The YAML itself can't be parsed
    Locale(
      locale: "syntax",
      content: "
title: \"Title
other: [
",
    ),
    // The root isn't a map
    Locale(
      locale: "root_list",
      content: "
- one
- two
",
    ),
    Locale(
      locale: "root_string",
      content: "just a string
",
    ),
    // More than one document
    Locale(
      locale: "documents",
      content: "
title: \"First\"
---
title: \"Second\"
",
    ),
    // Keys that aren't strings, at the root and in a group
    Locale(
      locale: "keys",
      content: "
1: \"integer\"
1.5: \"float\"
yes: \"boolean\"
~: \"empty\"
? [a, b]
: \"list\"
? {a: b}
: \"map\"
group:
  2: \"nested\"
",
    ),
    // Values that aren't a string or a map
    Locale(
      locale: "values",
      content: "
empty:
integer: 42
float: 4.2
boolean: true
list:
  - a
  - b
group:
  nested_empty:
  nested_integer: 1
",
    ),
    // Modifiers
    Locale(
      locale: "modifiers",
      content: "
string(cardinal): \"not a map\"
string2(cardinal=param): \"not a map\"
string3(ordinal=param): \"not a map\"
empty(ordinal):
integer(cardinal): 1
unknown(plural):
  one: \"one\"
  other: \"other\"
invalid_parameter(cardinal=Count):
  one: \"one\"
  other: \"other\"
wrong(wrong): \"wrong\"
",
    ),
    // Explicit plurals
    Locale(
      locale: "plurals",
      content: "
missing_other(cardinal):
  one: \"one\"
wrong_form(cardinal):
  one: \"one\"
  several: \"several\"
  other: \"other\"
wrong_value(ordinal):
  one: 1
  other:
    nested: \"map\"
wrong_key(cardinal):
  1: \"one\"
  other: \"other\"
",
    ),
    // Parameters
    Locale(
      locale: "parameters",
      content: "
invalid_name: \"Hello {First Name}\"
empty_name: \"Hello {}\"
unknown_type: \"Hello {name: Bool}\"
group:
  nested:
    invalid: \"Hello {Name}\"
plural:
  one: \"{count: Number} apple\"
  other: \"{Count} apples\"
plural_modifier(cardinal=n):
  one: \"{n: Text} apple\"
  other: \"{n} apples\"
",
    ),
  ])
  |> birdie.snap("invalid yaml")
}

pub fn invalid_key_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
Upper: \"Upper\"
my-key: \"Dash\"
1st: \"Digit\"
Group:
  first: \"First\"
  second: \"Second\"
apple(cardinal):
  one: \"one apple\"
  other: \"{n} apples\"
Plural(cardinal):
  one: \"one\"
  other: \"other\"
",
    ),
    Locale(
      locale: "fr",
      content: "
Upper: \"Majuscule\"
",
    ),
  ])
  |> birdie.snap("invalid key")
}

pub fn module_named_parameter_test() {
  simulate.single(Locale(
    locale: "en",
    content: "
greet: \"{locale} has {int: Int} and {float: Float}\"
",
  ))
  |> birdie.snap("module named parameter")
}

pub fn reserved_parameter_error_test() {
  simulate.prepare_error([
    Locale(
      locale: "en",
      content: "
greet: \"Hello {locale_}\"
",
    ),
  ])
  |> birdie.snap("reserved parameter error")
}
