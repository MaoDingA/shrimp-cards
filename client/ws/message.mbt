///|
pub(all) enum HostMessage {
  JoinMessage(@protocol.JoinResponse)
  InputMessage(@protocol.InputResponse)
  EventMessage(@protocol.ServerEvent)
  UnknownHostFrame(String)
} derive(Eq, Debug)

///|
pub fn HostMessage::from_wire_text(frame : String) -> HostMessage {
  match @protocol.ServerEvent::from_wire_text(frame) {
    Some(event) => EventMessage(event)
    None =>
      match @protocol.InputResponse::from_wire_text(frame) {
        Some(response) => InputMessage(response)
        None =>
          match @protocol.JoinResponse::from_wire_text(frame) {
            Some(response) => JoinMessage(response)
            None => UnknownHostFrame(frame)
          }
      }
  }
}

///|
pub fn HostMessage::summary(self : HostMessage) -> String {
  match self {
    JoinMessage(response) => "join \{response.summary()}"
    InputMessage(response) => "input \{response.summary()}"
    EventMessage(event) => "event \{event.summary()}"
    UnknownHostFrame(_) => "invalid host message"
  }
}

///|
pub fn HostMessage::opened_window(self : HostMessage) -> @protocol.WindowId? {
  match self {
    InputMessage(@protocol.WindowOpened(window_id)) => Some(window_id)
    EventMessage(@protocol.InputWindowOpened(window_id)) => Some(window_id)
    _ => None
  }
}
