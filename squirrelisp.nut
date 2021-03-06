kLPar <- '(';
kRPar <- ')';
kQuote <- '\'';

class Nil {
}
kNil <- Nil();

class Num {
  constructor(n) { data = n; }
  data = 0;
}

class Sym {
  constructor(s) { data = s; }
  data = "";
}

sym_table <- { nil = kNil };
function makeSym(str) {
  if (!(str in sym_table)) {
    sym_table[str] <- Sym(str);
  }
  return sym_table[str];
}

sym_t <- makeSym("t");
sym_quote <- makeSym("quote");
sym_if <- makeSym("if");
sym_lambda <- makeSym("lambda");
sym_defun <- makeSym("defun");
sym_setq <- makeSym("setq");

class Error {
  constructor(s) { data = s; }
  data = "";
}

class Cons {
  constructor(a, d) { car = a; cdr = d; }
  car = kNil;
  cdr = kNil;
}

function safeCar(obj) {
  if (obj instanceof Cons) {
    return obj.car;
  }
  return kNil;
}

function safeCdr(obj) {
  if (obj instanceof Cons) {
    return obj.cdr;
  }
  return kNil;
}

class Subr {
  constructor(f) { fn = f; }
  fn = kNil;
}

class Expr {
  constructor(a, b, e) { args = a; body = b; env = e; }
  args = kNil;
  body = kNil;
  env = kNil;
}

function makeExpr(args, env) {
  return Expr(safeCar(args), safeCdr(args), env);
}

function nreverse(lst) {
  local ret = kNil;
  while (lst instanceof Cons) {
    local tmp = lst.cdr;
    lst.cdr = ret;
    ret = lst;
    lst = tmp;
  }
  return ret;
}

function pairlis(lst1, lst2) {
  local ret = kNil;
  while (lst1 instanceof Cons && lst2 instanceof Cons) {
    ret = Cons(Cons(lst1.car, lst2.car), ret);
    lst1 = lst1.cdr;
    lst2 = lst2.cdr;
  }
  return nreverse(ret);
}

function isSpace(c) {
  return c == '\t' || c == '\r' || c == '\n' || c == ' ';
}

function isDelimiter(c) {
  return c == kLPar || c == kRPar || c == kQuote || isSpace(c);
}

function skipSpaces(str) {
  local i;
  for (i = 0; i < str.len(); i++) {
    if (!isSpace(str[i])) {
      break;
    }
  }
  return str.slice(i);
}

function makeNumOrSym(str) {
  try {
    return Num(str.tointeger());
  } catch (_) {
    return makeSym(str);
  }
}

function readAtom(str) {
  local next = "";
  for (local i = 0; i < str.len(); i++) {
    if (isDelimiter(str[i])) {
      next = str.slice(i);
      str = str.slice(0, i);
    }
  }
  return [makeNumOrSym(str), next];
}

function read(str) {
  str = skipSpaces(str);
  if (str.len() == 0) {
    return [Error("empty input"), ""];
  } else if (str[0] == kRPar) {
    return [Error("invalid syntax: " + str), ""];
  } else if (str[0] == kLPar) {
    return readList(str.slice(1));
  } else if (str[0] == kQuote) {
    local tmp = read(str.slice(1));
    return [Cons(sym_quote, Cons(tmp[0], kNil)), tmp[1]];
  }
  return readAtom(str);
}

function readList(str) {
  local ret = kNil;
  while (true) {
    str = skipSpaces(str);
    if (str.len() == 0) {
      return [Error("unfinished parenthesis"), ""];
    } else if (str[0] == kRPar) {
      break;
    }
    local tmp = read(str);
    if (tmp[0] instanceof Error) {
      return tmp;
    }
    ret = Cons(tmp[0], ret);
    str = tmp[1];
  }
  return [nreverse(ret), str.slice(1)];
}

function printObj(obj) {
  if (obj instanceof Nil) {
    return "nil";
  } else if (obj instanceof Num) {
    return obj.data.tostring();
  } else if (obj instanceof Sym) {
    return obj.data;
  } else if (obj instanceof Error) {
    return "<error: " + obj.data + ">";
  } else if (obj instanceof Cons) {
    return printList(obj);
  } else if (obj instanceof Subr) {
    return "<subr>";
  } else if (obj instanceof Expr) {
    return "<expr>";
  }
  return "<unknown>"
}

function printList(obj) {
  local ret = "", first = true;
  while (obj instanceof Cons) {
    if (first) {
      first = false;
    } else {
      ret += " ";
    }
    ret += printObj(obj.car);
    obj = obj.cdr;
  }
  if (obj == kNil) {
    return "(" + ret + ")";
  }
  return "(" + ret + " . " + printObj(obj) + ")"
}

function findVar(sym, env) {
  while (env instanceof Cons) {
    local alist = env.car;
    while (alist instanceof Cons) {
      if (alist.car.car == sym) {
        return alist.car;
      }
      alist = alist.cdr;
    }
    env = env.cdr;
  }
  return kNil;
}

g_env <- Cons(kNil, kNil);

function addToEnv(sym, val, env) {
  env.car = Cons(Cons(sym, val), env.car);
}

function eval(obj, env) {
  if (obj instanceof Nil || obj instanceof Num || obj instanceof Error) {
    return obj;
  } else if (obj instanceof Sym) {
    local bind = findVar(obj, env);
    if (bind == kNil) {
      return Error(obj.data + " has no value");
    }
    return bind.cdr;
  }

  local op = safeCar(obj);
  local args = safeCdr(obj);
  if (op == sym_quote) {
    return safeCar(args);
  } else if (op == sym_if) {
    local c = eval(safeCar(args), env);
    if (c instanceof Error) { return c; }
    if (c == kNil) {
      return eval(safeCar(safeCdr(safeCdr(args))), env);
    }
    return eval(safeCar(safeCdr(args)), env);
  } else if (op == sym_lambda) {
    return makeExpr(args, env);
  } else if (op == sym_defun) {
    local expr = makeExpr(safeCdr(args), env);
    local sym = safeCar(args);
    addToEnv(sym, expr, g_env);
    return sym;
  } else if (op == sym_setq) {
    local val = eval(safeCar(safeCdr(args)), env);
    if (val instanceof Error) { return val; }
    local sym = safeCar(args);
    local bind = findVar(sym, env);
    if (bind == kNil) {
      addToEnv(sym, val, env);
    } else {
      bind.cdr = val;
    }
    return val;
  }
  return apply(eval(op, env), evlis(args, env));
}

function evlis(lst, env) {
  local ret = kNil;
  while (lst instanceof Cons) {
    local elm = eval(lst.car, env);
    if (elm instanceof Error) { return elm; }
    ret = Cons(elm, ret);
    lst = lst.cdr;
  }
  return nreverse(ret);
}

function progn(body, env) {
  local ret = kNil;
  while (body instanceof Cons) {
    ret = eval(body.car, env);
    body = body.cdr;
  }
  return ret;
}

function apply(fn, args) {
  if (fn instanceof Error) {
    return fn;
  } else if (args instanceof Error) {
    return args;
  } else if (fn instanceof Subr) {
    return fn.fn(args);
  } else if (fn instanceof Expr) {
    return progn(fn.body, Cons(pairlis(fn.args, args), fn.env));
  }
  return Error(printObj(fn) + " is not function");
}

function subrCar(args) {
  return safeCar(safeCar(args));
}

function subrCdr(args) {
  return safeCdr(safeCar(args));
}

function subrCons(args) {
  return Cons(safeCar(args), safeCar(safeCdr(args)));
}

function subrEq(args) {
  local x = safeCar(args);
  local y = safeCar(safeCdr(args));
  if (x instanceof Num && y instanceof Num) {
    if (x.data == y.data) {
      return sym_t;
    } else {
      return kNil;
    }
  } else if (x == y) {
    return sym_t;
  }
  return kNil;
}

function subrAtom(args) {
  if (safeCar(args) instanceof Cons) {
    return kNil;
  }
  return sym_t;
}

function subrNumberp(args) {
  if (safeCar(args) instanceof Num) {
    return sym_t;
  }
  return kNil;
}

function subrSymbolp(args) {
  if (safeCar(args) instanceof Sym) {
    return sym_t;
  }
  return kNil;
}

function subrAddOrMul(fn, init_val) {
  return function(args) {
    local ret = init_val;
    while (args instanceof Cons) {
      if (!(safeCar(args) instanceof Num)) {
        return Error("wrong type");
      }
      ret = fn(ret, safeCar(args).data);
      args = args.cdr;
    }
    return Num(ret);
  }
}
subrAdd <- subrAddOrMul(function(x, y) { return x + y; }, 0);
subrMul <- subrAddOrMul(function(x, y) { return x * y; }, 1);

function subrSubOrDivOrMod(fn) {
  return function(args) {
    local x = safeCar(args);
    local y = safeCar(safeCdr(args));
    if (!(x instanceof Num) || !(y instanceof Num)) {
      return Error("wrong type");
    }
    return Num(fn(x.data, y.data));
  }
}
subrSub <- subrSubOrDivOrMod(function(x, y) { return x - y; });
subrDiv <- subrSubOrDivOrMod(function(x, y) { return x / y; });
subrMod <- subrSubOrDivOrMod(function(x, y) { return x % y; });

addToEnv(makeSym("car"), Subr(subrCar), g_env);
addToEnv(makeSym("cdr"), Subr(subrCdr), g_env);
addToEnv(makeSym("cons"), Subr(subrCons), g_env);
addToEnv(makeSym("eq"), Subr(subrEq), g_env);
addToEnv(makeSym("atom"), Subr(subrAtom), g_env);
addToEnv(makeSym("numberp"), Subr(subrNumberp), g_env);
addToEnv(makeSym("symbolp"), Subr(subrSymbolp), g_env);
addToEnv(makeSym("+"), Subr(subrAdd), g_env);
addToEnv(makeSym("*"), Subr(subrMul), g_env);
addToEnv(makeSym("-"), Subr(subrSub), g_env);
addToEnv(makeSym("/"), Subr(subrDiv), g_env);
addToEnv(makeSym("mod"), Subr(subrMod), g_env);
addToEnv(sym_t, sym_t, g_env);

function readLine() {
  local c, line = "";
  while ((c = stdin.readn('c')) != '\n') {
    line = format("%s%c", line, c);
  }
  return line;
}

try {
  while (true) {
    print("> ");
    local line = readLine();
    print(printObj(eval(read(line)[0], g_env)));
    print("\n");
  }
} catch (_) {}
