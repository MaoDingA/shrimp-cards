///|
pub(all) struct ReplayEventRecord {
  event_id : Int
  event : @protocol.ServerEvent
} derive(Eq, Debug, ToJson, FromJson)

///|
pub struct ReplayEventLog {
  priv header : ReplayHeader
  priv events : Array[ReplayEventRecord]
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn ReplayEventLog::new(
  header : ReplayHeader,
  events : Array[ReplayEventRecord],
) -> ReplayEventLog {
  { header, events }
}

///|
pub fn ReplayEventLog::is_compatible(self : ReplayEventLog) -> Bool {
  self.header.is_compatible()
}

///|
pub fn ReplayEventLog::match_id(self : ReplayEventLog) -> String {
  self.header.match_id
}

///|
pub fn ReplayEventLog::records_from(
  self : ReplayEventLog,
  from_event_id : Int,
) -> Array[ReplayEventRecord] {
  let records : Array[ReplayEventRecord] = []
  for record in self.events {
    if record.event_id >= normalized_cursor(from_event_id) {
      records.push(record)
    }
  }
  records
}

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

///|
pub fn ReplayEventJournal::to_event_log(
  self : ReplayEventJournal,
  header : ReplayHeader,
) -> ReplayEventLog {
  ReplayEventLog::new(header, self.records_from(0))
}

///|
async fn ensure_parent_directory(path : String) -> Unit {
  match path.rev_split_once("/") {
    Some((directory, _)) =>
      if !directory.is_empty() {
        @fs.mkdir(directory, recursive=true) catch {
          _ => ()
        }
      }
    None => ()
  }
}

///|
pub async fn ReplayEventLog::save(self : ReplayEventLog, path : String) -> Unit {
  ensure_parent_directory(path)
  @fs.write_file(
    path,
    self.to_json().stringify(indent=2),
    create_mode=CreateOrTruncate,
  )
}

///|
pub async fn load_event_log(path : String) -> ReplayEventLog? {
  try {
    let json = @json.parse(@fs.read_file(path).text())
    let log : ReplayEventLog = @json.from_json(json)
    if log.is_compatible() {
      Some(log)
    } else {
      None
    }
  } catch {
    _ => None
  }
}
