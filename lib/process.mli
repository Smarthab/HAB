(** The type of state machine, suitably polymorphic in underlying state, 
    input and output. State machines are encoded as resumptions. *)

(** Transitions are either requiring an input ([Input]) or requiring no input
    ([NoInput]). A process can also [Stop]. *)
type ('i,'o) transition = private
  | Input of ('i -> 'o)
  (** Requires an external input before proceeding to the next state. *)

  | NoInput of 'o
  (** Doesn't require any input before proceeding to the next state. *)

  | Stop
  (** Final state of the process. *)


(** The "state" of a machine is in fact divided in two parts:
    the usal part (component [state]) and the input/noinput
    state of the process. *)
type ('s,'i,'o) t = {
  move  : ('s, 'i, 'o) transition_function;
  state : 's
}

and ('s, 'i, 'o) transition_function =
  's -> ('i, ('s, 'i, 'o) outcome Lwt.t) transition

and ('s, 'i, 'o) outcome =
  {
    output : 'o option;
    next   : ('s, 'i, 'o) t
  }

(** Process names. *)
module Name :
sig

  type t

  val atom : string -> t
  val prod : t list -> t
  val show : t -> string
  val equal : t -> t -> bool

end

module Address :
sig

  type t = 
    { 
      owner : Types.public_identity;
      pname : Name.t
    }

  type access_path =
    | Root
    | Access of Name.t * access_path

  type 'a multi_dest = {
    dests : (t * access_path) list;
    msg   : 'a
  }

  type 'a prov = {
    path : access_path;
    msg  : 'a
  }

  include Types.Showable with type t := t
  include Types.Equalable with type t := t

  val show_access_path : access_path -> string
  val equal_access_path : access_path -> access_path -> bool

  val equal_multi_dest : ('a -> 'a -> bool) ->
    'a multi_dest -> 'a multi_dest -> bool

  val show_multi_dest : (Format.formatter -> 'a -> unit) ->
    'a multi_dest -> string

  val pp_multi_dest : (Format.formatter -> 'a -> unit) ->
    Format.formatter -> 'a multi_dest -> unit

end

(** Syntactic sugar to create addressed output messages 
    (type  Address.multi_dest). *)

(* [msg @ addr] creates a message { msg; dests = [addr,Root]}. *)
val (@) : 'a -> Address.t -> 'a Address.multi_dest

(* [msg @ (addr, path)] creates a message { msg; dests = [addr,path]}. *)
val (@.) : 'a -> Address.t * Address.access_path -> 'a Address.multi_dest

(* [msg @ dests] creates a message { msg; dests }. *)
val (@+) : 'a -> (Address.t * Address.access_path) list -> 'a Address.multi_dest

(** Syntactic sugar for access paths. *)
val (-->) : Name.t -> Address.access_path -> Address.access_path


(** Type of messages being communicated between state machines. *)
module type Message =
sig

  type t

  include Types.Equalable with type t := t
  include Types.Showable  with type t := t
  val serialize : t -> string
  val deserialize : string -> Address.access_path -> t

end

(** Processes are state machines with specified messages as inputs and 
    outputs.  *)
module type S =
sig

  module I : Message
  module O : Message

  type state
  val show_state : state -> string

  val name   : Name.t
  val thread : (state, I.t, O.t Address.multi_dest) t

end

type ('a, 'b) process_module = (module S with type I.t = 'a and type O.t = 'b)

(** [evolve p q] executes [p] until [Stop], then [q]. *)
val evolve :
  ('a, 'b) process_module ->
  ('a, ('b Address.multi_dest option * ('a, 'b) process_module) Lwt.t)
    transition

val ( >>> ) :
  ('a, 'b, 'c) transition_function ->
  ('a, 'b, 'c) transition_function ->
  ('a, 'b, 'c) transition_function

val with_input : ('i -> ('s, 'i, 'o) outcome Lwt.t) -> ('i, ('s, 'i, 'o) outcome Lwt.t) transition

val without_input : ('s, 'i, 'o) outcome Lwt.t -> ('i, ('s, 'i, 'o) outcome Lwt.t) transition

val stop : 's -> ('s, 'i, 'o) outcome Lwt.t

val continue_with : ?output:'o -> 's -> ('s, 'i, 'o) transition_function -> ('s, 'i, 'o) outcome Lwt.t

