# Objectilang – Proyecto 3 (Grupo 13)

Proyecto Rascal con la sintaxis concreta, la sintaxis abstracta (AST), el
verificador de tipos (TypePal) y el interprete de Objectilang.

## Estructura

```
objectilang/
├── pom.xml                         (dependencias: rascal, rascal-lsp, typepal)
├── META-INF/RASCAL.MF
├── Docs/                           (documentos de cada entrega)
├── examples/
│   ├── ejemplo1.obj                programa de prueba de la entrega 2 (solo sintaxis)
│   ├── ejemplo2.ol                 programa bien tipado que se ejecuta
│   ├── error_tipos.ol              programa con errores de tipos
│   ├── error_objeto.ol             programa que viola la regla "los elementos de un objeto deben existir"
│   └── snippet1.ol .. snippet4.ol  los fragmentos de codigo del enunciado (los cuatro se ejecutan)
└── src/lang/objectilang/
    ├── Syntax.rsc                  gramatica concreta + categorias de resaltado
    ├── AST.rsc                     sintaxis abstracta
    ├── Implode.rsc                 parseObjectilang(...) y loadAST(...)
    ├── Checker.rsc                 tipos y verificador con TypePal
    ├── Eval.rsc                    interprete (ejecuta el AST)
    ├── Main.rsc                    run(archivo .ol): parsea, verifica y ejecuta
    ├── Plugin.rsc                  registro del lenguaje en VS Code (*.ol, *.obj) con errores de tipos
    └── Tests.rsc                   pruebas (parseo, AST, tipos)
```

## Como usarlo

1. Abrir la carpeta `objectilang` en VS Code con la extension **Rascal MPL**
   (descarga sola las dependencias del `pom.xml`, incluida TypePal).
2. En el terminal de Rascal:
   ```
   import lang::objectilang::Plugin;
   main();                          // registra el lenguaje: *.ol con resaltado y errores de tipos

   import lang::objectilang::Main;
   run(|project://objectilang/examples/ejemplo2.ol|);      // ejecuta y muestra la salida en consola
   run(|project://objectilang/examples/error_tipos.ol|);   // muestra los errores de tipos
   run(|project://objectilang/examples/error_objeto.ol|);  // muestra las violaciones de la regla nueva
   run(|project://objectilang/examples/snippet3.ol|);      // fragmentos del enunciado (snippet1 .. snippet4)

   import lang::objectilang::Tests;
   :test
   ```
3. Tambien se puede ejecutar desde la linea de comandos (con `rascal` y `typepal` en el classpath):
   ```
   java -cp "rascal-0.43.0.jar;typepal-0.17.4.jar" org.rascalmpl.shell.RascalShell lang::objectilang::Main --file examples/ejemplo2.ol
   ```
