///|
fn main {
  let source = "BU_: ECU\nBO_ 1 Sensors: 2 ECU\n SG_ Mode M : 0|8@1+ (1,0) [0|255] \"\" ECU\n SG_ Temp m0 : 8|8@1+ (1,-40) [-40|215] \"degC\" ECU\n SG_ Volts m1 : 8|8@1+ (0.1,0) [0|25.5] \"V\" ECU\n"
  try {
    let db = @dbc.parse_dbc(source)
    let frame = @dbc.encode_message(db.messages[0], [
        { name: "Mode", value: Physical(1) },
        { name: "Volts", value: Physical(12.5) },
      ]).frame
    println(@dbc.frame_hex(frame.payload))
    let decoded = @dbc.decode_frame(db, frame)
    for s in decoded.signals {
      println("\{s.name} = \{s.physical} \{s.unit}")
    }
    println(@dbc.render_layout(db.messages[0]))
  } catch {
    @dbc.Failure(d) => println(@dbc.render_diagnostic(d))
  }
}
