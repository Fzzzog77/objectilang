# Cambios al proyecto – Objectilang, Proyecto 3

ISIS-2111 PLE – Proyecto 3 – Grupo 13
Juan Manuel Forero Bohórquez (202514666) – Fergye Zhamyra Ortiz Gómez (202426021)

**Base utilizada:** nuestra propia solución del Proyecto 2 (Grupo 13). No se usó la solución de otro grupo.
Se modificó lo mínimo necesario: la gramática y el AST de la entrega 2 se conservan; se agregó el literal de caracteres, se añadieron módulos nuevos y, en una segunda ronda (sección 5), se ajustó la gramática para aceptar todos los fragmentos de código del enunciado.

## 1. Qué se agregó por cada punto del enunciado

| Punto | Qué pedía | Qué se hizo | Dónde |
|---|---|---|---|
| 1 | Parser | Se reutiliza `parseObjectilang` de la entrega 2 (gramática `Syntax.rsc`). | `Implode.rsc` |
| 2 | Ejecutar programas `.ol` y mostrar el resultado en consola | Se escribió un **intérprete** sobre el AST (`Eval.rsc`) y un punto de entrada `run(archivo)` que parsea, verifica tipos y ejecuta. `print`/`println` escriben en la consola de Rascal. La extensión `.ol` se registró en el plugin (se mantiene `.obj`). | `Eval.rsc`, `Main.rsc`, `Plugin.rsc` |
| 3 | Instalar TypePal | Dependencia `org.rascalmpl:typepal:0.17.4` en `pom.xml` (compatible con Rascal 0.43.0) y `Require-Libraries: \|lib://typepal\|` en `RASCAL.MF`. | `pom.xml`, `META-INF/RASCAL.MF` |
| 4 | Anotaciones de tipo para Int, Boolean, Char, String; tipo genérico en objetos | La gramática ya tenía `val x: T`, parámetros `x: T` y retornos `: T`, y objetos genéricos `object List[+A](val item: A)`. Faltaba **Char**: se agregó el literal `'a'` (`CharLit`) a `Syntax.rsc` y `charLit(str)` al AST. Los tipos básicos son `Int`, `Float`, `Boolean`, `Char`, `String`. | `Syntax.rsc`, `AST.rsc` |
| 5 | Verificar que los tipos usados corresponden a las definiciones | Verificador con TypePal (`Checker.rsc`): declaraciones `val/var` con anotación, condiciones de `if`/`for`, operadores, argumentos y retorno de métodos, argumentos del constructor en `new`, herencia (`extends`) como subtipo y genéricos con varianza (`List[Dog] <: List[+A]` con `Animal`). | `Checker.rsc` |
| 6 | Regla nueva: todos los elementos usados en un objeto deben existir | En `Checker.rsc`: el padre de `extends`, los tipos de los parámetros, los parámetros de tipo, el objeto de `new X`, y cada campo/método accedido con `obj.x` u `obj.m(...)` (incluido `obj.m = method ...`) deben estar definidos; si no, se reporta error. | `Checker.rsc` |

## 2. Archivos nuevos y modificados

| Archivo | Estado | Resumen |
|---|---|---|
| `src/lang/objectilang/Syntax.rsc` | modificado | +`CharChar`/`CharLit` (literal `'a'`, `'\n'`) y alternativa `charLit` en `Expression`. Además los cambios de la sección 5: `if` como expresión, bloque y `print` como expresiones, `Obj.m = method(...)` sin cuerpo e interpolación `$nombre`. |
| `src/lang/objectilang/AST.rsc` | modificado | +`charLit(str c)` en `AExpression`; +`ifExpr`, `blockExpr`, `printExpr`, `printlnExpr`, `methodDecl` (sección 5). |
| `src/lang/objectilang/Checker.rsc` | nuevo | Tipos (`intType`, `boolType`, `charType`, `stringType`, `floatType`, `objectType(nombre, args)`, `typeVar`, `methodType`), reglas `collect` de TypePal, subtipos y configuración. Funciones: `checkTypes(loc)`, `wellTyped(str)`. |
| `src/lang/objectilang/Eval.rsc` | nuevo | Intérprete: valores, instancias de objetos (campos + métodos, herencia, `override`, `obj.m = method`), expresiones, interpolación de cadenas, `if`, los tres `for`, `print/println`. Si existe `method main` de nivel superior se invoca al final. |
| `src/lang/objectilang/Main.rsc` | nuevo | `run(loc)`: parsea → `checkTypes` → si no hay errores `evalProgram`. Imprime los errores de tipo en consola. |
| `src/lang/objectilang/Plugin.rsc` | modificado | Registra `*.ol` además de `*.obj` y agrega el servicio `analysis` para mostrar los errores de TypePal en el editor. |
| `src/lang/objectilang/Tests.rsc` | modificado | +22 pruebas de tipos (aceptación y rechazo) y de la regla nueva, +17 de los fragmentos del enunciado. Total 61 pruebas, todas pasan. |
| `pom.xml`, `META-INF/RASCAL.MF` | modificados | Dependencia TypePal. |
| `examples/ejemplo2.ol` | nuevo | Programa bien tipado que ejercita todo (salida esperada abajo). |
| `examples/error_tipos.ol` | nuevo | 9 errores de tipos detectados. |
| `examples/error_objeto.ol` | nuevo | 7 violaciones de la regla nueva detectadas. |
| `examples/ejemplo1.obj` | sin cambios | Programa de la entrega 2; solo muestra sintaxis, no está bien tipado (usa variables sin declarar). |
| `examples/snippet1.ol` … `snippet4.ol` | nuevos | Los cuatro fragmentos de código del enunciado, tal cual (ver sección 5). Los cuatro se ejecutan. |

## 3. Decisiones de diseño (para que todo funcionara)

- **Ámbitos en TypePal:** cada `object` es un ámbito; sus parámetros y los `val/var/method` del cuerpo son sus miembros. `extends` se modela con un camino `extendPath()` hacia el padre, de modo que los miembros heredados se encuentran. Con `override`, la definición del hijo oculta la del padre (`isAcceptablePath`).
- **Genéricos:** `object List[+A]` define el tipo `List[A]`; al acceder a `lista.item` el verificador busca `item` en el ámbito del objeto (y sus padres) y sustituye `A` por el argumento real del contenedor (función `memberAccess` en `Checker.rsc`). La varianza `+`/`-` declarada se respeta al comparar `List[Dog]` con `List[Animal]`. Un tipo sin argumentos (`new List(...)`) se acepta como "crudo".
- **Constructores:** si un objeto no declara parámetros, `new` usa (y verifica) los del padre más cercano que los declare; el intérprete hace lo mismo.
- **Valor de un bloque/método:** el de su última expresión; si termina en otra sentencia es `Unit`.
- **`for (x <- v)` / `for ((k, v) in o)`:** el lenguaje no tiene listas, así que recorrer un objeto recorre sus campos (valor, o nombre y valor) y recorrer un `String` recorre sus caracteres.
- `+` concatena si alguno de los operandos es `String`; `Int` es subtipo de `Float`.

## 4. Cómo probar

```
import lang::objectilang::Main;
run(|project://objectilang/examples/ejemplo2.ol|);
run(|project://objectilang/examples/error_tipos.ol|);
run(|project://objectilang/examples/error_objeto.ol|);
import lang::objectilang::Tests;
:test
```

Los fragmentos del enunciado:

```
run(|project://objectilang/examples/snippet1.ol|);   // Print the line of animal dogs: Dog()
run(|project://objectilang/examples/snippet2.ol|);   // Cats meows
run(|project://objectilang/examples/snippet3.ol|);   //  Preparing specialized food for an animal ...
                                                     //  Resulting food type : DogFood
run(|project://objectilang/examples/snippet4.ol|);   //  Movie : Inception , Rating : 9  Movie : Matrix , Rating : 8  Movie : Alien , Rating : 7
```

Salida de `ejemplo2.ol`:

```
entero = 7, real = 12.56, letra = a, texto = hola, ok = true
positivo
i = 0
i = 1
i = 2
Counter: 7
14
3
Firulais dice Guau
Michi dice Hola
start -> 5
count -> 5
Print the line of animal dogs: Rex dice Guau
```

## 5. Fragmentos de código del enunciado (`examples/snippet1.ol` … `snippet4.ol`)

Se tomaron los cuatro fragmentos del enunciado como programas de prueba. La regla fue: el fragmento se deja tal cual; si no parseaba por una construcción del lenguaje que faltaba, se amplió la gramática; si no pasaba el verificador, se corrigió el verificador; solo se tocó el fragmento cuando le faltaba lógica (nombres que no existen).

| Fragmento | Qué le faltaba al proyecto | Qué se hizo |
|---|---|---|
| 1. `List[+A]` con `new List(new Dog)` | `new` sin argumentos de tipo explícitos comparaba `Dog` con la variable de tipo `A` sin instanciar. | **Inferencia de argumentos de tipo** en `new`: se deducen de los argumentos del constructor (`new List(new Dog)` tiene tipo `List[Dog]`). `Checker.rsc`, función `bindTypeVars`. |
| 2. `Cat.talk = method() : String { print(...) }` | `Obj.m = method ...` solo funcionaba sobre variables y exigía que `m` ya existiera. `print` era una sentencia de tipo `Unit`, incompatible con `: String`. | **Métodos agregados a un objeto**: si el lado izquierdo es un objeto, el método se agrega a ese objeto (y lo heredan sus hijos y todas sus instancias); si ya existía, el nuevo debe ser compatible. **`print`/`println` son expresiones** cuyo valor es el texto impreso (`String`). |
| 3. `Transformer[-In, +Out]`, `Transformer.transform = method(input: In): Out` sin cuerpo, `getClass`, `resultantFood.getSimpleName` sin paréntesis | No existía la declaración de método sin cuerpo, ni `getClass`, ni el uso de un método sin paréntesis. En el fragmento el objeto se llama `Transformer` pero la declaración decía `Transform` (error de lógica del enunciado). | Gramática: `methodDecl` (método abstracto). `getClass` es un nombre predefinido de tipo `String` con el nombre del objeto actual. Un método sin parámetros se puede usar sin paréntesis (acceso uniforme, como en Scala). Se corrigió `Transform` → `Transformer` en el snippet. |
| 4. `val max = if a > b then a else b` y `"Movie : $name"` | El `if` era una sentencia (no valía como expresión) y la interpolación solo admitía `${...}`. `a`, `b` y `ratings` no estaban declarados. | **`if` es una expresión** (ver abajo). **Interpolación corta `$nombre`** en cadenas (el verificador exige que la variable exista). En el snippet se agregaron `val a`, `val b` y un objeto `Ratings` cuyos campos son las películas, que es lo que recorre `for ((name, rating) <- ratings)`. |

### `if` como expresión y bloques como expresiones

Para que `val max = if a > b then a else b` funcione, `if ... then ... else ...` pasó de `Statement` a `Expression` (`ifExpr`), con la prioridad más baja de todas: `if c then a else b + 1` se lee `if c then a else (b + 1)`. Sus ramas son expresiones, así que para conservar `if c then { ... } else { ... }` y `if c then println(..) else println(..)`:

- un **bloque `{ ... }` es una expresión** (`blockExpr`) cuyo valor es el de su última sentencia (igual que el cuerpo de un método);
- **`print`/`println` son expresiones** de tipo `String`.

El cuerpo de los `for` es ahora un `Statement` (un bloque entra como expresión), por lo que desapareció el no-terminal `Body` y el constructor `ifStmt`.

Las restricciones `!>> "{"` en `object ...`, `new ...` y `Obj.m = method(...)` evitan que una llave que sigue se lea como un bloque aparte en vez del cuerpo.

### Decisiones

- Un método asignado a un objeto (`Cat.talk = ...`) está disponible en todas las instancias (incluso las ya creadas) y en los objetos hijos; una asignación sobre una instancia (`c.inc = ...`) sigue afectando solo a esa instancia.
- Un método declarado sin cuerpo es abstracto: llamarlo sin haberlo sobreescrito es un error de ejecución.
- `print` no agrega salto de línea; por eso la salida de los snippets 2, 3 y 4 termina sin él.

