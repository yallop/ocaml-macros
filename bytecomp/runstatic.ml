(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*               Olivier Nicole, Paris-Saclay University                  *)
(*                                                                        *)
(*                      Copyright 2016 OCaml Labs                         *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

let run_static ppf lam =
  let (init_code, fun_code) = Bytegen.compile_phrase lam in
  let (code, code_size, reloc, _) =
    Emitcode.to_memory init_code fun_code
  in
  let nothing () = () in
  Cmo_load.load_deps_static ppf reloc nothing nothing (fun exn -> raise exn);
  Symtable.patch_object 1 code reloc;
  Symtable.check_global_initialized 1 reloc;
  Symtable.update_global_table ();
  Printf.fprintf stderr "before reify\n%!";
  let splices = (Meta.reify_bytecode code code_size) () in
  Printf.fprintf stderr "after reify\n%!";
  Symtable.reset ();
  (Obj.obj splices : Parsetree.expression array)

let load_static_deps ppf =
  Printf.fprintf stderr "load_static_deps called\n%!";
  if not !Clflags.no_std_include then
    begin try
      Printf.fprintf stderr "including std\n%!";
      let stdarchive =
        Misc.find_in_path (Clflags.std_include_dir ()) "stdlib.cma" in
      Clflags.static_deps := stdarchive :: !Clflags.static_deps
    with
      Not_found -> Misc.fatal_error "stdlib.cma not found."
    end
  ;
  Printf.fprintf stderr "before init_static\n%!";
  Symtable.init_static ();
  Printf.fprintf stderr "after init_static\n%!";
  let nothing () = () in
  let load fname =
    Printf.fprintf stderr "static dep: %s\n%!" fname;
    if Filename.check_suffix fname ".cmo"
    || Filename.check_suffix fname ".cma" then begin
      ignore (Cmo_load.load_file false ppf fname
        nothing nothing (fun exn -> raise exn) 1 true);
      Printf.fprintf stderr "done loading!\n%!"
    end
    else
      Misc.fatal_error (fname ^ " is not a .cmo or .cma file.")
  in
  List.iter load !Clflags.static_deps;

