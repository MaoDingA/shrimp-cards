///|
pub(all) struct EventSubscription {
  from_event_id : Int
} derive(Eq, Debug)

///|
pub fn EventSubscription::new(from_event_id : Int) -> EventSubscription {
  { from_event_id, }
}

///|
pub fn EventSubscription::to_wire_text(self : EventSubscription) -> String {
  "subscribe\t\{self.from_event_id}"
}

///|
pub fn EventSubscription::from_wire_text(frame : String) -> EventSubscription? {
  match split_wire_text(frame) {
    ["subscribe", from_raw] =>
      match parse_version(from_raw) {
        Some(from_event_id) => Some(EventSubscription::new(from_event_id))
        None => None
      }
    _ => None
  }
}

///|
pub fn EventSubscription::summary(self : EventSubscription) -> String {
  "subscribe from event \{self.from_event_id}"
}
