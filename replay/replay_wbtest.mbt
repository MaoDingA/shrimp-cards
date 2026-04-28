///|
test "replay header is compatible with current versions" {
  let header = ReplayHeader::new(
    "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
  )
  assert_true(header.is_compatible())
}

///|
test "replay header rejects mismatched protocol version" {
  let header = ReplayHeader::new(
    "match-1",
    "2026-04-28T00:00:00Z",
    42,
    @protocol.protocol_version + 1,
    replay_format_version,
  )
  assert_false(header.is_compatible())
}

///|
test "replay window record requires both final plans" {
  let intervention = @protocol.Intervention::new(
    side=@protocol.A,
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    kind=@protocol.SoftPreference,
    text="/prefer defend",
  )
  let record = ReplayWindowRecord::new(
    window_id=@protocol.WindowId::new(1),
    sequence_id=@protocol.SequenceId::new(1),
    initial_agent_plan_a="A initial",
    initial_agent_plan_b="B initial",
    final_agent_plan_a="A final",
    final_agent_plan_b="B final",
    public_interventions=[intervention],
    public_events=[
      @protocol.PublicEvent::new("window_closed", "Window 1 closed"),
    ],
  )
  assert_true(record.has_complete_agent_plans())
  assert_eq(record.public_event_count(), 1)
}

///|
test "replay log requires compatible versions and both player seats" {
  let header = ReplayHeader::new(
    "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
  )
  let log = ReplayLog::new(
    header,
    [
      @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
      @protocol.PlayerIdentity::new("p2", "Bob", @protocol.B),
    ],
    [],
  )
  assert_true(log.can_play())
}

///|
test "replay event journal returns public events from cursor" {
  let journal = ReplayEventJournal::new()
  let first = journal.append(
    @protocol.PlayerJoined(
      @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
    ),
  )
  let second = journal.append(@protocol.PlayerReady(@protocol.A))
  assert_eq(first.event_id, 0)
  assert_eq(second.event_id, 1)
  match journal.records_from(1) {
    [record] => {
      assert_eq(record.event_id, 1)
      assert_true(record.event == @protocol.PlayerReady(@protocol.A))
    }
    _ => fail("expected one replay event")
  }
}

///|
test "replay event log exposes metadata and groups windows" {
  let log = ReplayEventLog::new(
    ReplayHeader::new(
      "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
    ),
    [
      ReplayEventRecord::{ event_id: 0, event: @protocol.MatchStarted },
      ReplayEventRecord::{
        event_id: 1,
        event: @protocol.InputWindowOpened(@protocol.WindowId::new(1)),
      },
      ReplayEventRecord::{
        event_id: 2,
        event: @protocol.WindowLocked(@protocol.WindowId::new(1)),
      },
      ReplayEventRecord::{
        event_id: 3,
        event: @protocol.InputWindowOpened(@protocol.WindowId::new(2)),
      },
    ],
  )
  assert_eq(log.created_at(), "2026-04-28T00:00:00Z")
  assert_eq(log.seed(), 42)
  assert_eq(log.protocol_version(), @protocol.protocol_version)
  assert_eq(log.format_version(), replay_format_version)
  assert_eq(log.event_count(), 4)
  match log.window_groups() {
    [first, second] => {
      assert_true(first.window_id == @protocol.WindowId::new(1))
      assert_eq(first.records.length(), 2)
      assert_true(second.window_id == @protocol.WindowId::new(2))
      assert_eq(second.records.length(), 1)
    }
    _ => fail("expected two replay window groups")
  }
}

///|
async test "replay event log writes and loads compatible json" {
  @async.pause()
  let journal = ReplayEventJournal::new()
  ignore(
    journal.append(
      @protocol.PlayerJoined(
        @protocol.PlayerIdentity::new("p1", "Alice", @protocol.A),
      ),
    ),
  )
  ignore(journal.append(@protocol.PlayerReady(@protocol.A)))
  let header = ReplayHeader::new(
    "match-1", "2026-04-28T00:00:00Z", 42, @protocol.protocol_version, replay_format_version,
  )
  let path = "_build/replay_event_log_test.json"
  @fs.remove(path) catch {
    _ => ()
  }
  let log = journal.to_event_log(header)
  log.save(path)
  match load_event_log(path) {
    Some(loaded) => {
      assert_true(loaded.is_compatible())
      match loaded.records_from(1) {
        [record] =>
          assert_true(record.event == @protocol.PlayerReady(@protocol.A))
        _ => fail("expected replayed ready event")
      }
    }
    None => fail("expected replay event log")
  }
}

///|
async test "replay event log rejects incompatible versions on load" {
  @async.pause()
  let journal = ReplayEventJournal::new()
  ignore(journal.append(@protocol.PlayerReady(@protocol.A)))
  let header = ReplayHeader::new(
    "match-2",
    "2026-04-28T00:00:00Z",
    42,
    @protocol.protocol_version + 1,
    replay_format_version,
  )
  let path = "_build/replay_event_log_bad_version_test.json"
  @fs.remove(path) catch {
    _ => ()
  }
  journal.to_event_log(header).save(path)
  match load_event_log(path) {
    None => ()
    Some(_) => fail("expected incompatible replay to be rejected")
  }
}
