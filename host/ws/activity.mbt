///|
priv struct ConnectionActivity {
  timeout_ms : Int
  mut side_a_last_seen_ms : Int64?
  mut side_b_last_seen_ms : Int64?
  mut side_a_expired : Bool
  mut side_b_expired : Bool
}

///|
fn ConnectionActivity::new(timeout_ms~ : Int) -> ConnectionActivity {
  {
    timeout_ms,
    side_a_last_seen_ms: None,
    side_b_last_seen_ms: None,
    side_a_expired: false,
    side_b_expired: false,
  }
}

///|
fn ConnectionActivity::mark_seen(
  self : ConnectionActivity,
  side : @protocol.Side,
  now_ms : Int64,
) -> Unit {
  match side {
    @protocol.A => {
      self.side_a_last_seen_ms = Some(now_ms)
      self.side_a_expired = false
    }
    @protocol.B => {
      self.side_b_last_seen_ms = Some(now_ms)
      self.side_b_expired = false
    }
  }
}

///|
fn side_is_expired(
  last_seen_ms : Int64?,
  already_expired : Bool,
  timeout_ms : Int,
  now_ms : Int64,
) -> Bool {
  if timeout_ms <= 0 || already_expired {
    false
  } else {
    match last_seen_ms {
      Some(last_seen_ms) => now_ms - last_seen_ms >= timeout_ms.to_int64()
      None => false
    }
  }
}

///|
fn ConnectionActivity::expired_sides(
  self : ConnectionActivity,
  now_ms : Int64,
) -> Array[@protocol.Side] {
  let sides : Array[@protocol.Side] = []
  if side_is_expired(
      self.side_a_last_seen_ms,
      self.side_a_expired,
      self.timeout_ms,
      now_ms,
    ) {
    self.side_a_expired = true
    sides.push(@protocol.A)
  }
  if side_is_expired(
      self.side_b_last_seen_ms,
      self.side_b_expired,
      self.timeout_ms,
      now_ms,
    ) {
    self.side_b_expired = true
    sides.push(@protocol.B)
  }
  sides
}
