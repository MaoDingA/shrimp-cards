///|
fn main {
  println(@cli.parse_command(@env.args()).summary())
}
