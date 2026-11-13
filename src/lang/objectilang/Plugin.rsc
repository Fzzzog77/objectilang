module lang::objectilang::Plugin

/*
 * Registro del lenguaje en VS Code (extension Rascal).
 * Con esto los archivos *.ol (y *.obj) se abren con resaltado de sintaxis,
 * muestran los errores de parseo y los errores de tipos (TypePal).
 *
 * En el terminal de Rascal:
 *   import lang::objectilang::Plugin;
 *   main();
 */

import ParseTree;
import util::Reflective;
import util::LanguageServer;
import lang::objectilang::Syntax;
import lang::objectilang::Checker;
import lang::objectilang::Implode;

private str LANG_NAME = "Objectilang";
private set[str] LANG_EXTS = {"ol", "obj"};

private Tree (str _input, loc _origin) objectilangParser() {
  // mismo parser que run(): resuelve la ambiguedad de `val x = 1 - 2`
  return Tree (str input, loc origin) { return parseObjectilang(input, origin); };
}

// Verificacion de tipos: los mensajes de TypePal se muestran en el editor
private Summary objectilangAnalysis(loc origin, Tree input) {
  if (start[Program] pt := input) {
    return summary(origin, messages = {<m.at, m> | m <- checkTypes(pt)});
  }
  return summary(origin);
}

set[LanguageService] objectilangLanguageServer() = {
  parsing(objectilangParser(), usesSpecialCaseHighlighting = false),
  analysis(objectilangAnalysis)
};

void main() {
  PathConfig pcfg =
    getProjectPathConfig(|project://objectilang|, mode=interpreter_external());

  registerLanguage(
    language(pcfg, LANG_NAME, LANG_EXTS,
             "lang::objectilang::Plugin", "objectilangLanguageServer")
  );
}
