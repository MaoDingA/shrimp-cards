///|
pub(all) enum MessageKind {
  ClientJoin
  ClientReady
  ClientLeave
  ClientIntervention
  ServerAccepted
  ServerRejected
  ServerEvent
} derive(Eq, Debug, ToJson, FromJson)

///|
pub(all) struct TransportEnvelope {
  protocol_version : Int
  match_id : String
  window_id : @protocol.WindowId?
  sequence_id : @protocol.SequenceId
  kind : MessageKind
  payload : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn TransportEnvelope::new(
  match_id~ : String,
  window_id~ : @protocol.WindowId?,
  sequence_id~ : @protocol.SequenceId,
  kind~ : MessageKind,
  payload~ : String,
) -> TransportEnvelope {
  {
    protocol_version: @protocol.protocol_version,
    match_id,
    window_id,
    sequence_id,
    kind,
    payload,
  }
}

///|
pub fn TransportEnvelope::is_compatible(self : TransportEnvelope) -> Bool {
  self.protocol_version == @protocol.protocol_version
}

///|
pub fn TransportEnvelope::is_for_window(
  self : TransportEnvelope,
  current : @protocol.WindowId,
) -> Bool {
  match self.window_id {
    Some(window_id) => window_id == current
    None => false
  }
}
