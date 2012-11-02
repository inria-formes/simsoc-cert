(**
SimSoC-Cert, a toolkit for generating certified processor simulators
See the COPYRIGHTS and LICENSE files.

Pretty print CompCert type [AST.program fundef type] to Coq.
*)

open AST;;
open Values;;
open Csyntax;;
open Datatypes;;
open Printf;;
open Camlcoq;;
open Util;;

(*****************************************************************************)
(** printing functions for basic OCaml data structures *)

let using string_of_elt b x = string b (string_of_elt x);;

let app1 b s f1 v1 = bprintf b "%s %a" s f1 v1;;
let app2 b s f1 v1 f2 v2 = bprintf b "%s %a %a" s f1 v1 f2 v2;;
let app3 b s f1 v1 f2 v2 f3 v3 =
  bprintf b "%s %a %a %a" s f1 v1 f2 v2 f3 v3;;
let app4 b s f1 v1 f2 v2 f3 v3 f4 v4 =
  bprintf b "%s %a %a %a %a" s f1 v1 f2 v2 f3 v3 f4 v4;;
let papp5 b s f1 v1 f2 v2 f3 v3 f4 v4 f5 v5 =
  bprintf b "%s %a %a %a %a %a" s f1 v1 f2 v2 f3 v3 f4 v4 f5 v5;;

let papp1 b s f1 v1 = bprintf b "(%s %a)" s f1 v1;;
let papp2 b s f1 v1 f2 v2 = bprintf b "(%s %a %a)" s f1 v1 f2 v2;;
let papp3 b s f1 v1 f2 v2 f3 v3 =
  bprintf b "(%s %a %a %a)" s f1 v1 f2 v2 f3 v3;;
let papp4 b s f1 v1 f2 v2 f3 v3 f4 v4 =
  bprintf b "(%s %a %a %a %a)" s f1 v1 f2 v2 f3 v3 f4 v4;;
let papp5 b s f1 v1 f2 v2 f3 v3 f4 v4 f5 v5 =
  bprintf b "(%s %a %a %a %a %a)" s f1 v1 f2 v2 f3 v3 f4 v4 f5 v5;;

let todo b _ = string b "TODO";;

(*****************************************************************************)
(** Coq header *)

let header = "\
(**\n\
SimSoC-Cert, a toolkit for generating certified processor simulators\n\
See the COPYRIGHTS and LICENSE files.\n\
\n\
Coq representation of a C program automatically generated by Simgen.\n\
*)\n\
\n\
Require Import ZArith Cnotations.\n\
\n\
Open Scope Z_scope.\n";;

(*****************************************************************************)
(** printing functions for basic Coq data structures *)

let bool b = bprintf b "%b";;

let option elt b = function
  | None -> bprintf b "None"
  | Some x -> bprintf b "Some %a" elt x;;

let coq_list elt b = function
  | [] -> bprintf b "[]"
  | x :: l -> bprintf b "[%a%a]" elt x (list (prefix "; " elt)) l;;

let coq_pair f g b ((*Coq_pair *)(x, y)) = bprintf b "(%a,%a)" f x g y;;

let coq_pair2 f g b ((*Coq_pair*) (x,y)) = bprintf b "%a -: %a" f x g y;;

let coq_Z b x = int32 b (camlint_of_z x);;

let int b x =
  let x = camlint_of_coqint x in
    if x < 0l then par int32 b x else int32 b x;;

let positive b x = int32 b (camlint_of_positive x);;

let int8 b x =
  match Int32.to_int (camlint_of_coqint x) with
    | 10 -> string b "\n"
    | 34 -> ()
    | x when x >= 32 && x <= 126 -> bprintf b "%c" (Char.chr x)
    | x -> bprintf b "%03d" x;;

let float = todo;;

let float32 = todo;;

let float64 = todo;;

(*****************************************************************************)
(** printing function for [ident] *)

let identTable = Hashtbl.create 57;;

let string_of_ident id =
  try Hashtbl.find identTable id
  with Not_found ->
    Printf.sprintf "unknown_atom_%ld" (camlint_of_positive id);;

let ident = using string_of_ident;;

let valid_coq_ident s =
    match s with
      | "end" as s -> "_" ^ s
      | _ ->
          for i = 0 to String.length s - 1 do
            if s.[i] = '$' || s.[i] = ' ' then s.[i] <- '_'
          done;
          s;;

let add_ident id s = Hashtbl.add identTable id (valid_coq_ident s);;

let init_identTable () = Hashtbl.iter add_ident string_of_atom;;

let cmp_ident id1 id2 =
  Pervasives.compare (camlint_of_positive id1) (camlint_of_positive id2);;

let identifiers b =
  bprintf b "\n(* identifiers *)\n\nOpen Scope positive_scope.\n";
  List.iter
    (fun (id,s) -> bprintf b "Definition %s := %a.\n" s positive id)
    (List.sort (fun (id1,_) (id2,_) -> cmp_ident id1 id2)
       (Hashtbl.fold (fun id s l -> (id,s)::l) identTable []));
  bprintf b "Close Scope positive_scope.\n";;

(*****************************************************************************)
(** printing function for [signature] *)

let string_of_typ = function
  | AST.Tint -> "AST.Tint"
  | AST.Tfloat -> "AST.Tfloat";;

let typ = using string_of_typ;;

let signature b s =
  bprintf b "{| sig_args := %a; sig_res := %a |}"
    (coq_list typ) s.sig_args (option typ) s.sig_res;;

(*****************************************************************************)
(** printing function for [memory_chunk] *)

let string_of_memory_chunk = function
  | AST.Mint8signed -> "AST.Mint8signed"
  | AST.Mint8unsigned -> "AST.Mint8unsigned"
  | AST.Mint16signed -> "AST.Mint16signed"
  | AST.Mint16unsigned -> "AST.Mint16unsigned"
  | AST.Mint32 -> "AST.Mint32"
  | AST.Mfloat32 -> "AST.Mfloat32"
  | AST.Mfloat64 -> "AST.Mfloat64"

let memory_chunk = using string_of_memory_chunk

(*****************************************************************************)
(** printing function for [attr] *)

let just_no_attr _ = "noattr"

let no_attr = using just_no_attr

let attr b bo =
  bprintf b "{| attr_volatile := %a |}" bo;;

(*****************************************************************************)
(** recursor on Tstruct or Tunion idents occuring in a [coq_type] *)

(* CompCert-1.9 -> 1.11 change of type definition *)
let rec fold_type f x = function
  | Tvoid
  | Tint _
  | Tfloat _
  | Tcomp_ptr _ -> x
  | Tpointer (t, _)
  | Tarray (t, _, _) -> fold_type f x t
  | Tfunction (tl, t) -> fold_typelist f (fold_type f x t) tl
  | Tstruct (id, fl, _)
  | Tunion (id, fl, _) as t -> fold_fieldlist f (f t id x) fl

and fold_typelist f x = function
  | Tnil -> x
  | Tcons (t, tl) -> fold_typelist f (fold_type f x t) tl

and fold_fieldlist f x = function
  | Fnil -> x
  | Fcons (_, t, fl) -> fold_fieldlist f (fold_type f x t) fl;;

(*****************************************************************************)
(** iterator on Tstruct or Tunion idents occuring in a [coq_type] *)

(* CompCert-1.9 -> 1.11 change of type definition *)
let rec iter_type f = function
  | Tvoid
  | Tint _
  | Tfloat _
  | Tcomp_ptr _ -> ()
  | Tpointer (t, _)
  | Tarray (t, _, _) -> iter_type f t
  | Tfunction (tl, t) -> iter_type f t; iter_typelist f tl
  | Tstruct (id, fl, _)
  | Tunion (id, fl, _) as t -> f t id; iter_fieldlist f fl

and iter_typelist f = function
  | Tnil -> ()
  | Tcons (t, tl) -> iter_type f t; iter_typelist f tl

and iter_fieldlist f = function
  | Fnil -> ()
  | Fcons (_, t, fl) -> iter_type f t; iter_fieldlist f fl;;

(*****************************************************************************)
(** (coq_type,ident) map *)

module TypOrd = struct
  type t = coq_type
  let compare = Pervasives.compare
end;;

module TypMap = Map.Make (TypOrd);;

let typMap = ref TypMap.empty;;

let add_type_ident t id = typMap := TypMap.add t id !typMap;;

(*****************************************************************************)
(** printing function for [coq_type] replacing a struct or union by
    the corresponding defined name *)

let type_ident b id = bprintf b "typ_%a" ident id;;

let rec types_of_typelist = function
  | Tnil -> []
  | Tcons (t, tl) -> t :: types_of_typelist tl;;

(* CompCert-1.9 -> 1.11 change of type definition *)
let rec coq_type b = function
  | Tvoid -> string b "void"
  | Tint (IBool, _, _) -> string b "Tint IBool Unsigned noattr"
  | Tint (I8, Signed, _) -> string b "int8"
  | Tint (I8, Unsigned, _) -> string b "uint8"
  | Tint (I16, Signed, _) -> string b "int16"
  | Tint (I16, Unsigned, _) -> string b "uint16"
  | Tint (I32, Signed, _) -> string b "int32"
  | Tint (I32, Unsigned, _) -> string b "uint32"
  | Tfloat (F32, _) -> string b "float32"
  | Tfloat (F64, _) -> string b "float64"
  | Tpointer (t, _) -> app1 b "`*`" coq_type t
  | Tarray (t, n, a) -> app3 b "Tarray" pcoq_type t coq_Z n no_attr a
  | Tfunction (tl, t) -> app2 b "Tfunction" typelist tl pcoq_type t
  | Tcomp_ptr (id, _) -> app1 b "Tcomp_ptr" ident id
  | Tstruct (id, _, _)
  | Tunion (id, _, _) as t -> iter_type add_type_ident t; type_ident b id

and typelist b tl = bprintf b "T%a" (coq_list coq_type) (types_of_typelist tl)

and pcoq_type b t =
  match t with
    | Tvoid
    | Tint _
    | Tfloat _
    | Tstruct _
    | Tunion _ -> coq_type b t
    | Tpointer _
    | Tarray _
    | Tfunction _
    | Tcomp_ptr _ -> par coq_type b t;;

(*****************************************************************************)
(** ordering of struct and union type definitions *)

module IdOrd = struct
  type t = ident;;
  let compare = Pervasives.compare;;
end;;

module TC = TransClos (IdOrd);;

let lm = ref TC.XMap.empty;;

let compute_typ_order () =
  lm := TC.level_map
    (TypMap.fold
       (fun t id g ->
          fold_type
            (fun _ id' g -> if id = id' then g else TC.trans_add_edge id id' g)
            g t)
       !typMap TC.empty);;

let level id = try TC.XMap.find id !lm with Not_found -> 0;;

let cmp_level (_, id1) (_, id2) = Pervasives.compare (level id1) (level id2);;

(*****************************************************************************)
(** functions for printing Coq definitions for struct and union types *)

let rec fields_of_fieldlist = function
  | Fnil -> []
  | Fcons (id, t, fl) -> (id,t) :: fields_of_fieldlist fl;;

let field b = pair ident " -: " coq_type b;;

let fieldlist id s b fl =
  bprintf b "Definition typ_%s_%a := \nF%a.\n\n" s ident id 
    (coq_list (prefix "\n  " field)) (fields_of_fieldlist fl);;


(* CompCert-1.9 -> 1.11 change of type definition *)
let coq_type_def t =
  let type_type, id, fl = 
    match t with
      | Tvoid
      | Tint _
      | Tfloat _
      | Tpointer _
      | Tarray _
      | Tfunction _
      | Tcomp_ptr _ -> assert false
      | Tstruct (id, fl, _) -> "struct", id, fl
      | Tunion (id, fl, _) -> "union", id, fl in
  (fun b _ -> fieldlist id type_type b fl), 
  (fun b _ -> app2 b ("T" ^ type_type) ident id
    (fun b -> bprintf b "typ_%s_%a noattr" type_type ident) id);;

let structs_and_unions b =
  compute_typ_order ();
  bprintf b "\n(* structs and unions *)\n\n";
  List.iter
    (fun (t,id) ->
      let f_beg, f_body = coq_type_def t in
      bprintf b "%aDefinition %a := %a.\n\n" f_beg () type_ident id f_body ())
    (List.sort cmp_level (TypMap.bindings !typMap));;

(*****************************************************************************)
(** printing functions for [expr] *)

let string_of_unary_operation = function
  | Onotbool -> "!"
  | Onotint -> "`~"
  | Oneg -> "`-";;

let unary_operation = using string_of_unary_operation;;

let string_of_binary_operation = function
  | Oadd -> "+"
  | Osub -> "-"
  | Omul -> "*"
  | Odiv -> "/"
  | Omod -> "%"
  | Oand -> "&"
  | Oor -> "`|"
  | Oxor -> "^"
  | Oshl -> "<<"
  | Oshr -> ">>"
  | Oeq -> "=="
  | One -> "!="
  | Olt -> "<"
  | Ogt -> ">"
  | Ole -> "<="
  | Oge -> ">=";;

let binary_operation = using string_of_binary_operation;;

let block = coq_Z;;

let coq_val b = function
  | Vundef -> string b "Vundef"
  | Vint x -> int b x (* thanks to Coercion Vint : int >-> expr *)
  | Vfloat x -> papp1 b "Vfloat" float x
  | Vptr (x, i) -> papp2 b "Vptr" block x int i;;

let rec exprs_of_exprlist = function
  | Enil -> []
  | Econs (e, el) -> e :: exprs_of_exprlist el;;

let string_of_incr_or_decr = function
  | Incr -> "++"
  | Decr -> "--";;

let incr_of_decr = using string_of_incr_or_decr;;

let exptypMap = ref TypMap.empty;;

let exptyp_id = ref 0;;

let int_of_exptyp t =
  try TypMap.find t !exptypMap
  with Not_found ->
    incr exptyp_id;
    exptypMap := TypMap.add t !exptyp_id !exptypMap;
    !exptyp_id;;

let exptyp b t = bprintf b "T%d" (int_of_exptyp t);;

let of_exptyp b t = bprintf b "`:%a" exptyp t;;

let expr_types b =
  bprintf b "(* expression types *)\n\n";
  List.iter
    (fun (t,k) -> bprintf b "Definition T%d := %a.\n" k coq_type t)
    (List.sort (fun (_,k1) (_,k2) -> Pervasives.compare k1 k2)
       (TypMap.bindings !exptypMap));;

(* CompCert-1.9 -> 1.11 change of expr definition *)
let rec expr b = function
  | Eval (v, t) -> bprintf b "#%a%a" coq_val v of_exptyp t
  | Evar (id, t) -> bprintf b "$ %a%a" ident id of_exptyp t
  | Efield (e, id, t) -> bprintf b "%a|%a%a" pexpr e ident id of_exptyp t
  | Evalof (Evar (id, t), _) -> bprintf b "\\%a%a" ident id of_exptyp t
  | Evalof (e, t) -> papp2 b "valof" pexpr e exptyp t
  | Ederef (e, t) -> bprintf b "`*%a%a" pexpr e of_exptyp t
  | Eaddrof (e, t) -> bprintf b "&%a%a" pexpr e of_exptyp t
  | Eunop (op, e, t) ->
      bprintf b "%a%a%a" unary_operation op pexpr e of_exptyp t
  | Ebinop (op, e1, e2, t) ->
      bprintf b "%a%a%a%a" pexpr e1 binary_operation op pexpr e2 of_exptyp t
  | Ecast (e, t) -> papp2 b "Ecast" pexpr e exptyp t
  | Econdition (e1, e2, e3, t) ->
      bprintf b "%a?%a`:%a%a" pexpr e1 pexpr e2 pexpr e3 of_exptyp t
  | Esizeof (t1, t2) -> papp2 b "sizeof" exptyp t1 exptyp t2
  | Ealignof (t1, t2) -> papp2 b "alignof" exptyp t1 exptyp t2
  | Eassign (e1, e2, t) -> bprintf b "%a `= %a%a" pexpr e1 pexpr e2 of_exptyp t
  | Eassignop (op, e1, e2, t1, t2) ->
      bprintf b "%a %a= %a%a%a" pexpr e1 binary_operation op pexpr e2
        of_exptyp t1 of_exptyp t2
  | Epostincr (id, e, t) ->
      bprintf b "%a%a%a" pexpr e incr_of_decr id of_exptyp t
  | Ecomma (e1, e2, t) -> papp3 b "Ecomma" pexpr e1 pexpr e2 exptyp t
  | Ecall (e, el, t) -> papp3 b "call" pexpr e exprlist el exptyp t
  | Eloc (x, i, t) -> papp3 b "Eloc" block x int i exptyp t
  | Eparen (e, t) -> papp2 b "Eparen" pexpr e exptyp t

and pexpr b e =
  match e with
    | Eval _
    | Evar _
    | Efield _
    | Evalof (Evar _, _)
    | Ederef _
    | Eaddrof _
    | Eunop _
    | Ebinop _
    | Econdition _
    | Eassign _
    | Eassignop _
    | Epostincr _ -> par expr b e
    | Evalof _
    | Ecast _
    | Esizeof _
    | Ealignof _
    | Ecomma _
    | Ecall _
    | Eloc _
    | Eparen _ -> expr b e

and exprlist b el = bprintf b "E%a" (coq_list expr) (exprs_of_exprlist el);;

(*****************************************************************************)
(** printing functions for [statement] *)

let label = ident;;

let rec statement b = function
  | Sskip -> string b "skip"
  | Sdo e -> expr b e (* thanks to Coercion Sdo : expr >-> statement *)
  | Ssequence (s1, s2) -> bprintf b "%a;;\n%a" statement s1 statement s2
  | Sifthenelse (e, s1, s2) ->
      bprintf b "`if %a\nthen %a\nelse %a" pexpr e statement s1 statement s2
  | Swhile (e, s) -> bprintf b "while %a `do %a" pexpr e statement s
  | Sdowhile (e, s) -> bprintf b "`do %a while %a" statement s pexpr e
  | Sfor (s1, e, s2, s3) -> bprintf b "for (%a, %a, %a) { %a }"
      statement s1 pexpr e statement s2 statement s3
  | Sbreak -> string b "break"
  | Scontinue -> string b "continue"
  | Sreturn oe -> app1 b "return" (par (option pexpr)) oe
  | Sswitch (e, ls) ->
      bprintf b "switch (%a)\n(%a)" expr e labeled_statements ls
  | Slabel (l, s) -> bprintf b "label %a`: %a" label l statement s
  | Sgoto l -> app1 b "goto" label l

and labeled_statements b = function
  | LSdefault s -> bprintf b "default`: %a" statement s
  | LScase (i, s, ls) -> bprintf b "`case`%a`: %a\n:L: %a"
      int i statement s labeled_statements ls;;

(*****************************************************************************)
(** functions for printing Coq definitions for global variables *)

(* CompCert-1.9 -> 1.11  *)
let prog_var_ref b ((*Coq_pair*) (id, _)) =
  bprintf b "(%a,gv_%a)" ident id ident id;;
 
let init_data b = function
  | Init_int8 x -> bprintf b "\"%a\"" int8 x
  | Init_int16 x -> app1 b "Init_int16" int x
  | Init_int32 x -> app1 b "Init_int32" int x
  | Init_float32 x -> app1 b "Init_float32" float32 x
  | Init_float64 x -> app1 b "Init_float64" float64 x
  | Init_space x -> app1 b "Init_space" coq_Z x
  | Init_addrof (id, x) -> app2 b "Init_addrof" ident id int x;;

let is_printable x = (x >= 32 && x <= 126) || (x >= 9 && x <= 10);;

let char_of_init_data = function
  | Init_int8 x ->
      let x = Int32.to_int (camlint_of_coqint x) in
        if is_printable x then Char.chr x else raise Not_found
  | Init_int16 _
  | Init_int32 _
  | Init_float32 _
  | Init_float64 _
  | Init_space _
  | Init_addrof _ -> raise Not_found;;

let remove_null =
  let null = Init_int8 (coqint_of_camlint 0l) in
  let rec aux x = function
    | [] -> if x = null then [] else raise Not_found
    | y :: l -> let c = char_of_init_data x in
        if c = '"' then c :: c :: aux y l else c :: aux y l
  in function
    | [] -> []
    | x :: l -> aux x l;;

let is_int8 = function
  | Init_int8 _ -> true
  | Init_int16 _
  | Init_int32 _
  | Init_float32 _
  | Init_float64 _
  | Init_space _
  | Init_addrof _ -> false;;

let gvar_init =
  let b' = Buffer.create 100 in
    fun b l ->
      if List.for_all is_int8 l then
        try
          match remove_null l with
            | [] -> bprintf b "[Init_int8 0]"
            | l -> Buffer.clear b';
                List.iter (bprintf b' "%c") l;
                bprintf b "null_termin_string \"%a\"" Buffer.add_buffer b'
        with Not_found ->
          bprintf b "list_init_data_of_list_ascii %a%%char"
            (coq_list init_data) l
      else coq_list init_data b l;;

let prog_var_def b ((*Coq_pair*) (id, v)) =
  bprintf b "Definition gv_%a :=\n  {| gvar_info := %a;\n     \
    gvar_init := %a;\n     gvar_readonly := %a;\n     \
    gvar_volatile := %a |}.\n\n" ident id coq_type v.gvar_info
    gvar_init v.gvar_init bool v.gvar_readonly bool v.gvar_volatile;;

let global_variables b p =
  bprintf b "\n(* global variables *)\n\n%a\
    Definition global_variables : list (prod ident (globvar type)) := %a.\n"
    (list prog_var_def)
    (List.sort (fun ((*Coq_pair*)(id1,_)) ((*Coq_pair*)(id2,_)) -> cmp_ident id1 id2)
       p.prog_vars)
    (coq_list prog_var_ref) p.prog_vars;;

(*****************************************************************************)
(** functions for printing Coq definitions for C functions *)

let prog_funct_ref b ((*Coq_pair*) (id, _)) = bprintf b "fun_%a" ident id;;

let params = coq_list (prefix "\n" (coq_pair2 ident coq_type));;

let coq_function b f =
  bprintf b "{| fn_return := %a;\n     fn_params := %a;\n     \
    fn_vars := %a;\n     fn_body :=\n%a |}"
    coq_type f.fn_return params f.fn_params
    params f.fn_vars statement f.fn_body;;

(* CompCert-1.9 -> 1.11 change of external_function definition *)
let external_function b = function
  | EF_external (name, sg) -> papp2 b "EF_external" ident name signature sg
  | EF_builtin (name, sg) -> papp2 b "EF_builtin" ident name signature sg
  | EF_vload chunk -> papp1 b "EF_vload" memory_chunk chunk
  | EF_vstore chunk -> papp1 b "EF_vstore" memory_chunk chunk
  | EF_vload_global (chunk, id, ofs) -> 
    papp3 b "EF_vload_global" memory_chunk chunk ident id int ofs
  | EF_vstore_global (chunk, id, ofs) ->
    papp3 b "EF_vstore_global" memory_chunk chunk ident id int ofs
  | EF_malloc -> string b "EF_malloc"
  | EF_free -> string b "EF_free"
  | EF_memcpy (sz, al) -> papp2 b "EF_memcpy" coq_Z sz coq_Z al
  | EF_annot (text, targs) -> papp2 b "EF_annot" ident text (coq_list typ) targs
  | EF_annot_val (text, targ) -> papp2 b "EF_annot_val" ident text typ targ

let fundef_internal id b = 
  bprintf b "Definition fun_internal_%a :=\n  %a.\n\n" ident id coq_function

let fundef id = function
  | Internal f -> 
    (fun b _ -> fundef_internal id b f),
    (fun b _ -> bprintf b "Internal fun_internal_%a" ident id)
  | External (ef, tl, t) -> 
    (fun _ _ -> ()),
    (fun b _ -> bprintf b "External\n  %a\n  %a\n  %a"
      external_function ef typelist tl pcoq_type t);;

let prog_funct_def b ((*Coq_pair*) (id, fd)) =
  let f_beg, f_end = fundef id fd in
  bprintf b "%aDefinition fun_%a :=\n  (%a, %a).\n\n"
    f_beg () ident id ident id f_end ();;

let functions b p =
  bprintf b "\n(* functions *)\n\n%a\
    Definition functions : list (prod ident fundef) := %a.\n"
    (list prog_funct_def) p.prog_funct
    (coq_list prog_funct_ref) p.prog_funct;;

(*****************************************************************************)
(** printing function for [program] *)

let program b p = bprintf b
  "\n(* program *)\n\nDefinition p :=\n  \
    {| prog_funct := functions;\n     \
       prog_main := %a;\n     \
       prog_vars := global_variables |}.\n" ident p.prog_main;;

let to_buffer p =
  let b = Buffer.create 100000
  and b_gv_fun = Buffer.create 100000
  and b_exp_typ = Buffer.create 10000 in
    init_identTable ();
    string b header;
    identifiers b;
    global_variables b_gv_fun p;
    functions b_gv_fun p;
    expr_types b_exp_typ;
    structs_and_unions b;
    Buffer.add_buffer b b_exp_typ;
    Buffer.add_buffer b b_gv_fun;
    program b p;
    b;;
