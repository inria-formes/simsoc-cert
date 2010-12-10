(**
SimSoC-Cert, a Coq library on processor architectures for embedded systems.
See the COPYRIGHTS and LICENSE files.

Formalization of the SH4 architecture following the:

SH-4, Software Manual, Renesas 32-Bit RISC, Rev.6.00 2006.09

Page numbers refer to Renesas_SH4_2006.pdf.


*)

module type PDF_PAGE = 
sig
  type t

  val open_in : string (** filename *) -> t
  val open_in_channel : in_channel -> t

(* val input_page : t -> (string list * t) option *)
  val input_page_rev : t -> (string list * t) option (** return the lines of the page in reverse order *)
  (** Complexity notes : Besides several calls to [input_line], for each page we call one [String.sub] *)
  val throw_page : t -> int -> t (** [throw_page _ n] read [max n 0] pages and ignores them *)

  val pos : t -> int (** current page number, first page is the number 0 *)

  val close_in : t -> unit (** remark : this function can be deleted if we prefer to close the channel after an End_of_file *)
end

module PDF_page : PDF_PAGE = 
struct
  (** The output of pdftotext contains the '\x0C' byte at the first character of some lines, indicating a new page. The last byte of the file is also '\x0C'.
      The goal of this module is to help the manipulation of such files. In particular, [input_page_rev] returns a list of lines representing a single page, without the '\x0C' mark. *)

  type t = { ic : in_channel ; next : string option ; pos : int }
  (** By concatenating [next] with [ic], we have the whole file being processing.
      The field [next] is considered as a lookahead buffer, to be able to detect the '\x0C' byte. *)

  let input_line ic = try Some (input_line ic) with End_of_file -> None

  let open_in_channel ic = 
    { ic = ic ; next = input_line ic ; pos = 0 }

  let open_in fic = 
    open_in_channel (open_in_bin fic)

  let input_page_rev t = 
    let rec aux l =
      match input_line t.ic with
	| None -> (* end of file reached *)
	  if l = [""] then
	    None
	  else (* WARNING this pdf file does not end with '\x0C' as last byte, we can return the whole end by default *)
	    assert false (* Some (l, { t with next = None ; pos = succ t.pos }) *)
	| Some s -> 
	  if s <> "" && s.[0] = '\x0C' then (** In case we have a mark signaling a new page, we take the rest of the string as the new buffer *)
	    Some (l, { t with next = Some (String.sub s 1 (pred (String.length s))) ; pos = succ t.pos })
	  else
	    aux (s :: l) in
    match t.next with
      | None -> None
      | Some s -> aux [s]

  let throw_page = 
    let rec aux t n = 
      if n <= 0 then
	t
      else
	match input_page_rev t with
	  | None -> t (* WARNING End_of_file reached, this function stops now by default *)
	  | Some (_, t) -> aux t (pred n) in
    aux

  let pos t = t.pos

  let close_in t = close_in t.ic
end

  (** Suppress the first block of empty string (eventually) figuring at the beginning of the list *)
  let del_line = 
    let rec aux = function 
      | "" :: l -> aux l
      | l -> l in
    aux 

    let l_match = List.for_all (fun (r, x) -> Str.string_match r x 0)

module type SH4_SECTION9 = 
sig
  type t

  val init : string (** filename *) -> t
  val init_channel : in_channel -> t

  val input_instr : t -> (string list list * t) option
    (** Each call to [input_instr] gives us a section (unit of instruction described in several pages) of the chapter 9 *)
    (** [None] is returned when a page doesn't match a predefined header and footer template. It is a simple solution found to detect the end of section 9, because each pages in section 9 contains the same header and footer. *)

  val c_code : t -> string list (** The small C code published at the beginning of the 9 section. *)
  val pos : t -> int (** The first number given by [pos] is 0. In fact, it indicates the number of time we have called [input_instr]. *)

  val close_in : t -> unit
end

module SH4_section9 : SH4_SECTION9 = 
struct
  (** This module imports the information needed in 'Section 9 Instruction Descriptions' of the manual. 
      During initialization (with [init] or [init_channel]), we jump directly to section 9. Then, we also import the small header written in C code at the beginning of the section 9. It describes some definitions and functions commonly used inside the pseudo-code (like declarations of variable PC, SR, R ... ).
  *)
  (** Remark : The algorithm of importation looks like the module [PDF_page].
   ** Instead of 
   **     - read [string]      one by one and search at the beginning a byte   '\x0C'    <- it is the end of a page
   ** we
   **     - read [string list] one by one and search at the beginning a string "9.[0-9]" <- it is the end of an instruction *)
 
  module P = PDF_page

  type t = { ic : P.t ; pos : int ; next : string list option ; c_code : string list }
  (** 
      - The field [next] represents the lookahead buffer, to detect the end of a section.
      - [c_code] is the "copy paste" of the code present at the beginning of the 9 section, some human explanations are however not kept. *)

  exception Unknown_header
  exception Unknown_footer

  let nb_page_to_ignore = 214 (* Section 9 begins at page 215 *) + 1 (* we don't import the first page *) 
  let nb_page_to_read = 202 (* the whole section 9 *)


  (** Behaves like [PDF_page.input_page_rev] but the header and the footer are suppressed (along with empty lines). 
      In the case we try to input a "not section 9" page, [Unknown_header] or [Unknown_footer] is thrown depending the case. *)
  let input_page_fmt =
    let r_head, r_foot1, r_foot2 =
      Str.regexp " *Section 9 Instruction Descriptions *", 
      Str.regexp " *REJ09B0318-0600 *", 
      Str.regexp " *Rev. 6.00 Sep 13, 2006 page [0-9]+ of 424 *" in
    fun t ->
    match P.input_page_rev t with
      | None -> None
      | Some (l, t) -> Some ((
	match l with
	  | x1 :: x2 :: xs when l_match [r_foot1, x1; r_foot2, x2] -> 
	    (match List.rev (del_line xs) with
	      | x :: xs when l_match [r_head, x] -> del_line xs
	      | xs -> raise Unknown_header
	    ) 
 	  | _ -> raise Unknown_footer
      ), t)

  (** Same as [input_page_fmt] but an error is thrown instead of returning [None] *)
  let input_page t = 
    match input_page_fmt t with
      | None -> assert false (* We suppose we never reach the end of file. Remark that [input_page] is not called directly outside the module. *) 
      | Some r -> r

  (** [input_page_groups n _] applies [n] times [input_page] and returns the whole as a list (ordering is natural : the first element is the first read). *)
  let input_page_groups = 
    let rec aux ll n t = 
      if n = 0 then
	List.rev ll, t
      else
	let l, t = input_page t in
	aux (l :: ll) (pred n) t in
    aux []
	
  (** We describe above the lines written in human language we don't want to keep *)
  (** Remark that the program had been run (and tested) with increasing list and valid position only *)
  let comment_c_code1 = [3; 4; 10; 11; 15; 22; 34]
  let comment_c_code2 = [1; 5; 8]

  (** [dont_keep l_num l] returns [l] but all the element figuring at position specified by [l_num] are discarded.
      We suppose [l_num] is sorted in increasing order, the first element is 0. *)
  let dont_keep = 
    let rec aux p = function 
      | n :: ns, x :: xs when p = n -> aux (succ p) (ns, xs)
      | n :: ns, x :: xs when p < n -> x :: aux (succ p) (n :: ns, xs)
      | [], l -> l
      | _ -> assert false in
    fun l_num l ->
    aux 0 (l_num, l)

  (** Here comes the initialization of the processing, [f_open] and [f] are used to return an input channel. *)
  let init_ f_open f = 
    let t = P.throw_page (f_open f) nb_page_to_ignore in (** go to section 9 and ignore the first page of section 9 *)
    let l1, t = input_page t in let l1 = dont_keep comment_c_code1 l1 in (** page [1]  C code *)
    let l2, t = input_page t in let l2 = dont_keep comment_c_code2 l2 in (** page [2]  C code *)
    let ll, t = input_page_groups 10 t in (** page [3-12]  C code *)
    let t = P.throw_page t 1 in (** go to beginning of instruction *)

    let l, t = input_page t in (** we read one more page for the initialization of the buffer *)
    { ic = t ; pos = 0 ; next = Some l ; c_code = List.flatten (l1 :: l2 :: ll) }

  let init = init_ P.open_in
  let init_channel = init_ P.open_in_channel

  (** The algorithm of [input_instr] is simple : we call [input_page] as long as we don't have a new section, characterized by the presence of the mark "9.1", "9.2", ..., "9.103" at the beginning of the new page.
      In the case we encounter the exception [Unknown_header] or [Unknown_footer], we just halt. *)
  let input_instr =
    let r = Str.regexp "9\\.[0-9]+ +" in (** Indicates the beginning of an instruction section. (see chapter 9.) *)
    let some ll t = Some (ll, { t with pos = succ t.pos }) in
    fun t ->
      let rec aux ll = 
	match try Some (input_page t.ic) with Unknown_header -> None | Unknown_footer -> None with
	  | None -> some ll { t with next = None }
	  | Some (l, tt) ->
	    match l with 
	      | x :: _ when Str.string_match r x 0 -> some ll { t with ic = tt ; next = Some l }
	      | _ -> aux (l :: ll) in
      match t.next with
	| None -> None
	| Some l -> aux [l]

  let pos t = t.pos
  let c_code t = t.c_code

  let close_in t = P.close_in t.ic
end


let display_dec = false
let display_c = true

module States = struct
  type t = 
    | Tiret
    | Pos of int
    | Range of int * int
end

module T_bit = struct
  type t = 
    | Tiret
    | Zero
    | One
    | One_Zero
    | Borrow
    | Carry
    | LSB
    | MSB
    | Overflow
    | Result_of_
    | Test
    | Underflow
    | Empty
end

type decoder = 
    { h : string option
    ; inst_code : string option
    ; states : States.t
    ; t_bit : T_bit.t } 

let _ = 
  let module S = SH4_section9 in

  let t = S.init_channel stdin in
(* let t = S.init Sys.argv.(1) in *)

  (** [split_from_beg_at f l] returns [l1, x, l2] where the following conditions hold :
  - [l] is equal to [l1 @ [x] @ l2]
  - [x] is the first element in [l] such as [f x] evaluates to [true] *)
  let split_from_beg_at f =
    let rec aux l_pred = function
	| x :: xs -> 
	  if f x then
	    Some (List.rev l_pred, x, xs)
	  else
	    aux (x :: l_pred) xs
	| [] -> None in
    aux [] in

  (** Same as [split_from_beg_at] but the search start from the end of the list *)
  let split_from_end_at f = 
    let rec aux l_succ = function
	| x :: xs -> 
	  if f x then
	    Some (List.rev xs, x, l_succ)
	  else
	    aux (x :: l_succ) xs
	| [] -> None in
    fun l -> aux [] (List.rev l) in

  let split_beg s l = match split_from_beg_at s l with None -> assert false | Some s -> s in
  let split_end s l = match split_from_end_at s l with None -> assert false | Some s -> s in

  (** These regexp characterize the end of any C code present in the documentation *)
  let accol_end = Str.regexp " *} *" (* C code usually end with a '}' delimiter *) in
  let comment = Str.regexp " */\\*.*\\*/ *" (* a line containing C comment like /* */ *) in

  let find_nl = 
    let r = Str.regexp "^ *$" in
    let rec aux b1 l_pred = function
      | x :: xs ->
	let b2 = l_match [ r, x ] in
	if b1 && b2 then
	  List.rev l_pred, xs
	else
	  aux b2 (x :: l_pred) xs in
    aux false [] in

  let matched_group_i n s = int_of_string (Str.matched_group n s) in
  let matched_group_t n s = let open T_bit in
    match Str.matched_group n s with
      | "\226\128\148" -> Tiret
      | "0" -> Zero
      | "1" -> One
      | "1/0" -> One_Zero
      | "Borrow" -> Borrow
      | "Carry" -> Carry
      | "LSB" -> LSB
      | "MSB" -> MSB
      | "Overflow" -> Overflow
      | "Result of" -> Result_of_
      | "Test" -> Test
      | "Underflow" -> Underflow 
      | "" -> Empty in

  let rec aux t =
    match S.input_instr t with 
      | None -> ()
      | Some (l, t) -> 
	let l = List.flatten (List.rev l) in
	let l1, _, l = split_beg ((=) "Description") l in (** [l1] contains the information between the beginning of the section and the line "Description" *)
	let l2, _, l = split_beg ((=) "Operation") l in (** [l2] contains the information between the line "Description" and the line "Operation" *)
	let l3, n, l = split_end (fun x -> List.exists (fun r -> Str.string_match r x 0) [ accol_end; comment ]) l in (** [l3 @ [n]] contains the C program between the line "Operation" and some human language information we are not interested *)
	begin

	  if display_dec then
	    begin 
	      List.iter (fun s -> Printf.printf "%s\n" s) (

		let x1 :: x2 :: l1, _, l2 = split_beg ((=) "") l1 in 
		(** Example : [x1] and [x2] contains
		    - "9.1 [whitespace] ADD [whitespace] ADD binary [whitespace] Arithmetic Instruction"
		    - " [whitespace] Binary Addition"
		*)

		let m l = l_match (List.map (function x1, x2 -> Str.regexp x1, x2) l) in

		let contains_instruction x = m [ "\\(.+\\) +\\([A-Z][a-z]+\\)-?\\([A-Z][a-z]+\\)* Instruction", x ] in

		let l, inst_ty = match () with
		  | _ when contains_instruction x1 -> 
		    let inst_ty = Str.matched_group 2 x1 ^ try "-" ^ Str.matched_group 3 x1 with _ -> "" in
		    let l = [Str.matched_group 1 x1 ; x2] in
		    (** In this part, we detect if the sequence "Delayed Branch Instruction" is present. *)
		    (* (* to be completed *) let _ = 
		      match inst_ty with
			| "Branch" -> 
			  (if m [ "\\(.+\\) +Delayed Branch Instruction", x2 ] then
			      Printf.printf "[[[[[\n%s\n]]]]]\n%!" (Str.matched_group 1 x2)
			   else 
			      ())
			| _ -> () in*)
		    l, inst_ty
		  | _ when contains_instruction x2 -> 
		    [x1 ; Str.matched_group 1 x2], Str.matched_group 2 x2 ^ try "-" ^ Str.matched_group 3 x2 with _ -> "" in 

		let x_exe :: header :: l2 = (** suppress the block of eventually empty lines at the beginning and the end *)
		  let f x = del_line (List.rev x) in
		  f (f l2) in

		let header = (** we rewrite correctly the title of the array *)
		  let tab = [ "Format" ; "Summary of Operation" ; "Instruction Code" ; "Execution States" ; "T Bit" ] in
		  match () with 
		    | _ when m [ "^ *Execution *$", x_exe ] -> 
		      (match Str.split (Str.regexp "  +") header with
			| [ "Format" ; "Summary of Operation Instruction Code" ; "States" ; "T Bit" ] 
			| [ "Format" ; "Summary of Operation" ; "Instruction Code" ; "States" ; "T Bit" ] 
			| [ "Format" ; "Summary of Operation" ; "nstruction Code" ; "States" ; "T Bit" ] -> tab
			| [ "PR Format" ; "Summary of Operation Instruction Code" ; "States" ; "T Bit" ] 
			| [ "PR" ; "Format" ; "Summary of Operation Instruction Code" ; "States" ; "T Bit" ] 
			| [ "PR" ; "Format" ; "Summary of Operation" ; "Instruction Code" ; "States" ; "T Bit" ] -> "PR" :: tab
			| [ "No. PR Format" ; "Summary of Operation Instruction Code" ; "States" ; "T Bit" ] -> "No." :: "PR" :: tab)
		    | _ when m [ "^ *Summary of +Execution *$", x_exe ] -> 
		      (** This case only applies to 9.37 and 9.38. Hopefully, the number of fields and the type of the data of each column are the same in both cases. *)
		      "No." :: (match String.sub (List.hd l) 0 4 with "9.37" -> "SZ" | "9.38" -> "PR") :: tab in

		let l2 = (** We regroup a line written into a multi-lines into a single block. Heuristic used : we consider as a member of a previous line, any line beginning with a space. *)
		  let rec aux l = function 
		    | x :: xs -> 
		    
		      let rec aux2 l_bl = function
			| x :: xs when x.[0] = ' ' -> aux2 (x :: l_bl) xs
			| xs -> List.rev l_bl, xs in
		      let l_bl, xs = aux2 [] xs in
		      if xs = [] then
			List.rev ((x, l_bl) :: l)
		      else
			aux ((x, l_bl) :: l) xs in
		  aux [] l2 in

		let _ = 
		  begin
		    List.iter (fun (s, l2) -> 
		      let info = 
		        (match () with
			  | _ when m [ "\\(.+\\) +\\([01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid][01nmid]\\) +\\([0-9]+\\)\\(\226\128\147\\([0-9]+\\)\\)? *\\(.*\\)", s ] ->
			    Some { h = Some (Str.matched_group 1 s)
				 ; inst_code = Some (Str.matched_group 2 s)
				 ; states = (let open States in
						 (match try Some (matched_group_i 5 s) with _ -> None with
						   | None -> fun x -> Pos x
						       | Some i_end -> fun i_beg -> Range (i_beg, i_end)) (matched_group_i 3 s))
				 ; t_bit = matched_group_t 6 s }
			  | _ when List.for_all ((=) "\226\128\148") (match Str.split (Str.regexp "  +") s with ("0" | "1") :: xs -> xs | xs -> xs) -> 
			    (** Remark: This branch had been run at least one time without a "Match_failure". If we suppose this code will only be used with the same reference manual, we can delete this guard condition. *)
			    None) in
		      match info with
			| Some { h = Some s1 } -> 
			  begin
			    Printf.printf "#%s#\n%!" header;
			    Printf.printf "|%s|\n%!" s1 ;
			    List.iter (fun s -> Printf.printf "|%s|\n%!" s) l2;
			    Printf.printf "\n%!";
			  end
			| _ -> ()
		      ) (match String.sub (List.hd l) 0 4 with
			| "9.31" -> let x1 :: x2 :: _ = l2 in [x1; x2]
			| "9.55" -> let x :: _ = l2 in [x]
			| "9.64" -> let x :: _ = l2 in [x]
			| "9.65" -> let x :: _ = l2 in [x]
			| _ -> l2);
		  end in
		[]
	      );
	    end;

	  if display_c then 
	    begin
	      Printf.printf "/* 9.%d */\n" (S.pos t);
	      List.iter (fun s -> Printf.printf "%s\n" s) l3; 
	      Printf.printf "%s\n" n; 
	    end;
	  aux t;
	end in

  begin
    if display_c then
      begin 
	List.iter (fun s -> Printf.printf "%s\n" s) (S.c_code t);
      end; 
    aux t;
    Printf.printf "%!";
  end