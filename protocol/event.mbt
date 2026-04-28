///|
pub(all) struct PublicEvent {
  code : String
  message : String
} derive(Eq, Debug, ToJson, FromJson)

///|
pub fn PublicEvent::new(code : String, message : String) -> PublicEvent {
  { code, message }
}
