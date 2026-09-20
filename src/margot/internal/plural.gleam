import gleam/int
import gleam/list
import gleam/option.{None, Some}
import margot/internal/locale.{
  type PluralForm, type PluralForms, type PluralKind, Cardinal, Few, Many, One,
  Ordinal, Other, Two, Zero,
}

pub type Arm {
  Exact(List(Int))
  When(fn(String) -> String)
}

fn mod10_in(variable: String, from: Int, to: Int) -> String {
  variable
  <> " % 10 >= "
  <> int.to_string(from)
  <> " && "
  <> variable
  <> " % 10 <= "
  <> int.to_string(to)
}

fn mod100_in(variable: String, from: Int, to: Int) -> String {
  variable
  <> " % 100 >= "
  <> int.to_string(from)
  <> " && "
  <> variable
  <> " % 100 <= "
  <> int.to_string(to)
}

fn millions(v: String) -> String {
  v <> " != 0 && " <> v <> " % 1_000_000 == 0"
}

fn slavic_few(v: String) -> String {
  mod10_in(v, 2, 4)
  <> " && "
  <> v
  <> " % 100 < 12 || "
  <> mod10_in(v, 2, 4)
  <> " && "
  <> v
  <> " % 100 > 14"
}

fn plural_rule(kind: PluralKind, language: String) -> List(#(PluralForm, Arm)) {
  case kind, language {
    Cardinal, "ja"
    | Cardinal, "zh"
    | Cardinal, "ko"
    | Cardinal, "th"
    | Cardinal, "id"
    | Cardinal, "ms"
    | Cardinal, "vi"
    -> []
    Cardinal, "fr" | Cardinal, "pt" -> [
      #(One, Exact([0, 1])),
      #(Many, When(millions)),
    ]
    Cardinal, "es" | Cardinal, "it" -> [
      #(Zero, Exact([0])),
      #(One, Exact([1])),
      #(Many, When(millions)),
    ]
    Cardinal, "cs" -> [
      #(Zero, Exact([0])),
      #(One, Exact([1])),
      #(Few, Exact([2, 3, 4])),
    ]
    Cardinal, "he" -> [
      #(Zero, Exact([0])),
      #(One, Exact([1])),
      #(Two, Exact([2])),
    ]
    Cardinal, "ru" | Cardinal, "uk" -> [
      #(One, When(fn(v) { v <> " % 10 == 1 && " <> v <> " % 100 != 11" })),
      #(Few, When(slavic_few)),
      #(
        Many,
        When(fn(v) {
          v
          <> " % 10 == 0 || "
          <> mod10_in(v, 5, 9)
          <> " || "
          <> mod100_in(v, 11, 14)
        }),
      ),
    ]
    Cardinal, "pl" -> [
      #(One, Exact([1])),
      #(Few, When(slavic_few)),
      #(
        Many,
        When(fn(v) {
          v
          <> " != 1 && "
          <> v
          <> " % 10 <= 1 || "
          <> mod10_in(v, 5, 9)
          <> " || "
          <> mod100_in(v, 12, 14)
        }),
      ),
    ]
    Cardinal, "ar" -> [
      #(Zero, Exact([0])),
      #(One, Exact([1])),
      #(Two, Exact([2])),
      #(Few, When(fn(v) { mod100_in(v, 3, 10) })),
      #(Many, When(fn(v) { v <> " % 100 >= 11" })),
    ]
    Cardinal, _ -> [#(Zero, Exact([0])), #(One, Exact([1]))]
    Ordinal, "en" -> [
      #(One, When(fn(v) { v <> " % 10 == 1 && " <> v <> " % 100 != 11" })),
      #(Two, When(fn(v) { v <> " % 10 == 2 && " <> v <> " % 100 != 12" })),
      #(Few, When(fn(v) { v <> " % 10 == 3 && " <> v <> " % 100 != 13" })),
    ]
    Ordinal, "fr" | Ordinal, "ms" | Ordinal, "vi" -> [#(One, Exact([1]))]
    Ordinal, "uk" -> [
      #(Few, When(fn(v) { v <> " % 10 == 3 && " <> v <> " % 100 != 13" })),
    ]
    Ordinal, "it" -> [#(Many, Exact([8, 11, 80, 800]))]
    Ordinal, "sv" -> [
      #(
        One,
        When(fn(v) {
          v
          <> " % 10 == 1 && "
          <> v
          <> " % 100 != 11 || "
          <> v
          <> " % 10 == 2 && "
          <> v
          <> " % 100 != 12"
        }),
      ),
    ]
    Ordinal, _ -> []
  }
}

pub fn plural_arms(
  kind: PluralKind,
  language: String,
  forms: PluralForms(a),
) -> List(#(Arm, a)) {
  list.filter_map(plural_rule(kind, language), fn(step) {
    let form = case step.0 {
      Zero -> forms.zero
      One -> forms.one
      Two -> forms.two
      Few -> forms.few
      Many -> forms.many
      Other -> Some(forms.other)
    }

    case form {
      Some(parts) -> Ok(#(step.1, parts))
      None -> Error(Nil)
    }
  })
}
