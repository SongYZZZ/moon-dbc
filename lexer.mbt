///|
priv struct Token {
  text : String
  quoted : Bool
  location : SourceLocation
  end_offset : Int
}

///|
fn lex(source : String, limits : ParseLimits) -> Array[Token] raise DbcError {
  if source.length() > limits.max_file_size {
    fail("limit.file", "input exceeds file budget")
  }
  let tokens = []
  let mut i = 0
  let mut line = 1
  let mut column = 1
  while i < source.length() {
    let start = i
    let location = { line, column, offset: i }
    let c = source[i].to_int()
    if column > limits.max_line_length {
      raise Failure(diagnostic("limit.line", "line exceeds budget", location~))
    }
    if c == 32 || c == 9 || c == 13 || (i == 0 && c == 0xFEFF) {
      i += 1
      column += 1
      continue
    }
    if c == 10 {
      tokens.push({ text: "\n", quoted: false, location, end_offset: i + 1 })
      i += 1
      line += 1
      column = 1
      continue
    }
    if c == 34 {
      i += 1
      column += 1
      let buf = StringBuilder::new()
      let mut segment = i
      let mut closed = false
      while i < source.length() {
        let q = source[i].to_int()
        if i - start > limits.max_token_length {
          raise Failure(
            diagnostic("limit.token", "quoted token exceeds budget", location~),
          )
        }
        if column > limits.max_line_length {
          raise Failure(
            diagnostic("limit.line", "line exceeds budget", location~),
          )
        }
        if q == 34 {
          buf.write_stringview(source[segment:i])
          i += 1
          column += 1
          closed = true
          break
        }
        if q == 92 {
          buf.write_stringview(source[segment:i])
          i += 1
          column += 1
          if i >= source.length() {
            break
          }
          match source[i].to_int() {
            34 => buf.write_string("\"")
            92 => buf.write_string("\\")
            110 => buf.write_string("\n")
            114 => buf.write_string("\r")
            116 => buf.write_string("\t")
            _ =>
              raise Failure(
                diagnostic("lex.escape", "unsupported quoted escape", location~),
              )
          }
          i += 1
          column += 1
          segment = i
        } else {
          i += 1
          if q == 10 {
            line += 1
            column = 1
          } else {
            column += 1
          }
        }
      }
      if !closed {
        raise Failure(
          diagnostic("lex.string", "unterminated quoted string", location~),
        )
      }
      tokens.push({
        text: buf.to_string(),
        quoted: true,
        location,
        end_offset: i,
      })
      continue
    }
    if c < 32 {
      raise Failure(
        diagnostic("lex.character", "invalid control character", location~),
      )
    }
    if c == 58 ||
      c == 59 ||
      c == 124 ||
      c == 64 ||
      c == 40 ||
      c == 41 ||
      c == 91 ||
      c == 93 ||
      c == 44 ||
      c == 43 ||
      c == 45 {
      i += 1
      column += 1
    } else {
      while i < source.length() {
        let v = source[i].to_int()
        if v == 43 || v == 45 {
          if i == start ||
            (source[i - 1].to_int() != 101 && source[i - 1].to_int() != 69) {
            break
          }
        } else if v <= 32 ||
          v == 34 ||
          v == 58 ||
          v == 59 ||
          v == 124 ||
          v == 64 ||
          v == 40 ||
          v == 41 ||
          v == 91 ||
          v == 93 ||
          v == 44 {
          break
        }
        i += 1
        column += 1
        if i - start > limits.max_token_length {
          raise Failure(
            diagnostic("limit.token", "token exceeds budget", location~),
          )
        }
      }
    }
    tokens.push({
      text: source[start:i].to_owned(),
      quoted: false,
      location,
      end_offset: i,
    })
  }
  tokens.push({
    text: "",
    quoted: false,
    location: { line, column, offset: i },
    end_offset: i,
  })
  tokens
}
