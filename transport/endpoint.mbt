///|
pub(all) struct Endpoint {
  bind_host : String
  port : Int
} derive(Eq, Debug)

///|
pub fn Endpoint::new(bind_host : String, port : Int) -> Endpoint {
  { bind_host, port }
}

///|
pub fn Endpoint::localhost(port : Int) -> Endpoint {
  { bind_host: "127.0.0.1", port }
}

///|
fn normalize_path(path : String) -> String {
  if path.has_prefix("/") {
    path
  } else {
    "/\{path}"
  }
}

///|
pub fn Endpoint::ws_url(self : Endpoint, path : String) -> String {
  "ws://\{self.bind_host}:\{self.port}\{normalize_path(path)}"
}

///|
pub fn Endpoint::http_url(self : Endpoint, path : String) -> String {
  "http://\{self.bind_host}:\{self.port}\{normalize_path(path)}"
}
