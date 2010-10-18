(**
SimSoC-Cert, a library on processor architectures for embedded systems.
See the COPYRIGHTS and LICENSE files.

Formalization of the ARM architecture version 6 following the:

ARM Architecture Reference Manual, Issue I, July 2005.

Page numbers refer to ARMv6.pdf.

Generate the binary instruction for SimSoC decoder.
*)

open Ast;;
open Printf;;
open Util;;     (* for the "list" function *)
open Codetype;; (* from the directory "refARMparsing" *)
open Gencoqdec;;
open Dec;;
open Validity;;
open Flatten;;

(*Set the seed of the random generator*)
let init = Random.init 3
;;

(* output a 32 bits word in little-endian *)
let output_word out (word: int32) =
  output_byte out (Int32.to_int word);
  output_byte out (Int32.to_int (Int32.shift_right_logical word 8));
  output_byte out (Int32.to_int (Int32.shift_right_logical word 16));
  output_byte out (Int32.to_int (Int32.shift_right_logical word 24));;

(* add a bit on the right of 'w', e.g.: push_bit true 0b101 = 0b1011 *)
let push_bit (b: bool) (w: int32) =
  let w' = Int32.shift_left w 1 in
    if b then Int32.succ w' else w'

let push_bits (x: bool array) (y: int32) =
  let lst = Array.to_list x in
    List.fold_right push_bit lst y;; 

let insert_bit (b: int32) (p: int) (w: int32) =
  let i = Int32.shift_left b p in
    Int32.logor i w;;

(*insert bits at from position p*)
let insert_bits i p w =
  let is = Int32.shift_left i p in
    Int32.logor is w;;

type vcon =
  | Insert_bits of int *int
  | Insert_bit of bool * int
  | No_change
;;

type vconstraint =
  | NotPC of string   (* the string must contains the name of parameter *)
  (*| NotLR of string (* the string must contains the name of parameter *)*)
  (*| IsEven of string   (* parameter that should contain an even value *)*)
  | NoWritebackDest    (* no write-back with Rd==Rn *)
  | NotSame of string * string (* R<a> <> R<b> *)
  (*| NotLSL0            (* to distinguished between (equivalent?) mode cases *)*)
  (*| OtherVC of exp     (* Other validy constraints described by a boolean
   * expression *)*)
  | NotV of string * bool
  | NotVs of string * int
  | And of vconstraint * vconstraint
  | NotZero of string
  | Or of vconstraint * vconstraint
  | NoRestrict
;;

(*
(*Generate bits randomly*)
let gen_bin pc =
  let aux ls w =
    match ls with
      | Value s -> push_bit s w
      | Shouldbe s -> push_bit s w
      | Param1 _ | Param1s _ -> push_bit (Random.bool ()) w
      | Range _ -> push_bit (Random.bool ()) w
      | Nothing -> raise (Failure "unexpected case")
  in Array.fold_right aux pc Int32.zero;;

let bin_inst out ps =
  let md = add_mode (name ps) in
    match md with
      | DecInst -> (*output_word out (gen_bin ls)*)
      | DecEncoding -> ()
      | DecMode _ -> ();;

let gen_tests out _ dec =
  set_binary_mode_out out true;
  List.iter (bin_inst out) dec;;
*)

let max_v i1 i2 =
  if i1 > i2 then
    int_of_float (2.0** (float (i1-i2)))
  else 1;;

let restrict p =
let aux fmode =
  match fmode with
    | Some ("M1_LSRReg"|"M1_LSLReg"|"M1_ASRReg"|"M1_RRReg") -> 
	Or (NotPC "d", Or (NotPC "m", Or (NotPC "n", NotPC "s")))
    | Some ("M2_RegOff"|"M2_ScRegOff"|"M3_RegOff") -> 
	NotPC "m"
    | Some ("M2_Imm_preInd"|"M2_Imm_postInd"|"M3_Imm_preInd"|"M3_Imm_postInd"|"M5_Imm_preInd") -> 
	NotPC "n"
    | Some ("M2_Reg_preInd"|"M2_ScReg_preInd"|"M2_Reg_postInd"|"Sc_Reg_postInd"|"M3_Reg_preInd"|"M3_Reg_postInd") -> 
	Or (NotPC "m", Or (NotPC "n", NotSame ("n", "m")))
    | Some ("M4_IA"|"M5_IB"|"M5_DA"|"M5_DB") -> Or (NotV ("S", true), NotVs ("register_list", 0))
    | Some "M5_U" -> NotV ("U", false)
    | None ->
	begin match p.finstr with
	  | "ADC"|"ADD"|"AND" -> NotPC "d"
	  | "CLZ" -> Or (NotPC "m", NotPC "d")
	  | "CPS" ->
	      Or (And (NotVs ("imod", 0b00), NotV("mmod", false)), 
		  Or (And (NotVs ("imod",0b01), NotV ("mmod", false)), 
		      And (NotVs ("imod", 0b01), NotV ("mmod", true))))
	  | "LDM1"|"LDM2"|"STM1"|"STM2" -> And (NotPC "n", NotZero "register_list")
	  | "LDM3"|"LDRB" -> NotPC "n"
	  | "LDR"|"STR"|"STRB" -> NoWritebackDest
	  | "LDRBT" -> Or (NotPC "n", NotSame ("d", "n"))
	  | "LDREX" -> Or (NotPC "n", NotPC "d")
	  | "LDRH"|"LDRSB"|"LDRSH"|"STRH" -> Or (NotPC "d", NoWritebackDest)
	  | "LDRT"|"STRBT" -> Or (NotPC "d", NotSame ("d", "n"))
	  | "MCR"|"MCRR"|"MRS"-> NotPC "d"
	  | "MLA"|"SMLAxy"|"SMLAWy"|"SMLSD"|"SMMLS"  -> 
	       Or (NotPC "d", Or (NotPC "m", Or (NotPC "s", NotPC "n")))
	  | "MRRC" -> Or (NotSame ("d", "n"), Or (NotPC "d", NotPC "n"))
	  | "MUL"  -> Or (NotPC "d", Or (NotPC "s", NotPC "m"))
	  | "PKHBT"|"PKHTB"|"QADD"|"QADD8"|"QADD16"|"QADDSUBX"|"QDADD"|"QDSUB"|"QSUB"|"QSUB16"|"QSUB8"|"QSUBADDX"|"SADD16"|"SADD8"|"SADDSUBX"|"SEL"|"SHADD16"|"SHADD8"|"SHADDSUBX"|"SHSUB16"|"SHSUB8"|"SHSUBADDX"|"SSUB16"|"SSUB8"|"SSUBADDX"
	-> Or (NotPC "n", Or (NotPC "d", NotPC "m"))
	  | "REV"|"REV16"|"REVSH"|"SSAT"|"SSAT16"|"SXTAB"|"SXTAB16"|"SXTAH"|"SXTB"|"SXTB16"|"SXTH"-> Or (NotPC "d", NotPC "m")
	  | "RFE" -> NotPC "n"
	  | "SMLAD" -> Or (NotPC "d", Or (NotPC "m", NotPC "s"))
	  | "SMLAL"-> Or (NotPC "dHi", Or (NotPC "dLo", Or (NotPC "s", NotPC "m")))
	  | "SMLALxy"|"SMLALD"|"SMLSLD"|"SMULL"|"UMAAD"|"UMLAL"|"UMULL"-> Or (NotPC "dHi", Or (NotPC "dLo", Or (NotPC "s", Or (NotPC "m", NotSame ("d","n")))))
	  | "SMMUL"|"SMUAD"|"SMULxy"|"SMULWy"|"SMUSD"|"USAD8"|"USADA8" -> Or (NotPC "d", Or (NotPC "s", NotPC "m"))
	  | "STREX" -> Or (NotPC "n", Or (NotPC "d", Or (NotPC "m", Or (NotSame ("d","m"), NotSame ("d","n")))))
	  | "STRT"-> NotSame ("d","n")
	  | "SWP"|"SWPB" -> Or (NotPC "n", Or (NotPC "d", Or (NotPC "m", Or (NotSame ("d","m"), NotSame ("d","n")))))
	  | "UADD16"|"UADD8"|"UADDSUBX"|"UHADD16"|"UHADD8"|"UHADDSUBX"|"UHSUB16"|"UHSUB8"|"UHSUBADDX"|"UQADD16"|"UQADD8"|"UQADDSUBX"|"UQSUB16"|"UQSUB8"|"UQSUBADDX"|"USUB16"|"USUB8"|"USUBADDX" -> Or (NotPC "n", Or (NotPC "d", NotPC "m"))
	  | "USAT"|"USAT16"|"UXTAB"|"UXTAB16"|"UXTAH"|"UXTB"|"UXTB16"|"UXT H" -> Or (NotPC "d", NotPC "m")
	  | _ -> NoRestrict
	end
    | _ -> NoRestrict
in aux p.fmode 
;;


let notpc s (s', _, p2) w = 
  if (s' = s) then insert_bits (Int32.of_int (Random.int 15)) p2 w
  else w;;

let notv s b (s', _, p2)  w =
  if (s' = s) then insert_bit (if (not b) then Int32.one else Int32.zero) p2 w
  else w;;

let notvs s i (s', p1, p2) w =
  if (s' = s) then
    let r = Random.int (max_v p1 p2) in
      insert_bits (Int32.of_int (if (r = i) then (r+ 1) else r)) p2 w
  else w;;

let notsame s1 s2 params w =
  match params with
    | (s1', _, p12) -> 
	if (s1' = s1) then 
	  match params with
	    | (s2', _, p22) -> 
		if (s2' = s2) then
		  let r1 = Random.int 15 in
		  let r2 = Random.int 15 in
		    insert_bits (Int32.of_int r1) p12 
		      (insert_bits (Int32.of_int (if (r2 = r1) then (r2+ 1) else r2)) p22 w)
		else w
	else w
;;

let notzero s params w =
  match params with
    | (s', p1, p2) ->
	if (s' = s) then 
	  let is = (Random.int (max_v p1 p2)) in
	    insert_bits (Int32.of_int (if (is = 0) then (is+ 1) else is)) p2 w
        else w;;

let gen_tests ps =
  let fix_bits dec =
    match dec with
      | (Shouldbe b, p) -> Insert_bit (b,p)
      | (Value i, p) -> Insert_bit (i, p)
      | ((Range _ | Param1 _ | Param1s _ | Nothing), _) -> No_change
  in
  let random_bits ps =
    match ps with
      | (("n"|"m"|"s"|"d"|"dLo"|"dHi"),_, p2) -> 
	  Insert_bits (Random.int 16, p2)
      | (("cond"),_, p2) -> Insert_bits (Random.int 15, p2)
      | (_, p1, p2) -> 
	  Insert_bits (Random.int (max_v p1 p2), p2)  
  in let no_restrict_bits s ps =
    match ps with
      | (s', p1, p2) -> if (s' = s) then
	  No_change
	else Insert_bits (Random.int (max_v p1 p2), p2)
  in
  let proc vs w =
    match vs with
      | Insert_bits (i, p) -> insert_bits (Int32.of_int i) p w
      | Insert_bit (b, p) -> insert_bit (if b then Int32.one else Int32.zero) p w
      | No_change -> w
  in 
  let pos dec =
    let ar = Array.create (Array.length dec) (Nothing, 0) in
      for i = 0 to Array.length dec - 1 do
	ar.(i) <- (dec.(i), i)
      done;
    ar
  in
  let vparams s w1 =
    Int32.logor w1
      (Int32.logor (Array.fold_right proc (Array.map fix_bits (pos ps.fdec)) Int32.zero)
	 (List.fold_right proc (List.map (no_restrict_bits s) (parameters_of ps.fdec)) Int32.zero)) 
  in
  let rec gen res w = 
    match res with
      | Or (v1, v2) ->  gen v1 (gen v2 w)
	  (*if Random.bool() then (proc1 v1 w) else (proc1 v2 w)*)
      | And (v1, v2) -> gen v1 (gen v2 w)
      | NotPC s -> vparams s (List.fold_right (notpc s) ps.fparams w)
      | NotV (s, b) -> vparams s(List.fold_right (notv s b) ps.fparams w)
      | NotVs (s, i) -> vparams s (List.fold_right (notvs s i) ps.fparams w)
      | NotSame (s1, s2) -> vparams s2 (List.fold_right (notsame s1 s2) ps.fparams w)
      | NotZero s -> vparams s (List.fold_right (notzero s) ps.fparams w)
      | NoWritebackDest -> insert_bit Int32.one 21 w
      | NoRestrict -> 
	  Int32.logor (Array.fold_right proc (Array.map fix_bits (pos ps.fdec)) w)
	    (List.fold_right proc (List.map random_bits (parameters_of ps.fdec)) w)
  in match ps.finstr with
    | _ ->
	gen (restrict ps) Int32.zero
    (*| _ -> Int32.zero*)
;;

let bin_insts out fs =
  (*for i = 0 to 10 do*)
    output_word out (gen_tests fs)
  (*done*)
;;

let gen_test out pcs decs =
  set_binary_mode_out out true;
  let fs: fprog list = List.filter is_arm (flatten pcs decs) in
    List.iter (bin_insts out) fs;;
