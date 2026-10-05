///|
fn main {
  let args = @env.args()
  let start = argument_start()
  let code = try {
    let command = @dbc.parse_cli_arguments(args[start:].to_owned())
    let source = if command.path == "" {
      ""
    } else {
      @fs.read_file_to_string(command.path, encoding="utf8")
    }
    let second_source = match command.second_path {
      Some(path) => @fs.read_file_to_string(path, encoding="utf8")
      None => ""
    }
    let out = @dbc.execute_cli(command, source, second_source~)
    println(out.text)
    out.exit_code
  } catch {
    @dbc.Failure(d) => {
      print_stderr(@dbc.render_diagnostic(d) + "\n")
      2
    }
    e => {
      print_stderr("error [io.read]: " + e.to_string() + "\n")
      2
    }
  }
  if code != 0 {
    @sys.exit(code)
  }
}
