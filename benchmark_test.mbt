///|
fn benchmark_source(messages : Int, signals_per_message : Int) -> String {
  let out = StringBuilder::new()
  out.write_string("VERSION \"benchmark\"\nBS_:\nBU_: ECU\n")
  for i = 0; i < messages; i = i + 1 {
    out.write_string("BO_ \{i+1} Message\{i}: 8 ECU\n")
    for j = 0; j < signals_per_message; j = j + 1 {
      out.write_string(" SG_ S\{j} : \{j}|1@1+ (1,0) [0|1] \"\" ECU\n")
    }
  }
  out.to_string()
}

///|
test "parse small DBC" (b : @bench.T) {
  let text = basic_text()
  b.bench(
    fn() {
      b.keep(
        parse_dbc(text) catch {
          _ => abort("valid benchmark input failed")
        },
      )
    },
    count=5U,
  )
}

///|
test "parse 100 messages" (b : @bench.T) {
  let text = benchmark_source(100, 8)
  b.bench(
    fn() {
      b.keep(
        parse_dbc(text) catch {
          _ => abort("valid benchmark input failed")
        },
      )
    },
    count=5U,
  )
}

///|
test "parse 1000 messages" (b : @bench.T) {
  let text = benchmark_source(1000, 8)
  b.bench(
    fn() {
      b.keep(
        parse_dbc(text) catch {
          _ => abort("valid benchmark input failed")
        },
      )
    },
    count=5U,
  )
}

///|
test "parse 10000 signals" (b : @bench.T) {
  let text = benchmark_source(1000, 10)
  b.bench(
    fn() {
      b.keep(
        parse_dbc(text) catch {
          _ => abort("valid benchmark input failed")
        },
      )
    },
    count=5U,
  )
}

///|
test "decode 100k frames cached" (b : @bench.T) {
  let m = (parse_dbc(basic_text()) catch { _ => abort("benchmark fixture") }).messages[0]
  let compiled = compile_message(m) catch { _ => abort("benchmark model") }
  let frame = CanFrame::{
    frame_id: m.frame_id,
    payload: [0xE0, 0x2E, 3, 0, 0, 0, 0, 0],
  }
  b.bench(
    fn() {
      let mut checksum = 0.0
      for i = 0; i < 100000; i = i + 1 {
        let decoded = compiled.decode(frame) catch {
          _ => abort("benchmark decode")
        }
        checksum += decoded.signals[0].physical
      }
      b.keep(checksum)
    },
    count=5U,
  )
}

///|
test "encode 100k frames cached" (b : @bench.T) {
  let m = (parse_dbc(basic_text()) catch { _ => abort("benchmark fixture") }).messages[0]
  let compiled = compile_message(m) catch { _ => abort("benchmark model") }
  let assignments = [
    SignalAssignment::{ name: "EngineSpeed", value: Physical(1500) },
    { name: "Gear", value: Physical(3) },
  ]
  b.bench(
    fn() {
      let mut checksum = 0
      for i = 0; i < 100000; i = i + 1 {
        let encoded = compiled.encode(assignments) catch {
          _ => abort("benchmark encode")
        }
        checksum += encoded.frame.payload[0].to_int()
      }
      b.keep(checksum)
    },
    count=5U,
  )
}

///|
test "semantic diff 100 messages" (b : @bench.T) {
  let source = benchmark_source(100, 8)
  let old = parse_dbc(source) catch { _ => abort("benchmark fixture") }
  let new = parse_dbc(source.replace_all(old="(1,0)", new="(2,0)")) catch {
    _ => abort("benchmark fixture")
  }
  b.bench(fn() { b.keep(diff_database(old, new)) }, count=5U)
}
