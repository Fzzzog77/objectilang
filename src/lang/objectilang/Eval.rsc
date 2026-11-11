module lang::objectilang::Eval

/*
 * Objectilang - interprete sobre el AST.
 *
 * Ejecuta las sentencias del programa en orden y muestra en consola lo que
 * imprimen print/println. Si el programa define un metodo "main" de nivel
 * superior, se invoca al final.
 */

import IO;
import List;
import String;
import util::Math;
import lang::objectilang::AST;

// Valores y estado

data Value
  = intV(int n)
  | floatV(real r)
  | boolV(bool b)
  | charV(str c)
  | strV(str s)
  | objV(int id)
  | methodV(AMethodDef m, int self)   // self = -1 si no pertenece a un objeto
  | unitV()
  ;

data Obj = obj(str cls, lrel[str, Value] fields, map[str, AMethodDef] methods);

alias Env = map[str, Value];

private map[int, Obj] heap = ();
private int nextId = 0;
private map[str, AObjectDef] classes = ();
private Env globals = ();
private map[str, map[str, AMethodDef]] classMethods = ();  // metodos agregados con `Objeto.m = method ...`

data RuntimeError = runtimeError(str msg);

// Programa

void evalProgram(AProgram p) {
  heap = ();
  nextId = 0;
  classes = ();
  globals = ();
  classMethods = ();
  Env env = ();
  Value v = unitV();
  for (s <- p.statements) {
    <env, v> = execStmt(s, env, -1);
    globals = env;
  }
  if ("main" in env, methodV(AMethodDef m, int self) := env["main"]) {
    callMethod(m, self, []);
  }
}

// Sentencias

tuple[Env, Value] execStmt(objectStmt(AObjectDef d), Env env, int self) {
  classes[d.name] = d;
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(methodStmt(AMethodDef m), Env env, int self) {
  switch (m) {
    case methodDef([str n], _, _, _):   env[n] = methodV(m, self);
    case overrideDef([str n], _, _, _): env[n] = methodV(m, self);
    case methodAssign(_, _, _, _, _): assignMethod(m, env, self);
    case methodDecl(_, _, _, _):      assignMethod(m, env, self);
  }
  return <env, unitV()>;
}

// obj.m = method(...) { ... }
//  - obj es una variable: reemplaza (o agrega) el metodo m de esa instancia.
//  - obj es un objeto (Cat.talk = method ...): agrega el metodo a todas las
//    instancias del objeto y de sus hijos. Sin cuerpo queda abstracto.
private void assignMethod(AMethodDef m, Env env, int self) {
  str objName = m.objName;
  list[str] path = m.path;
  str name = last(path);
  AMethodDef def = m;
  if (methodAssign(_, _, ps, rt, body) := m) def = methodDef([name], [ps], rt, body);

  if (objName in classes, size(path) == 1, !isVariable(objName, env, self)) {
    map[str, AMethodDef] ms = (objName in classMethods) ? classMethods[objName] : ();
    ms[name] = def;
    classMethods[objName] = ms;
    return;
  }
  if (methodDecl(_, _, _, _) := m) {
    throw runtimeError("Un metodo sin cuerpo solo se puede declarar sobre un objeto");
  }
  Value target = lookup(objName, env, self);
  for (f <- prefix(path)) target = member(target, f);
  if (objV(int id) := target) {
    heap[id].methods[name] = def;
  } else {
    throw runtimeError("`<objName>` no es un objeto");
  }
}

private bool isVariable(str name, Env env, int self)
  = name in env || name in globals || (self >= 0 && name in fieldNames(heap[self].fields));

// Metodo agregado con `Objeto.m = method .` al objeto o a alguno de sus padres
private list[AMethodDef] classMethod(str cls, str name) {
  if (cls in classMethods, name in classMethods[cls]) return [classMethods[cls][name]];
  if (cls in classes, [extension(str p)] := classes[cls].parent) return classMethod(p, name);
  return [];
}

tuple[Env, Value] execStmt(valDecl(str n, _, AExpression e), Env env, int self) {
  env[n] = eval(e, env, self);
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(varDecl(str n, _, AExpression e), Env env, int self) {
  env[n] = eval(e, env, self);
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(forEach(str v, _, AInvocation iter, AStatement body), Env env, int self) {
  for (<_, Value x> <- elements(evalInvocation(iter, env, self))) {
    execStmt(body, env + (v : x), self);
  }
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(forEachTuple(list[str] vs, _, AInvocation iter, AStatement body), Env env, int self) {
  for (<str k, Value x> <- elements(evalInvocation(iter, env, self))) {
    Env inner = env;
    if (size(vs) > 0) inner[vs[0]] = strV(k);
    if (size(vs) > 1) inner[vs[1]] = x;
    execStmt(body, inner, self);
  }
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(forRange(str v, AExpression init, AExpression cond, str step, AStatement body), Env env, int self) {
  Env inner = env + (v : eval(init, env, self));
  while (boolV(true) := eval(cond, inner, self)) {
    execStmt(body, inner, self);
    if (intV(int n) := inner[step]) inner[step] = intV(n + 1);
    else throw runtimeError("`<step>++` requiere un Int");
  }
  return <env, unitV()>;
}

tuple[Env, Value] execStmt(exprStmt(AExpression e), Env env, int self) = <env, eval(e, env, self)>;

tuple[Env, Value] execStmt(emptyStmt(), Env env, int self) = <env, unitV()>;

// Un bloque tiene su propio ambito; su valor es el de la ultima sentencia.
Value execBlock(block(list[AStatement] stmts), Env env, int self) {
  Value last = unitV();
  for (s <- stmts) <env, last> = execStmt(s, env, self);
  return last;
}

// Objetos

Value instantiate(str cls, list[Value] args, list[AMethodDef] extra) {
  if (cls notin classes) throw runtimeError("Objeto `<cls>` no definido");
  int id = nextId;
  nextId += 1;
  heap[id] = obj(cls, [], ());
  initObject(classes[cls], id, args);
  for (m <- extra) {
    switch (m) {
      case methodDef([str n], _, _, _):   heap[id].methods[n] = m;
      case overrideDef([str n], _, _, _): heap[id].methods[n] = m;
    }
  }
  return objV(id);
}

private void initObject(AObjectDef d, int id, list[Value] args) {
  list[AParam] ps = [p | params(items) <- d.parameters, p <- items];
  // Primero la parte heredada
  for (extension(str parent) <- d.parent) {
    if (parent notin classes) throw runtimeError("Objeto `<parent>` no definido");
    initObject(classes[parent], id, (ps == []) ? args : []);
  }

  for (i <- index(ps), i < size(args)) setField(id, ps[i].name, args[i]);
  for (block(stmts) <- d.body, s <- stmts) {
    switch (s) {
      case valDecl(str n, _, AExpression e): setField(id, n, eval(e, (), id));
      case varDecl(str n, _, AExpression e): setField(id, n, eval(e, (), id));
      case methodStmt(m:methodDef([str n], _, _, _)):   heap[id].methods[n] = m;
      case methodStmt(m:overrideDef([str n], _, _, _)): heap[id].methods[n] = m;
      default: execStmt(s, (), id);
    }
  }
  // Metodos agregados al objeto con `Nombre.m = method ...`
  if (d.name in classMethods) {
    for (str n <- classMethods[d.name]) heap[id].methods[n] = classMethods[d.name][n];
  }
}

private void setField(int id, str name, Value v) {
  fs = heap[id].fields;
  if (name in fieldNames(fs)) {
    heap[id].fields = [<f, (f == name) ? v : old> | <f, old> <- fs];
  } else {
    heap[id].fields = fs + [<name, v>];
  }
}

private set[str] fieldNames(lrel[str, Value] fs) = {f | <f, _> <- fs};

// Acceso a un miembro de un valor
Value member(objV(int id), str name) {
  ob = heap[id];
  if ([*_, <name, Value v>, *_] := ob.fields) return v;
  if (name in ob.methods) return methodV(ob.methods[name], id);
  if ([AMethodDef m] := classMethod(ob.cls, name)) return methodV(m, id);
  throw runtimeError("`<ob.cls>` no tiene un miembro `<name>`");
}
default Value member(Value v, str name) {
  throw runtimeError("No se puede acceder a `<name>` en <toStr(v)>");
}

// Busqueda de un nombre: ambito local, luego el objeto actual, luego globales
Value lookup(str name, Env env, int self) {
  if (name in env) return env[name];
  if (name == "getClass") {   // predefinido: nombre del objeto actual
    if (self >= 0) return strV(heap[self].cls);
    throw runtimeError("`getClass` solo se puede usar dentro de un objeto");
  }
  if (self >= 0) {
    ob = heap[self];
    if ([*_, <name, Value v>, *_] := ob.fields) return v;
    if (name in ob.methods) return methodV(ob.methods[name], self);
    if ([AMethodDef m] := classMethod(ob.cls, name)) return methodV(m, self);
  }
  if (name in globals) return globals[name];
  throw runtimeError("Variable `<name>` no definida");
}

Value callMethod(AMethodDef m, int self, list[Value] args) {
  list[AParam] ps = [];
  ABlock body = block([]);
  switch (m) {
    case methodDef(_, list[AParams] pss, _, ABlock b):   { ps = [p | params(items) <- pss, p <- items]; body = b; }
    case overrideDef(_, list[AParams] pss, _, ABlock b): { ps = [p | params(items) <- pss, p <- items]; body = b; }
    case methodAssign(_, _, params(items), _, ABlock b): { ps = items; body = b; }
    case methodDecl(_, list[str] path, _, _):
      throw runtimeError("El metodo `<last(path)>` no tiene cuerpo (es abstracto)");
  }
  if (size(ps) != size(args)) throw runtimeError("Se esperaban <size(ps)> argumento(s), se dieron <size(args)>");
  Env env = (ps[i].name : args[i] | i <- index(ps));
  return execBlock(body, env, self);
}

// Elementos de un valor recorrible
lrel[str, Value] elements(objV(int id)) = heap[id].fields;
lrel[str, Value] elements(strV(str s)) = [<"<i>", charV(stringChar(charAt(s, i)))> | i <- [0..size(s)]];
default lrel[str, Value] elements(Value v) { throw runtimeError("No se puede recorrer <toStr(v)>"); }

// Expresiones

Value eval(intLit(int n), Env env, int self) = intV(n);
Value eval(floatLit(real r), Env env, int self) = floatV(r);
Value eval(charLit(str c), Env env, int self) = charV(unescape(c[1..-1]));
Value eval(trueLit(), Env env, int self) = boolV(true);
Value eval(falseLit(), Env env, int self) = boolV(false);
Value eval(stringLit(AStringLit s), Env env, int self) = strV(evalString(s, env, self));
Value eval(callExpr(AInvocation inv), Env env, int self) = evalInvocation(inv, env, self);

Value eval(newObject(str cls, _, list[ACallArgs] args, list[AObjectBody] body), Env env, int self)
  = instantiate(cls, [eval(a, env, self) | callArgs(as) <- args, a <- as],
                [m | objectBody(ms) <- body, m <- ms]);

Value eval(ifExpr(AExpression cond, AExpression t, AExpression f), Env env, int self) {
  if (boolV(true) := eval(cond, env, self)) return eval(t, env, self);
  return eval(f, env, self);
}

Value eval(blockExpr(ABlock b), Env env, int self) = execBlock(b, env, self);

// print/println valen el texto impreso (asi un metodo `: String` pueden terminar en un print)
Value eval(printExpr(list[AExpression] arg), Env env, int self) {
  str text = intercalate("", [toStr(eval(e, env, self)) | e <- arg]);
  print(text);
  return strV(text);
}

Value eval(printlnExpr(list[AExpression] arg), Env env, int self) {
  str text = intercalate("", [toStr(eval(e, env, self)) | e <- arg]);
  println(text);
  return strV(text);
}

Value eval(negate(AExpression e), Env env, int self) {
  switch (eval(e, env, self)) {
    case intV(int n):   return intV(-n);
    case floatV(real r): return floatV(-r);
    default: throw runtimeError("`-` requiere un numero");
  }
}

Value eval(logicalNot(AExpression e), Env env, int self) {
  if (boolV(bool b) := eval(e, env, self)) return boolV(!b);
  throw runtimeError("`neg` requiere Boolean");
}

Value eval(power(AExpression l, AExpression r), Env env, int self)    = arith("**", eval(l, env, self), eval(r, env, self));
Value eval(multiply(AExpression l, AExpression r), Env env, int self) = arith("*", eval(l, env, self), eval(r, env, self));
Value eval(divide(AExpression l, AExpression r), Env env, int self)   = arith("/", eval(l, env, self), eval(r, env, self));
Value eval(modulo(AExpression l, AExpression r), Env env, int self)   = arith("%", eval(l, env, self), eval(r, env, self));
Value eval(subtract(AExpression l, AExpression r), Env env, int self) = arith("-", eval(l, env, self), eval(r, env, self));

Value eval(add(AExpression l, AExpression r), Env env, int self) {
  vl = eval(l, env, self);
  vr = eval(r, env, self);
  if (strV(_) := vl || strV(_) := vr) return strV(toStr(vl) + toStr(vr));
  return arith("+", vl, vr);
}

Value eval(lessThan(AExpression l, AExpression r), Env env, int self)    = compare("\<", eval(l, env, self), eval(r, env, self));
Value eval(greaterThan(AExpression l, AExpression r), Env env, int self) = compare("\>", eval(l, env, self), eval(r, env, self));
Value eval(lessEq(AExpression l, AExpression r), Env env, int self)      = compare("\<=", eval(l, env, self), eval(r, env, self));
Value eval(greaterEq(AExpression l, AExpression r), Env env, int self)   = compare("\>=", eval(l, env, self), eval(r, env, self));
Value eval(equals(AExpression l, AExpression r), Env env, int self)      = boolV(eval(l, env, self) == eval(r, env, self));
Value eval(notEqual(AExpression l, AExpression r), Env env, int self)    = boolV(eval(l, env, self) != eval(r, env, self));

Value eval(andExpr(AExpression l, AExpression r), Env env, int self) {
  if (boolV(false) := eval(l, env, self)) return boolV(false);
  return eval(r, env, self);
}

Value eval(orExpr(AExpression l, AExpression r), Env env, int self) {
  if (boolV(true) := eval(l, env, self)) return boolV(true);
  return eval(r, env, self);
}

Value evalInvocation(invocation(list[str] path, _, list[ACallArgs] args), Env env, int self) {
  Value v = lookup(path[0], env, self);
  for (f <- path[1..]) v = member(v, f);
  if ([callArgs(as)] := args) {
    if (methodV(AMethodDef m, int s) := v) return callMethod(m, s, [eval(a, env, self) | a <- as]);
    throw runtimeError("`<intercalate(".", path)>` no es un metodo");
  }
  // Un metodo sin parametros se invoca al usarlo sin parentesis: obj.nombre
  if (methodV(AMethodDef m, int s) := v, arity(m) == 0) return callMethod(m, s, []);
  return v;
}

private int arity(methodDef(_, list[AParams] pss, _, _))      = size([p | params(items) <- pss, p <- items]);
private int arity(overrideDef(_, list[AParams] pss, _, _))    = size([p | params(items) <- pss, p <- items]);
private int arity(methodAssign(_, _, params(list[AParam] items), _, _)) = size(items);
private int arity(methodDecl(_, _, params(list[AParam] items), _))      = size(items);

// Aritmetica entera y real
private Value arith(str op, intV(int a), intV(int b)) {
  switch (op) {
    case "+": return intV(a + b);
    case "-": return intV(a - b);
    case "*": return intV(a * b);
    case "/": { if (b == 0) throw runtimeError("Division por cero"); return intV(a / b); }
    case "%": { if (b == 0) throw runtimeError("Division por cero"); return intV(a % b); }
    case "**": return (b >= 0) ? intV(toInt(pow(a, b))) : floatV(pow(toReal(a), b));
  }
  throw runtimeError("Operador desconocido <op>");
}
private default Value arith(str op, Value l, Value r) {
  if (<real a, real b> := <asReal(l), asReal(r)>) {
    switch (op) {
      case "+": return floatV(a + b);
      case "-": return floatV(a - b);
      case "*": return floatV(a * b);
      case "/": { if (b == 0) throw runtimeError("Division por cero"); return floatV(a / b); }
      case "%": return floatV(a - b * toReal(floor(a / b)));
      case "**": return floatV(pow(a, b));
    }
  }
  throw runtimeError("`<op>` requiere numeros, se encontro <toStr(l)> y <toStr(r)>");
}

private real asReal(intV(int n)) = toReal(n);
private real asReal(floatV(real r)) = r;
private default real asReal(Value v) { throw runtimeError("Se esperaba un numero, se encontro <toStr(v)>"); }

private Value compare(str op, strV(str a), strV(str b)) = boolV(cmp(op, a, b));
private Value compare(str op, charV(str a), charV(str b)) = boolV(cmp(op, a, b));
private default Value compare(str op, Value l, Value r) = boolV(cmp(op, asReal(l), asReal(r)));

private bool cmp(str op, value a, value b) {
  switch (op) {
    case "\<":  return a < b;
    case "\>":  return a > b;
    case "\<=": return a <= b;
    case "\>=": return a >= b;
  }
  throw runtimeError("Operador desconocido <op>");
}

// Cadenas

// plain:        "abc"           -> abc
// templateStr:  "a ${" tail      (prefijo sin la comilla inicial ni el ${)
// tailEnd:      expr "} b"       (sufijo sin el } ni la comilla final)
// tailMore:     expr "} b ${" rest
str evalString(plain(str t), Env env, int self) = expand(t[1..-1], env, self);
str evalString(templateStr(str pre, AStringTail tail), Env env, int self)
  = expand(pre[1..-2], env, self) + evalTail(tail, env, self);

str evalTail(tailEnd(AExpression e, str suf), Env env, int self)
  = toStr(eval(e, env, self)) + expand(suf[1..-1], env, self);
str evalTail(tailMore(AExpression e, str mid, AStringTail rest), Env env, int self)
  = toStr(eval(e, env, self)) + expand(mid[1..-2], env, self) + evalTail(rest, env, self);

// Texto de una cadena: procesa los escapes y la interpolacion corta $nombre
private str expand(str s, Env env, int self) {
  str out = "";
  int i = 0;
  while (i < size(s)) {
    str ch = s[i];
    if (ch == "\\" && i + 1 < size(s)) {
      str nx = s[i + 1];
      out += (nx == "n") ? "\n" : (nx == "t") ? "\t" : (nx == "r") ? "\r" : nx;
      i += 2;
    } else if (ch == "$" && i + 1 < size(s) && /^[a-zA-Z]$/ := s[i + 1]) {
      int j = i + 1;
      while (j < size(s) && /^[a-zA-Z0-9]$/ := s[j]) j += 1;
      out += toStr(lookup(s[i + 1 .. j], env, self));
      i = j;
    } else {
      out += ch;
      i += 1;
    }
  }
  return out;
}

// Escapes de un literal de caracter
private str unescape(str s) {
  str out = "";
  int i = 0;
  while (i < size(s)) {
    str ch = s[i];
    if (ch == "\\" && i + 1 < size(s)) {
      str nx = s[i + 1];
      out += (nx == "n") ? "\n" : (nx == "t") ? "\t" : (nx == "r") ? "\r" : nx;
      i += 2;
    } else {
      out += ch;
      i += 1;
    }
  }
  return out;
}

str toStr(intV(int n)) = "<n>";
str toStr(floatV(real r)) = "<r>";
str toStr(boolV(bool b)) = "<b>";
str toStr(charV(str c)) = c;
str toStr(strV(str s)) = s;
str toStr(unitV()) = "()";
str toStr(methodV(_, _)) = "\<method\>";
str toStr(objV(int id)) {
  ob = heap[id];
  return "<ob.cls>(<intercalate(", ", ["<f> = <toStr(v)>" | <f, v> <- ob.fields])>)";
}
