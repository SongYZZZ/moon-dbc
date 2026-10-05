// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "SongYZZZ/moon-dbc"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/SongYZZZ/moon-dbc"

license = "Apache-2.0"

keywords = [ "can", "can-fd", "dbc", "automotive", "codec", "multiplex" ]

preferred_target = "wasm-gc"

description = "MoonDBC: CAN / CAN FD DBC parsing, validation, multiplexed frame codec and CLI"
