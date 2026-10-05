///|
fn[A] expect_error(f : () -> A raise DbcError, code : String) -> Unit raise {
  try f() catch {
    Failure(d) => assert_eq(d.code, code)
  } noraise {
    _ => assert_true(false, msg="expected DbcError \{code}")
  }
}

///|
fn basic_text() -> String {
  "VERSION \"1.0\"\nNS_ :\n CM_\n VAL_\nBS_:\nBU_: ECU Dash\nBO_ 291 EngineData: 8 ECU\n SG_ EngineSpeed : 0|16@1+ (0.125,0) [0|8000] \"rpm\" Dash\n SG_ Gear : 16|8@1+ (1,0) [0|7] \"\" Dash\nVAL_ 291 Gear 0 \"Park\" 3 \"Drive\";\n"
}
