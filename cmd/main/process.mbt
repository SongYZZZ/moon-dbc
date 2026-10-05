///|
#cfg(target="native")
fn argument_start() -> Int {
  1
}

///|
#cfg(target="js")
fn argument_start() -> Int {
  2
}

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn argument_start() -> Int {
  1
}

///|
#cfg(target="js")
extern "js" fn print_stderr(text : String) =
  #| (text) => process.stderr.write(text)

///|
#cfg(target="native")
#owned(bytes)
extern "c" fn stderr_bytes(bytes : Bytes) = "moon_dbc_stderr"

///|
#cfg(target="native")
fn print_stderr(text : String) -> Unit {
  stderr_bytes(@utf8.encode(text))
}

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn print_stderr(text : String) -> Unit {
  println(text)
}
