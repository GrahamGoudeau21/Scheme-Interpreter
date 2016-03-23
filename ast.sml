type identifier = string
datatype let_type = LET | LET_STAR | LET_REC

datatype value = NIL
               | BOOL of bool
               | NUM of int
               | CLOSURE of
                   ((identifier list) * exp) * ((identifier * value) list)
               | S_EXP of s_exp
               (*
               | S_EXP_LIT of value
               | S_EXP_SYM of identifier
               | S_EXP_LIST of value list
               | PAIR of value * value
               list)
               | PRIMITIVE of string
               *)
and

s_exp = S_EXP_INT of int
      | S_EXP_BOOL of bool
      | S_EXP_SYM of identifier
      | S_EXP_LIST of s_exp list

and

exp = LIT of value
             | VAR of identifier
             | APPLY of exp * (exp list)
             (*
             | SET of identifier * exp
             | IFX of exp * exp * exp
             | WHILEX of exp * exp
             | BEGIN of exp list
             | LETX of let_type * (identifier list) * (exp list) * exp
             | LAMBDA of lambda
             *)
             withtype lambda = (identifier list) * exp

datatype def = VAL of identifier * exp
             | EXP of exp
             | DEFINE of identifier * lambda

fun value_to_string (NIL) = "[value: NIL]"
  | value_to_string (BOOL(true)) = "[value: #t]"
  | value_to_string (BOOL(false)) = "[value: #f]"
  | value_to_string (NUM(int)) = "[value: " ^ (Int.toString int) ^ "]"
  | value_to_string (CLOSURE(lambda, env)) = "[value: closure]"

fun exp_to_string (LIT(value)) = value_to_string value
  | exp_to_string (VAR(var)) = "[var " ^ var ^ "]"

fun print_def (VAL(ident, exp)) =
  (print ("(val " ^ ident ^ " " ^ exp_to_string exp ^ ")\n"))
  | print_def (EXP(exp)) = print ((exp_to_string exp) ^ ")\n")
  | print_def (DEFINE(ident, _)) =
  print ("(define " ^ ident ^ ")\n")

type error_message = string

exception VariableNotBound
exception UndefinedMethod
exception InvalidMethodName
exception MismatchFunctionArity

datatype runtime_Error = VAR_NOT_BOUND of error_message
                       | INVALID_METHOD of error_message
                       | UNDEFINED_METHOD of error_message
                       | MISMATCH_ARITY of error_message

fun raise_runtime_error error =
  let
    val runtime_err_msg = "Runtime error encountered:\n\t - \""
    fun get_msg msg = runtime_err_msg ^ msg ^ "\"\n"
    fun handle_error (VAR_NOT_BOUND(msg)) =
          (print (get_msg msg); raise VariableNotBound)
      | handle_error (INVALID_METHOD(msg)) =
          (print (get_msg msg); raise InvalidMethodName)
      | handle_error (UNDEFINED_METHOD(msg)) =
          (print (get_msg msg); raise UndefinedMethod)
      | handle_error (MISMATCH_ARITY(msg)) =
          (print (get_msg msg); raise MismatchFunctionArity)
  in handle_error error
  end

(*datatype env = ENV of (identifier * value) list*)
type env = (identifier * value) list

(*val init_env = (ENV([]))*)
val init_env = [] : env

fun print_all_env (xs: env) =
  (print "=== Environment state: ===\n";
   List.map
     (fn (ident, value) => print ("{" ^ ident ^ ", " ^
                                  (value_to_string value) ^ "}\n"))
     xs;
   print "\n")

fun bind_env key value (xs: env) = (key, value)::xs

fun find_env key [] =
      raise_runtime_error (VAR_NOT_BOUND("Var \"" ^ key ^ "\" not bound"))
  | find_env key ((ident, value)::xs) =
      if key = ident then value
      else find_env key xs

fun eval (LIT(value)) env = (value, env)
  | eval (VAR(ident)) env = ((find_env ident env), env)
  | eval (APPLY((VAR(ident)), exp_list)) env = 
      let
        val _ = print "Applying\n"
        fun bind_args [] [] env = env
          | bind_args (arg::args) (param::params) env =
              bind_env param (eval arg env) env
          | bind_args _ _ _ =
              raise_runtime_error
        val arguments = List.map (fn exp => eval exp) exp_list
        val bound_value = find_env ident env
        val closure = case bound_value of
          (CLOSURE(((ident_list, body), captured_env))) => bound_value
          | _ => 
            raise_runtime_error
              (UNDEFINED_METHOD("Method \"" ^ ident ^ "\" not found"))
      (*in ((find_env ident env), env)*)
      in
      end
  | eval (APPLY(exp, _)) env =
      let
        val (value, value_state) = eval exp env
      in
        (raise_runtime_error
          (INVALID_METHOD("Method name \"" ^
                          (value_to_string value) ^
                          "\" is invalid")))
      end
  (*
      let val (value, value_state) = eval exp
      in
      (raise_runtime_error
        (INVALID_METHOD("Method name \"" ^
                        (value_to_string value) ^
                        "\" is invalid")))
      end
      *)

fun execute defs =
      let
        fun execute_def (VAL((ident, exp))) env =
              let
                val (result, new_env) = eval exp env
              in
                (bind_env ident result env)
              end
          | execute_def (EXP(exp)) env =
              let
                val (result, new_env) = eval exp env
              in
                new_env
              end
          | execute_def (DEFINE((ident, lambda))) env =
              (bind_env
                ident
                (CLOSURE((lambda: (identifier list * exp),
                         env)))
                env)
      in
        List.foldl (fn (def, old_env) => execute_def def old_env) init_env defs
      end
