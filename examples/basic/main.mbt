///|
fn main {
  let source = "BU_: ECU Dash\nBO_ 291 Engine: 2 ECU\n SG_ Speed : 0|16@1+ (0.125,0) [0|8000] \"rpm\" Dash\n"
  try {
    let db = @dbc.parse_dbc(source)
    let message = db.message_by_name("Engine").unwrap()
    let encoded = @dbc.encode_message(message, [
      { name: "Speed", value: Physical(1500) },
    ])
    println(@dbc.frame_hex(encoded.frame.payload))
    let decoded = @dbc.decode_frame(db, encoded.frame)
    println(
      "\{decoded.signals[0].name} = \{decoded.signals[0].physical} \{decoded.signals[0].unit}",
    )
  } catch {
    @dbc.Failure(d) => println(@dbc.render_diagnostic(d))
  }
}
