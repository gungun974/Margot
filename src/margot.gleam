import argv
import filepath
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import margot/internal
import margot/internal/code
import polly
import simplifile
import tom

const usage = "usage: gleam run -m margot [watch]"

const poll_interval = 500

const debounce = 150

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

pub fn main() -> Nil {
  case argv.load().arguments {
    [] -> generate()
    ["watch"] -> watch()
    _ -> {
      io.println_error(usage)
      halt(1)
    }
  }
}

fn with_project_root(next: fn(String) -> Nil) -> Nil {
  case internal.find_project_root() {
    Ok(root_path) -> next(root_path)
    Error(error) -> {
      io.println_error("error: " <> error)
      halt(1)
    }
  }
}

fn write_file(path: String, content: String) -> Result(Bool, String) {
  case simplifile.read(path) {
    Ok(existing) if existing == content -> Ok(False)
    _ ->
      simplifile.write(path, content)
      |> result.map(fn(_) { True })
      |> result.map_error(fn(error) {
        path
        <> ": couldn't be written ("
        <> simplifile.describe_error(error)
        <> ")"
      })
  }
}

pub const default_output = "src/t.gleam"

pub type Config {
  Config(output: String, module: String)
}

pub fn read_config(root_path: String) -> Result(Config, String) {
  use content <- result.try(
    simplifile.read(filepath.join(root_path, "gleam.toml"))
    |> result.map_error(fn(error) {
      "`gleam.toml` couldn't be read: " <> simplifile.describe_error(error)
    }),
  )

  use toml <- result.try(
    tom.parse(content)
    |> result.map_error(fn(_) { "`gleam.toml` isn't a valid TOML file" }),
  )

  case tom.get_string(toml, ["tools", "margot", "output"]) {
    Error(tom.NotFound(_)) -> parse_output(default_output)
    Error(tom.WrongType(..)) ->
      Error("`tools.margot.output` in `gleam.toml` should be a string")
    Ok(output) -> parse_output(output)
  }
}

fn parse_output(output: String) -> Result(Config, String) {
  let invalid = fn(reason) {
    Error(
      "`tools.margot.output` in `gleam.toml` is `"
      <> output
      <> "`, "
      <> reason
      <> " (for example `src/t.gleam` or `../shared/src/i18n.gleam`)",
    )
  }

  case string.starts_with(output, "/") {
    True -> invalid("it should be relative to the project root")
    False ->
      case string.ends_with(output, ".gleam") {
        False -> invalid("it should end with `.gleam`")
        True -> {
          let module =
            output
            |> filepath.base_name()
            |> string.remove_suffix(".gleam")

          case valid_module_name(module) {
            True -> Ok(Config(output:, module:))
            False ->
              invalid(
                "the file name should be a valid Gleam module name, in lowercase with `_`",
              )
          }
        }
      }
  }
}

fn valid_module_name(module: String) -> Bool {
  case string.to_graphemes(module) {
    [first, ..rest] ->
      is_lowercase_letter(first)
      && list.all(rest, fn(char) {
        is_lowercase_letter(char) || is_digit(char) || char == "_"
      })
    [] -> False
  }
}

fn is_lowercase_letter(char: String) -> Bool {
  string.contains("abcdefghijklmnopqrstuvwxyz", char)
}

fn is_digit(char: String) -> Bool {
  string.contains("0123456789", char)
}

fn generate_project(root_path: String) -> Result(Nil, Nil) {
  case
    {
      use config <- result.try(
        read_config(root_path)
        |> result.map_error(fn(error) { [error] }),
      )
      use scanned <- result.try(internal.scan(root_path))
      use prepared <- result.try(internal.prepare(scanned))
      let generated = internal.generate(prepared, config.module)

      let module_path =
        filepath.join(root_path, config.output)
        |> filepath.expand()
        |> result.unwrap(filepath.join(root_path, config.output))
      let ffi_path =
        filepath.join(
          filepath.directory_name(module_path),
          code.ffi_file_name(config.module),
        )

      let write = fn(path, content) {
        simplifile.create_directory_all(filepath.directory_name(path))
        |> result.map_error(fn(error) {
          filepath.directory_name(path)
          <> ": couldn't be created ("
          <> simplifile.describe_error(error)
          <> ")"
        })
        |> result.try(fn(_) { write_file(path, content) })
        |> result.map_error(fn(error) { [error] })
      }

      use module_changed <- result.try(write(module_path, generated.module))
      use ffi_changed <- result.map(write(ffi_path, generated.ffi))

      #(module_path, module_changed || ffi_changed, generated.warnings)
    }
  {
    Ok(#(module_path, changed, warnings)) -> {
      list.each(warnings, fn(warning) {
        io.println_error("warning: " <> warning)
      })

      case changed {
        True -> io.println("Generated " <> module_path)
        False -> io.println(module_path <> " is already up to date")
      }

      Ok(Nil)
    }
    Error(errors) -> {
      list.each(errors, fn(error) { io.println_error("error: " <> error) })
      io.println_error("nothing was generated")

      Error(Nil)
    }
  }
}

fn generate() -> Nil {
  use root_path <- with_project_root

  case generate_project(root_path) {
    Ok(Nil) -> halt(0)
    Error(Nil) -> halt(1)
  }
}

fn is_locale_file(file_type: simplifile.FileType, path: String) -> Bool {
  polly.default_filter(file_type, path)
  && case file_type {
    simplifile.File -> string.ends_with(path, ".i18n.yaml")
    _ -> True
  }
}

fn watch() -> Nil {
  use root_path <- with_project_root

  let lang_path = filepath.join(root_path, "lang")
  let events = process.new_subject()

  let watcher =
    polly.new()
    |> polly.add_dir(lang_path)
    |> polly.max_depth(1)
    |> polly.interval(poll_interval)
    |> polly.filter(is_locale_file)
    |> polly.ignore_initial_missing()
    |> polly.add_callback(process.send(events, _))
    |> polly.watch()

  case watcher {
    Error(errors) -> {
      io.println_error("error: " <> polly.describe_errors(errors))
      halt(1)
    }
    Ok(_) -> {
      let _ = generate_project(root_path)

      io.println(
        "Watching " <> lang_path <> " for changes, press Ctrl+C to stop",
      )

      watch_loop(root_path, events)
    }
  }
}

fn watch_loop(root_path: String, events: Subject(polly.Event)) -> Nil {
  let changes = collect_events(events, [process.receive_forever(events)])

  list.each(changes, fn(event) { io.println(describe_event(root_path, event)) })

  let _ = generate_project(root_path)

  watch_loop(root_path, events)
}

fn collect_events(
  events: Subject(polly.Event),
  collected: List(polly.Event),
) -> List(polly.Event) {
  case process.receive(events, debounce) {
    Ok(event) -> collect_events(events, [event, ..collected])
    Error(Nil) -> list.reverse(collected)
  }
}

fn describe_event(root_path: String, event: polly.Event) -> String {
  let relative = fn(path) { string.remove_prefix(path, root_path <> "/") }

  case event {
    polly.Created(path) -> "created " <> relative(path)
    polly.Changed(path) -> "changed " <> relative(path)
    polly.Deleted(path) -> "deleted " <> relative(path)
    polly.Error(path, reason) ->
      "couldn't watch "
      <> relative(path)
      <> " ("
      <> simplifile.describe_error(reason)
      <> ")"
  }
}
