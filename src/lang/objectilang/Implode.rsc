module lang::objectilang::Implode

/*
 * Parser y conversion del arbol de sintaxis concreta (CST) al AST.
 */
 
import ParseTree;
import List;
import Set;
import lang::objectilang::Syntax;
import lang::objectilang::AST;

public start[Program] parseObjectilang(str text) =
  disambiguate(parse(#start[Program], text, allowAmbiguity=true));

public start[Program] parseObjectilang(str text, loc origin) =
  disambiguate(parse(#start[Program], text, origin, allowAmbiguity=true));

public start[Program] parseObjectilang(loc file) =
  disambiguate(parse(#start[Program], file, allowAmbiguity=true));

/*
 * Las sentencias no llevan separador, asi que `val x = 1 - 2` tambien se
 * puede leer como `val x = 1` seguida de la sentencia `-2`. Cuando una lista
 * de sentencias tiene varias lecturas, se elige la que tiene menos sentencias
 * (la expresion mas larga): `val x = 1 - 2` es una resta.
 * Si queda mas de una lectura, se deja la ambiguedad para que se reporte.
 */
private start[Program] disambiguate(start[Program] t) = visit(t) {
  case amb(set[Tree] alts) => fewestStatements(alts)
};

private Tree fewestStatements(set[Tree] alts) {
  if (!all(a <- alts, appl(regular(_), _) := a)) return amb(alts);
  int least = min({size(a.args) | a <- alts});
  set[Tree] best = {a | a <- alts, size(a.args) == least};
  return size(best) == 1 ? getOneFrom(best) : amb(best);
}

public AProgram loadAST(start[Program] tree) = implode(#AProgram, tree.top);

public AProgram loadAST(str text) = loadAST(parseObjectilang(text));

public AProgram loadAST(loc file) = loadAST(parseObjectilang(file));
