module lang::objectilang::Main

/*
 * Punto de entrada: ejecuta un programa Objectilang (.ol).
 *
 *   1. parsea el archivo,
 *   2. verifica los tipos con TypePal (Checker),
 *   3. si no hay errores, evalua el programa (Eval) y muestra la salida
 *      en la consola.
 */

import IO;
import List;
import Message;
import Exception;
import ParseTree;
import lang::objectilang::Syntax;
import lang::objectilang::Implode;
import lang::objectilang::Checker;
import lang::objectilang::Eval;

// Parsea, verifica y ejecuta el archivo; los errores se muestran en consola.
void run(loc file) {
  start[Program] pt;
  try {
    pt = parseObjectilang(file);
  } catch ParseError(loc l): {
    println("Error de sintaxis en <l>");
    return;
  }

  msgs = checkTypes(pt);
  for (m <- msgs) println(format(m));
  errors = [m | m:error(_, _) <- msgs];
  if (errors != []) {
    println("No se ejecuta el programa: <size(errors)> error(es) de tipos.");
    return;
  }

  evalProgram(loadAST(pt));
}

void run(str text) = run(writeTemp(text));

private loc writeTemp(str text) {
  loc f = |tmp:///objectilang_run.ol|;
  writeFile(f, text);
  return f;
}

private str format(error(str msg, loc at))   = "[error] <at.path>:<at.begin.line>: <msg>";
private str format(warning(str msg, loc at)) = "[warning] <at.path>:<at.begin.line>: <msg>";
private str format(info(str msg, loc at))    = "[info] <at.path>:<at.begin.line>: <msg>";

void main(str file = "examples/ejemplo2.ol") = run(|cwd:///| + file);
