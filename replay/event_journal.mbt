///|
pub(all) struct ReplayEventRecord {
  event_id : Int
  event : @protocol.ServerEvent
} derive(Eq, Debug, ToJson, FromJson)

///|
pub struct ReplayEventJournal {
  priv events : Array[@protocol.ServerEvent]
} derive(Eq, Debug)

///|
pub fn ReplayEventJournal::new() -> ReplayEventJournal {
  { events: [] }
}

///|
pub fn ReplayEventJournal::append(
  self : ReplayEventJournal,
  event : @protocol.ServerEvent,
) -> ReplayEventRecord {
  let event_id = self.events.length()
  self.events.push(event)
  { event_id, event }
}

///|
fn normalized_cursor(from_event_id : Int) -> Int {
  if from_event_id < 0 {
    0
  } else {
    from_event_id
  }
}

///|
pub fn ReplayEventJournal::records_from(
  self : ReplayEventJournal,
  from_event_id : Int,
) -> Array[ReplayEventRecord] {
  let records : Array[ReplayEventRecord] = []
  for event_id in normalized_cursor(from_event_id)..<self.events.length() {
    records.push({ event_id, event: self.events[event_id] })
  }
  records
}
