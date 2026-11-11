module lang::objectilang::Checker

import ParseTree;
import List;
import String;
import Message;
extend analysis::typepal::TypePal;
import lang::objectilang::Syntax;
import lang::objectilang::Implode;

//Tipos del lenguaje
data AType
  = intType()
  | floatType()
  | boolType()
  | charType()
  | stringType()
  | unitType()
  | objectType(str name, list[AType] targs)
  | typeVar(str name)
  | methodType(list[AType] formals, AType ret)
  ;

str prettyAType(intType())    = "Int";
str prettyAType(floatType())  = "Float";
str prettyAType(boolType())   = "Boolean";
str prettyAType(charType())   = "Char";
str prettyAType(stringType()) = "String";
str prettyAType(unitType())   = "Unit";
str prettyAType(typeVar(n))   = n;
str prettyAType(objectType(n, []))    = n;
str prettyAType(objectType(n, targs)) = "<n>[<intercalate(", ", [prettyAType(t) | t <- targs])>]";
str prettyAType(methodType(fs, r))
  = "method(<intercalate(", ", [prettyAType(f) | f <- fs])>): <prettyAType(r)>";

data IdRole
  = objectId()
  | methodId()
  | typeVarId()
  ;

data PathRole = extendPath();

private map[str, str] parents = ();           // hijo -> padre
private map[str, list[str]] variances = ();   // objeto -> "+" | "-" | "" por parametro de tipo
private map[str, list[Tree]] ctorParams = (); // objeto -> arboles de tipo de sus parametros
private map[str, loc] objectScopes = ();      // objeto -> ambito de su definicion
private map[str, set[str]] objMembers = ();   // objeto -> campos y metodos propios

private set[str] BUILTIN = {"Int", "Float", "Boolean", "Char", "String"};

AType builtin("Int")     = intType();
AType builtin("Float")   = floatType();
AType builtin("Boolean") = boolType();
AType builtin("Char")    = charType();
AType builtin("String")  = stringType();

//Subtipos, herencias etc

bool isSub(AType t1, AType t2) {
  if (t1 == t2) return true;
  if (intType() := t1, floatType() := t2) return true;
  if (objectType(n1, a1) := t1, objectType(n2, a2) := t2) {
    if (n1 == n2) return argsSub(n1, a1, a2);
    if (n1 in parents) return isSub(objectType(parents[n1], []), t2);
    return false;
  }
  if (methodType(f1, r1) := t1, methodType(f2, r2) := t2) {
    return size(f1) == size(f2)
        && (true | it && isSub(f2[i], f1[i]) | i <- index(f1))
        && isSub(r1, r2);
  }
  return false;
}

private bool argsSub(str n, list[AType] a1, list[AType] a2) {
  if (a1 == [] || a2 == []) return true;  // tipo sin argumentos: se acepta
  if (size(a1) != size(a2)) return false;
  vs = (n in variances) ? variances[n] : [];
  for (i <- index(a1)) {
    v = (i < size(vs)) ? vs[i] : "";
    switch (v) {
      case "+": if (!isSub(a1[i], a2[i])) return false;
      case "-": if (!isSub(a2[i], a1[i])) return false;
      default:  if (a1[i] != a2[i]) return false;
    }
  }
  return true;
}

private bool isNumeric(AType t) = t == intType() || t == floatType();

AType instTypeParams(Tree _, objectType(_, list[AType] formals), objectType(_, list[AType] actuals), AType act, Solver _) {
  if (size(formals) == size(actuals)) {
    subst = (n : actuals[i] | i <- index(formals), typeVar(str n) := formals[i]);
    return visit (act) { case typeVar(str n) => subst[n] when n in subst };
  }
  return act;
}
default AType instTypeParams(Tree _, AType _, AType _, AType act, Solver _) = act;

tuple[list[str], set[IdRole]] typeNamesAndRole(objectType(str n, _)) = <[n], {objectId()}>;
default tuple[list[str], set[IdRole]] typeNamesAndRole(AType _) = <[], {}>;

// Herencia con "override": si el objeto hijo ya define el miembro buscado, 
// se ignora la definicion heredada del padre (no es una doble declaracion).
Accept acceptInherited(loc defScope, loc _, Use use, PathRole _, Solver s) {
  paths = s.getPathsByPathRole();
  if (extendPath() notin paths) return acceptBinding();
  for (<loc child, defScope> <- paths[extendPath()], s.isContainedIn(use.scope, child)) {
    if (any(Define d <- s.getAllDefines(), d.scope == child, d.id == use.id, d.idRole in use.idRoles)) {
      return ignoreContinue();
    }
  }
  return acceptBinding();
}

// Acceso a un miembro de un valor que no es un objeto
AType noMemberAccess(AType containerType, Tree selector, loc _, Solver s) {
  s.report(error(selector, "No se puede acceder a `<selector>`: el tipo %t no es un objeto", containerType));
  return unitType();
}

TypePalConfig objectilangConfig() = tconfig(
  isSubType = isSub,
  getTypeNamesAndRole = typeNamesAndRole,
  instantiateTypeParameters = instTypeParams,
  isAcceptablePath = acceptInherited,
  getTypeInNamelessType = noMemberAccess
);

//Entradas
TModel checkObjectilang(start[Program] pt) {
  parents = ();
  variances = ();
  ctorParams = ();
  objectScopes = ();
  objMembers = ();
  return collectAndSolve(pt, config = objectilangConfig());
}

list[Message] checkTypes(start[Program] pt) = checkObjectilang(pt).messages;
list[Message] checkTypes(str text) = checkTypes(parseObjectilang(text));
list[Message] checkTypes(loc file) = checkTypes(parseObjectilang(file));

bool wellTyped(str text) = [] == [m | m:error(_, _) <- checkTypes(text)];

// Utilidades sobre árbol completo
private list[Tree] optParts(Tree opt) = (appl(_, list[Tree] as) := opt) ? as : [];

private TypeExpr paramType((Param) `<Id _> : <TypeExpr t>`) = t;
private TypeExpr paramType((Param) `val <Id _> : <TypeExpr t>`) = t;

private str paramName((Param) `<Id n> : <TypeExpr _>`) = "<n>";
private str paramName((Param) `val <Id n> : <TypeExpr _>`) = "<n>";

// Nombres que declara una sentencia del cuerpo de un objeto
private set[str] declaredNames((Statement) `val <Id n> <TypeAnn? _> = <Expression _>`) = {"<n>"};
private set[str] declaredNames((Statement) `var <Id n> <TypeAnn? _> = <Expression _>`) = {"<n>"};
private set[str] declaredNames((Statement) `<MethodDef m>`) = methodName(m);
private default set[str] declaredNames(Statement _) = {};

private set[str] methodName((MethodDef) `method <Id? n> <Params? _> <TypeAnn? _> = <Block _>`) = {"<i>" | Id i <- optParts(n)};
private set[str] methodName((MethodDef) `method <Id? n> <Params? _> <TypeAnn? _> <Block _>`) = {"<i>" | Id i <- optParts(n)};
private set[str] methodName((MethodDef) `override <Id? n> <Params? _> <TypeAnn? _> = <Block _>`) = {"<i>" | Id i <- optParts(n)};
private default set[str] methodName(MethodDef _) = {};

// El objeto ya tiene un miembro con ese nombre
private bool hasMember(str obj, str name) {
  if (obj in objMembers && name in objMembers[obj]) return true;
  if (obj in parents) return hasMember(parents[obj], name);
  return false;
}

private list[Param] paramList(Params? ps)
  = [p | [Params pp] := optParts(ps), (Params) `( <{Param ","}* items> )` := pp, p <- items];

private list[Param] paramList((Params) `( <{Param ","}* items> )`) = [p | p <- items];

private list[TypeExpr] typeArgList(TypeArgs ta)
  = [t | (TypeArgs) `[ <{TypeExpr ","}+ ts> ]` := ta, t <- ts];

private list[TypeParam] typeParamList(TypeParams? tps)
  = [tp | [TypeParams tpl] := optParts(tps), (TypeParams) `[ <{TypeParam ","}+ items> ]` := tpl, tp <- items];

private str variance((TypeParam) `+ <TypeName _>`) = "+";
private str variance((TypeParam) `- <TypeName _>`) = "-";
default str variance(TypeParam _) = "";

private TypeName typeParamName(TypeParam tp) = tn when /TypeName tn := tp;

//Programas sentencias y bloques completos
void collect(current: (Program) `<Statement* stmts>`, Collector c) {
  for (s <- stmts) collect(s, c);
}

void collect(current: (Block) `{ <Statement* stmts> }`, Collector c) {
  c.enterScope(current);
    for (s <- stmts) collect(s, c);
  c.leaveScope(current);
  // El tipo de un bloque es el de su ultima expresion
  if ([*_, Statement last] := [s | s <- stmts], (Statement) `<Expression e>` := last) {
    c.fact(current, e);
  } else {
    c.fact(current, unitType());
  }
}

void collect(current: (Statement) `val <Id name> <TypeAnn? ann> = <Expression e>`, Collector c)
  = declareVar(name, ann, e, c);

void collect(current: (Statement) `var <Id name> <TypeAnn? ann> = <Expression e>`, Collector c)
  = declareVar(name, ann, e, c);

private void declareVar(Id name, TypeAnn? ann, Expression e, Collector c) {
  if ([TypeAnn ta] := optParts(ann), (TypeAnn) `: <TypeExpr t>` := ta) {
    c.define("<name>", variableId(), name, defType(t));
    collect(t, c);
    c.requireSubType(e, t,
      error(e, "`<name>` se declaro de tipo %t pero el valor es de tipo %t", t, e));
  } else {
    c.define("<name>", variableId(), name, defType(e));
  }
  collect(e, c);
}

void collect(current: (Statement) `for ( <Id v> <Generator _> <Invocation iter> ) <Statement body>`, Collector c) {
  collect(iter, c);
  c.enterScope(current);
    c.define("<v>", variableId(), v, defType([iter], elementType(iter, 0)));
    collect(body, c);
  c.leaveScope(current);
}

void collect(current: (Statement) `for ( ( <{Id ","}+ vs> ) <Generator _> <Invocation iter> ) <Statement body>`, Collector c) {
  collect(iter, c);
  c.enterScope(current);
    int i = 0;
    for (v <- vs) {
      c.define("<v>", variableId(), v, defType([iter], elementType(iter, i)));
      i += 1;
    }
    collect(body, c);
  c.leaveScope(current);
}

// Tipo del último elemento que produce un iterabl
private AType(Solver) elementType(Invocation iter, int i) = AType(Solver s) {
  t = s.getType(iter);
  if (objectType(_, list[AType] targs) := t, i < size(targs)) return targs[i];
  return t;
};

void collect(current: (Statement) `for ( <Id v> = <Expression init> , <Expression cond> , <Id step> ++ ) <Statement body>`, Collector c) {
  collect(init, c);
  c.requireEqual(init, intType(),
    error(init, "El valor inicial del ciclo debe ser Int, se encontro %t", init));
  c.enterScope(current);
    c.define("<v>", variableId(), v, defType(intType()));
    collect(cond, c);
    c.requireEqual(cond, boolType(),
      error(cond, "La condicion del ciclo debe ser Boolean, se encontro %t", cond));
    c.use(step, {variableId()});
    collect(body, c);
  c.leaveScope(current);
}


// objectStmt, methodStmt, exprStmt y emptyStmt son reglas de cadena:
// TypePal desciende automaticamente al unico hijo.

// Objetos

void collect(current: (ObjectDef) `object <Id name> <Extension? ext> <TypeParams? tps> <Params? ps> <Block? body>`, Collector c) {
  n = "<name>";
  tparams = typeParamList(tps);
  params = paramList(ps);

  variances[n] = [variance(tp) | tp <- tparams];
  ctorParams[n] = [paramType(p) | p <- params];
  if ([Extension e] := optParts(ext), (Extension) `extends <Id p>` := e) {
    parents[n] = "<p>";
  }

  c.define(n, objectId(), current,
    defType(objectType(n, [typeVar("<typeParamName(tp)>") | tp <- tparams])));
  objMembers[n] = {paramName(p) | p <- params}
    + {m | [Block b] := optParts(body), (Block) `{ <Statement* stmts> }` := b, s <- stmts, m <- declaredNames(s)};

  c.enterScope(current);
    objectScopes[n] = c.getScope();
    // El objeto padre debe existir
    if ([Extension e] := optParts(ext), (Extension) `extends <Id p>` := e) {
      c.addPathToDef(p, {objectId()}, extendPath());
    }
    for (tp <- tparams) {
      tn = typeParamName(tp);
      c.define("<tn>", typeVarId(), tn, defType(typeVar("<tn>")));
    }
    // Los parametros del constructor son campos del objeto
    for (p <- params) collect(p, c);
    // Las sentencias del cuerpo se recogen en el ambito del objeto
      if ([Block b] := optParts(body), (Block) `{ <Statement* stmts> }` := b) {
      for (s <- stmts) collect(s, c);
    }
  c.leaveScope(current);
}

void collect(current: (Param) `<Id name> : <TypeExpr t>`, Collector c) {
  c.define("<name>", variableId(), name, defType(t));
  collect(t, c);
}

void collect(current: (Param) `val <Id name> : <TypeExpr t>`, Collector c) {
  c.define("<name>", variableId(), name, defType(t));
  collect(t, c);
}

void collect(current: (Params) `( <{Param ","}* ps> )`, Collector c) {
  for (p <- ps) collect(p, c);
}

// Cuerpo de un objeto anonimo: new A(...) { method ... }
void collect(current: (ObjectBody) `{ <MethodDef* ms> }`, Collector c) {
  c.enterScope(current);
    for (m <- ms) collect(m, c);
  c.leaveScope(current);
}

// Tipos (anotaciones)

void collect(current: (TypeExpr) `<TypeName n>`, Collector c) {
  if ("<n>" in BUILTIN) {
    c.fact(current, builtin("<n>"));
  } else {
    //El tipo usado debe ser un objeto definido o un parametro de tipo
    c.use(n, {objectId(), typeVarId()});
    c.fact(current, n);
  }
}

void collect(current: (TypeExpr) `<TypeName n> <TypeArgs ta>`, Collector c) {
  args = typeArgList(ta);
  c.use(n, {objectId()});
  for (a <- args) collect(a, c);
  c.calculate("tipo generico", current, [n] + args, AType(Solver s) {
    base = s.getType(n);
    if (objectType(str bn, list[AType] formals) := base) {
      if (size(formals) != size(args)) {
        s.report(error(current, "`<bn>` espera <size(formals)> argumento(s) de tipo, se dieron <size(args)>"));
      }
      return objectType(bn, [s.getType(a) | a <- args]);
    }
    s.report(error(current, "`<n>` no es un objeto generico"));
    return base;
  });
}

// Metodos

void collect(current: (MethodDef) `method <Id? name> <Params? ps> <TypeAnn? ret> = <Block body>`, Collector c)
  = defineMethod(current, name, ps, ret, body, c);

void collect(current: (MethodDef) `method <Id? name> <Params? ps> <TypeAnn? ret> <Block body>`, Collector c)
  = defineMethod(current, name, ps, ret, body, c);

void collect(current: (MethodDef) `override <Id? name> <Params? ps> <TypeAnn? ret> = <Block body>`, Collector c)
  = defineMethod(current, name, ps, ret, body, c);

// obj.m = method(...) { ... }
/*  - Si `obj` es una variable: el metodo m debe existir en su objeto y el 
    nuevo metodo debe ser compatible con su tipo. 
    - Si `obj` es un objeto (Cat.talk = method ...): agrega el metodo m al
    objeto; si ya existia, el nuevo debe ser compatible con el anterior.
*/    
void collect(current: (MethodDef) `<Id obj> . <{Id "."}+ path> = method <Params ps> <TypeAnn? ret> <Block body>`, Collector c) {
  list[Id] ids = [i | i <- path];
  if ("<obj>" in objectScopes, [Id m] := ids) {
    assignToObject(current, obj, m, paramList(ps), ret, [body], c);
    return;
  }
  Tree prev = resolvePath([obj] + ids, c);
  defineMethod(current, [], paramList(ps), ret, body, c);
  c.requireSubType(current, prev,
    error(current, "El metodo asignado es de tipo %t pero `<prev>` es de tipo %t", current, prev));
}

// Obj.m = method(...): T  sin cuerpo declara un metodo abstracto del objeto
void collect(current: (MethodDef) `<Id obj> . <{Id "."}+ path> = method <Params ps> <TypeAnn? ret>`, Collector c) {
  list[Id] ids = [i | i <- path];
  if ("<obj>" in objectScopes, [Id m] := ids) {
    assignToObject(current, obj, m, paramList(ps), ret, [], c);
  } else {
    c.report(error(current, "Un metodo sin cuerpo solo se puede declarar sobre un objeto: `Objeto.metodo = method(...)`"));
  }
}

private void assignToObject(MethodDef current, Id obj, Id m, list[Param] params, TypeAnn? ret, list[Block] body, Collector c) {
  str n = "<obj>";
  c.use(obj, {objectId()});
  list[Tree] ptypes = [paramType(p) | p <- params];
  list[Tree] retAnn = [t | [TypeAnn ta] := optParts(ret), (TypeAnn) `: <TypeExpr t>` := ta];
  list[Tree] deps = ptypes + retAnn + body;
  AType(Solver) getMethodType = AType(Solver s) {
    AType r = unitType();
    if (retAnn != []) r = s.getType(retAnn[0]);
    else if (body != []) r = s.getType(body[0]);
    return methodType([s.getType(t) | t <- ptypes], r);
  };
  c.calculate("tipo del metodo", current, deps, getMethodType);

  if (hasMember(n, "<m>")) {
    loc oscope = objectScopes[n];
    c.require("metodo compatible", current, [current], void(Solver s) {
      AType prev = s.getTypeInScopeFromName("<m>", oscope, {variableId(), methodId()});
      s.requireSubType(current, prev,
        error(current, "El metodo asignado es de tipo %t pero `<n>.<m>` es de tipo %t", current, prev));
    });
  } else {
    objMembers[n] = objMembers[n] + {"<m>"};
    c.defineInScope(objectScopes[n], "<m>", methodId(), m, defType(deps, getMethodType));
  }

  c.enterScope(current);
    // Dentro del metodo se ven los miembros del objeto (como en su cuerpo)
    c.addPathToDef(obj, {objectId()}, extendPath());
    for (p <- params) collect(p, c);
    for (t <- retAnn) collect(t, c);
    for (b <- body) {
      for (t <- retAnn) {
        c.requireSubType(b, t, error(b, "El metodo retorna %t pero se declaro con tipo %t", b, t));
      }
      collect(b, c);
    }
  c.leaveScope(current);
}

private void defineMethod(MethodDef current, Id? name, Params? ps, TypeAnn? ret, Block body, Collector c)
  = defineMethod(current, [n | Id n <- optParts(name)], paramList(ps), ret, body, c);

private void defineMethod(MethodDef current, list[Id] name, list[Param] params, TypeAnn? ret, Block body, Collector c) {
  list[Tree] ptypes = [paramType(p) | p <- params];
  list[Tree] retAnn = [t | [TypeAnn ta] := optParts(ret), (TypeAnn) `: <TypeExpr t>` := ta];
  Tree retSrc = (retAnn == []) ? body : retAnn[0];

  AType(Solver) getMethodType = AType(Solver s) {
    return methodType([s.getType(t) | t <- ptypes], s.getType(retSrc));
  };

  if ([Id n] := name) {
    c.define("<n>", methodId(), n, defType(ptypes + [retSrc], getMethodType));
  }
  c.calculate("tipo del metodo", current, ptypes + [retSrc], getMethodType);

  c.enterScope(current);
    for (p <- params) collect(p, c);
    for (t <- retAnn) {
      collect(t, c);
      c.requireSubType(body, t,
        error(body, "El metodo retorna %t pero se declaro con tipo %t", body, t));
    }
    collect(body, c);
  c.leaveScope(current);
}

// Invocaciones: a.b.c(args)

// Resuelve la ruta de identificadores: el primero es una variable y cada uno
// de los siguientes debe ser un campo o metodo del tipo del anterior
// Devuelve el ultimo identf
private Tree resolvePath(list[Tree] ids, Collector c) {
  if ("<ids[0]>" == "getClass") {
    c.fact(ids[0], stringType());   // predefinido: nombre del objeto actual
  } else {
    c.use(ids[0], {variableId(), methodId()});
  }
  Tree prev = ids[0];
  for (i <- ids[1..]) {
    memberAccess(prev, i, c);
    prev = i;
  }
  return prev;
}

// Tipo de `container.selector`: se busca el miembro en el ambito del objeto
private void memberAccess(Tree container, Tree selector, Collector c) {
  loc scope = c.getScope();
  c.calculate("miembro `<selector>`", selector, [container], AType(Solver s) {
    AType ct = s.getType(container);
    if (objectType(str n, list[AType] actuals) := ct) {
      set[Define] defs = s.getDefinitions(n, scope, {objectId()});
      if ({Define d} := defs) {
        if (isEmpty(s.getDefinitions("<selector>", d.defined, {variableId(), methodId()}))) {
          s.report(error(selector, "`<n>` no tiene un campo ni un metodo llamado `<selector>`"));
        }

        AType t = s.getTypeInScopeFromName("<selector>", d.defined, {variableId(), methodId()});
        if (objectType(_, list[AType] formals) := s.getType(d.defInfo), size(formals) == size(actuals)) {
          t = substitute(formals, actuals, t);
        }
        return t;
      }
      s.report(error(selector, "No se encuentra la definicion del objeto `<n>`"));
    }
    s.report(error(selector, "No se puede acceder a `<selector>`: el tipo %t no es un objeto", ct));
    return unitType();
  });
}

private AType substitute(list[AType] formals, list[AType] actuals, AType t) {
  subst = (v : actuals[i] | i <- index(formals), typeVar(str v) := formals[i]);
  return visit (t) { case typeVar(str v) => subst[v] when v in subst };
}

void collect(current: (Invocation) `<{Id "."}+ path> <TypeArgs? targs> <CallArgs? cargs>`, Collector c) {
  Tree last = resolvePath([i | i <- path], c);
  for (Tree ta <- optParts(targs), t <- typeArgList(ta)) collect(t, c);

  if ([CallArgs ca] := optParts(cargs), (CallArgs) `( <{Expression ","}* es> )` := ca) {
    list[Tree] args = [e | e <- es];
    for (a <- args) collect(a, c);
    c.calculate("llamada", current, [last] + args, AType(Solver s) {
      if (methodType(list[AType] formals, AType ret) := s.getType(last)) {
        if (size(formals) != size(args)) {
          s.report(error(current, "`<last>` espera <size(formals)> argumento(s), se dieron <size(args)>"));
        }
        for (i <- index(args)) {
          s.requireSubType(args[i], formals[i],
            error(args[i], "El argumento <i + 1> de `<last>` debe ser %t, se encontro %t", formals[i], args[i]));
        }
        return ret;
      }
      s.report(error(current, "`<last>` no es un metodo (tiene tipo %t)", last));
      return unitType();
    });
  } else {
    c.calculate("acceso", current, [last], AType(Solver s) {
      // Un metodo sin parametros se puede usar sin parentesis: obj.nombre
      if (methodType([], AType ret) := s.getType(last)) return ret;
      return s.getType(last);
    });
  }
}

// Expresiones

void collect(current: (Expression) `<IntLit _>`, Collector c)   { c.fact(current, intType()); }
void collect(current: (Expression) `<FloatLit _>`, Collector c) { c.fact(current, floatType()); }
void collect(current: (Expression) `<CharLit _>`, Collector c)  { c.fact(current, charType()); }
void collect(current: (Expression) `true`, Collector c)         { c.fact(current, boolType()); }
void collect(current: (Expression) `false`, Collector c)        { c.fact(current, boolType()); }

void collect(current: (Expression) `<StringLit s>`, Collector c) {
  collect(s, c);
  c.fact(current, stringType());
}

void collect(current: (StringLit) `<StringPlain p>`, Collector c) { checkInterpVars(p, c); }
void collect(current: (StringLit) `<StringPre p> <StringTail t>`, Collector c) {
  checkInterpVars(p, c);
  collect(t, c);
}
void collect(current: (StringTail) `<Expression e> <StringPost p>`, Collector c) {
  collect(e, c);
  checkInterpVars(p, c);
}
void collect(current: (StringTail) `<Expression e> <StringMid p> <StringTail t>`, Collector c) {
  collect(e, c);
  checkInterpVars(p, c);
  collect(t, c);
}

// Interpolacion corta "$nombre": la variable debe estar definida
private void checkInterpVars(Tree tok, Collector c) {
  list[str] names = interpVars("<tok>");
  if (names == []) return;
  loc scope = c.getScope();
  c.require("variables interpoladas", tok, [], void(Solver s) {
    for (str v <- names, isEmpty(s.getDefinitions(v, scope, {variableId(), methodId()}))) {
      s.report(error(tok, "Variable `$<v>` no definida"));
    }
  });
}

// Nombres interpolados con $nombre en el texto de un token de cadena
// se ignoran los escapes como \$ y los ${ de la interpolacion larga
list[str] interpVars(str raw) {
  list[str] names = [];
  int i = 0;
  while (i < size(raw)) {
    if (raw[i] == "\\") { i += 2; continue; }
    if (raw[i] == "$" && i + 1 < size(raw) && /^[a-zA-Z]$/ := raw[i + 1]) {
      int j = i + 1;
      while (j < size(raw) && /^[a-zA-Z0-9]$/ := raw[j]) j += 1;
      names += [raw[i + 1 .. j]];
      i = j;
    } else {
      i += 1;
    }
  }
  return names;
}

void collect(current: (Expression) `<Invocation inv>`, Collector c) {
  collect(inv, c);
  c.fact(current, inv);
}

void collect(current: (Expression) `( <Expression e> )`, Collector c) {
  collect(e, c);
  c.fact(current, e);
}

// Un bloque como expresion vale lo que su ultima sentencia
void collect(current: (Expression) `<Block b>`, Collector c) {
  collect(b, c);
  c.fact(current, b);
}

// print/println valen el texto impreso
void collect(current: (Expression) `print ( <Expression? e> )`, Collector c) {
  for (Tree t <- optParts(e)) collect(t, c);
  c.fact(current, stringType());
}

void collect(current: (Expression) `println ( <Expression? e> )`, Collector c) {
  for (Tree t <- optParts(e)) collect(t, c);
  c.fact(current, stringType());
}

// if como expresion su valor (y tipo) es el de la rama elegida
void collect(current: (Expression) `if <Expression cond> then <Expression thenB> else <Expression elseB>`, Collector c) {
  collect(cond, c);
  c.requireEqual(cond, boolType(),
    error(cond, "La condicion del if debe ser Boolean, se encontro %t", cond));
  collect(thenB, c);
  collect(elseB, c);
  c.calculate("if", current, [thenB, elseB], AType(Solver s) {
    AType tt = s.getType(thenB);
    AType te = s.getType(elseB);
    if (isSub(te, tt)) return tt;
    if (isSub(tt, te)) return te;
    return unitType();   // ramas de tipos distintos: el if no produce un valor
  });
}

void collect(current: (Expression) `new <Id cls> <TypeArgs? targs> <CallArgs? cargs> <ObjectBody? body>`, Collector c) {

  c.use(cls, {objectId()});
  list[Tree] targList = [t | Tree ta <- optParts(targs), t <- typeArgList(ta)];
  list[Tree] args = [e | [CallArgs ca] := optParts(cargs), (CallArgs) `( <{Expression ","}* es> )` := ca, e <- es];
  for (t <- targList) collect(t, c);
  for (a <- args) collect(a, c);
  for (Tree b <- optParts(body)) collect(b, c);

  c.calculate("new", current, [cls] + targList + args, AType(Solver s) {
    if (objectType(str n, list[AType] formals) := s.getType(cls)) {
      if (targList != [] && size(targList) != size(formals)) {
        s.report(error(current, "`<n>` espera <size(formals)> argumento(s) de tipo, se dieron <size(targList)>"));
      }
      list[AType] actuals = [s.getType(t) | t <- targList];
      // Verificacion de los argumentos del constructor: si el objeto no
      // declara parametros, se usan los del padre mas cercano que los declare.
      str owner = n;
      while (owner in ctorParams && ctorParams[owner] == [] && owner in parents) owner = parents[owner];
      list[Tree] ptrees = (owner in ctorParams) ? ctorParams[owner] : [];
      if (ptrees != [] || args != []) {
        if (size(ptrees) != size(args)) {
          s.report(error(current, "El constructor de `<n>` espera <size(ptrees)> argumento(s), se dieron <size(args)>"));
        }
      }
      
      map[str, AType] bound = ();
      if (actuals != []) {
        bound = (v : actuals[j] | j <- index(formals), j < size(actuals), typeVar(str v) := formals[j]);
      } else if (formals != [] && size(ptrees) == size(args)) {
        for (i <- index(args)) bound = bindTypeVars(s.getType(ptrees[i]), s.getType(args[i]), bound);
        inferred = [bound[v] | typeVar(str v) <- formals, v in bound];
        if (size(inferred) == size(formals)) actuals = inferred;
      }
      for (i <- index(args), i < size(ptrees)) {
        AType formal = visit (s.getType(ptrees[i])) { case typeVar(str v) => bound[v] when v in bound };
        // Un parametro de tipo que no se pudo instanciar no se puede verificar
        if (/typeVar(_) := formal) continue;
        s.requireSubType(args[i], formal,
          error(args[i], "El argumento <i + 1> de `new <n>` debe ser %t, se encontro %t", formal, args[i]));
      }
      return objectType(n, actuals);
    }
    s.report(error(current, "`<cls>` no es un objeto"));
    return unitType();
  });
}

// Empareja el tipo declarado de un parametro (que puede contener variables
// de tipo) con el tipo del argumento y acumula las variables que quedan
// determinadas
private map[str, AType] bindTypeVars(AType formal, AType actual, map[str, AType] b) {
  switch (formal) {
    case typeVar(str v):
      if (v notin b) b[v] = actual;
    case objectType(str n, list[AType] fs):
      if (objectType(n, list[AType] as) := actual, size(fs) == size(as)) {
        for (i <- index(fs)) b = bindTypeVars(fs[i], as[i], b);
      }
    case methodType(list[AType] fs, AType r):
      if (methodType(list[AType] as, AType ar) := actual, size(fs) == size(as)) {
        for (i <- index(fs)) b = bindTypeVars(fs[i], as[i], b);
        b = bindTypeVars(r, ar, b);
      }
    default: ;
  }
  return b;
}

void collect(current: (Expression) `- <Expression e>`, Collector c) {
  collect(e, c);
  c.calculate("negacion", current, [e], AType(Solver s) {
    t = s.getType(e);
    if (!isNumeric(t)) s.report(error(current, "`-` requiere un numero, se encontro %t", e));
    return t;
  });
}

void collect(current: (Expression) `neg <Expression e>`, Collector c) {
  collect(e, c);
  c.requireEqual(e, boolType(), error(current, "`neg` requiere Boolean, se encontro %t", e));
  c.fact(current, boolType());
}

void collect(current: (Expression) `<Expression l> ** <Expression r>`, Collector c) = arith(current, "**", l, r, c);
void collect(current: (Expression) `<Expression l> * <Expression r>`, Collector c)  = arith(current, "*", l, r, c);
void collect(current: (Expression) `<Expression l> / <Expression r>`, Collector c)  = arith(current, "/", l, r, c);
void collect(current: (Expression) `<Expression l> % <Expression r>`, Collector c)  = arith(current, "%", l, r, c);
void collect(current: (Expression) `<Expression l> - <Expression r>`, Collector c)  = arith(current, "-", l, r, c);

void collect(current: (Expression) `<Expression l> + <Expression r>`, Collector c) {
  collect(l, c);
  collect(r, c);
  c.calculate("suma", current, [l, r], AType(Solver s) {
    tl = s.getType(l);
    tr = s.getType(r);
    if (tl == stringType() || tr == stringType()) return stringType();  // concatenacion
    if (isNumeric(tl) && isNumeric(tr)) return (tl == floatType() || tr == floatType()) ? floatType() : intType();
    s.report(error(current, "`+` requiere numeros o String, se encontro %t y %t", l, r));
    return intType();
  });
}

private void arith(Expression current, str op, Expression l, Expression r, Collector c) {
  collect(l, c);
  collect(r, c);
  c.calculate("aritmetica", current, [l, r], AType(Solver s) {
    tl = s.getType(l);
    tr = s.getType(r);
    if (isNumeric(tl) && isNumeric(tr)) return (tl == floatType() || tr == floatType()) ? floatType() : intType();
    s.report(error(current, "`<op>` requiere numeros, se encontro %t y %t", l, r));
    return intType();
  });
}

void collect(current: (Expression) `<Expression l> \< <Expression r>`, Collector c)  = comparison(current, "\<", l, r, c);
void collect(current: (Expression) `<Expression l> \> <Expression r>`, Collector c)  = comparison(current, "\>", l, r, c);
void collect(current: (Expression) `<Expression l> \<= <Expression r>`, Collector c) = comparison(current, "\<=", l, r, c);
void collect(current: (Expression) `<Expression l> \>= <Expression r>`, Collector c) = comparison(current, "\>=", l, r, c);

private void comparison(Expression current, str op, Expression l, Expression r, Collector c) {
  collect(l, c);
  collect(r, c);
  c.require("comparacion", current, [l, r], void(Solver s) {
    tl = s.getType(l);
    tr = s.getType(r);
    if (!((isNumeric(tl) && isNumeric(tr)) || (tl == tr && tl in {stringType(), charType()}))) {
      s.report(error(current, "`<op>` requiere operandos comparables, se encontro %t y %t", l, r));
    }
  });
  c.fact(current, boolType());
}

void collect(current: (Expression) `<Expression l> = <Expression r>`, Collector c)   = equality(current, "=", l, r, c);
void collect(current: (Expression) `<Expression l> \<\> <Expression r>`, Collector c) = equality(current, "\<\>", l, r, c);

private void equality(Expression current, str op, Expression l, Expression r, Collector c) {
  collect(l, c);
  collect(r, c);
  c.requireComparable(l, r, error(current, "`<op>` requiere operandos del mismo tipo, se encontro %t y %t", l, r));
  c.fact(current, boolType());
}

void collect(current: (Expression) `<Expression l> and <Expression r>`, Collector c) = logical(current, "and", l, r, c);
void collect(current: (Expression) `<Expression l> or <Expression r>`, Collector c)  = logical(current, "or", l, r, c);

private void logical(Expression current, str op, Expression l, Expression r, Collector c) {
  collect(l, c);
  collect(r, c);
  c.requireEqual(l, boolType(), error(l, "`<op>` requiere Boolean, se encontro %t", l));
  c.requireEqual(r, boolType(), error(r, "`<op>` requiere Boolean, se encontro %t", r));
  c.fact(current, boolType());
}
