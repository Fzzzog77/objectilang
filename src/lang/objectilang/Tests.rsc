module lang::objectilang::Tests

import ParseTree;
import Exception;
import lang::objectilang::AST;
import lang::objectilang::Implode;
import lang::objectilang::Checker;

bool parses(str src) {
  try {
    parseObjectilang(src);
    return true;
  } catch ParseError(_): {
    return false;
  }
}

test bool tVal() = parses("val x: Int = 1 + 2 * 3");

test bool tVar() = parses("var y = 2.5");

test bool tNegativoEnDeclaracion() = parses("val x = -2");

test bool tNegativoComoExpresion() =
  parses("method f(): Int = { -2 }");

test bool tObject() =
  parses("object A extends B [+T, -U] (x: Int, y: String) { val z = x }");

test bool tParametroValObjeto() =
  parses("object List [+A](val item : A)");

test bool tObjectSinCuerpo() = parses("object A");

test bool tMetodoSinIgual() =
  parses("method main { val x = 1 }");

test bool tImplodeMetodoSinIgual() =
  program([methodStmt(methodDef(["main"], [], [],
    block([valDecl("x", [], intLit(1))])))]) :=
      loadAST("method main { val x = 1 }");

test bool tMetodos() =
  parses("method f(x: Int): Int = { x + 1 }\noverride g = { 1 }");

test bool tMetodoAsignado() =
  parses("c.inc = method(step: Int): Int { step + 1 }");

test bool tMetodoAsignadoSinTipo() =
  parses("c.inc = method(step: Int) { step + 1 }");

test bool tIf() =
  parses("if a = b then println(\"si\") else println(\"no\")");

test bool tForRango() = parses("for (i = 0, i \< 10, i++) println(i)");

test bool tForEach() = parses("for (x \<- xs) println(x)");

test bool tForTupla() = parses("for ((k, v) in pairs) { println(k) }");

test bool tNew() =
  parses("val o = new A[Int](1, 2) { method m(): Int = { 1 } }");

test bool tInterpolacion() =
  parses("println(\"a ${x} b ${y.z(1)} c\")");

test bool tComentarios() =
  parses("// linea\nval a = 1 /* bloque */ val b = 2");

test bool tRechazaValSinNombre() = !parses("val = 3");

test bool tRechazaReservada() = !parses("val if = 3");

test bool tPrecedencia() =
  program([valDecl("x", [],
    add(intLit(1), multiply(intLit(2), intLit(3))))]) :=
      loadAST("val x = 1 + 2 * 3");

test bool tAsociatividadIzquierda() =
  program([valDecl("x", [],
    subtract(subtract(intLit(1), intLit(2)), intLit(3)))]) :=
      loadAST("val x = (1 - 2 - 3)");

// ---------------------------------------------------------------------------
// Proyecto 3: tipos (Checker) y ejecucion (Eval)
// ---------------------------------------------------------------------------

test bool tCharLit() = parses("val c: Char = \'a\'");

test bool tCharEscapado() =
  program([valDecl("c", [typeAnn(simpleType("Char"))], charLit("\'\\n\'"))]) :=
    loadAST("val c: Char = \'\\n\'");

test bool tTiposBasicosOk() =
  wellTyped("val a: Int = 1 val b: Boolean = true val c: Char = \'x\' val d: String = \"s\" val e: Float = 1.5");

test bool tTipoIncorrecto() = !wellTyped("val a: Int = \"texto\"");

test bool tBooleanIncorrecto() = !wellTyped("val b: Boolean = 1");

test bool tCondicionIf() = !wellTyped("if 1 then println(1) else println(2)");

test bool tSumaStringOk() = wellTyped("val s: String = \"a\" + 1");

test bool tAritmeticaIncorrecta() = !wellTyped("val x = 1 * true");

test bool tObjetoYMetodoOk() =
  wellTyped("object Counter(start: Int) { method inc(step: Int): Int = { start + step } }
            'val c: Counter = new Counter(1)
            'val r: Int = c.inc(2)");

test bool tRetornoIncorrecto() =
  !wellTyped("object A { method f(): String = { 1 } }");

test bool tArgumentoIncorrecto() =
  !wellTyped("object Counter(start: Int) { method inc(step: Int): Int = { start + step } }
             'val c = new Counter(1)
             'val r = c.inc(\"dos\")");

test bool tConstructorIncorrecto() =
  !wellTyped("object Counter(start: Int) val c = new Counter(\"uno\")");

test bool tGenericosCovarianza() =
  wellTyped("object Animal object Dog extends Animal object List[+A](val item: A)
            'val ld: List[Dog] = new List[Dog](new Dog)
            'val la: List[Animal] = ld
            'val a: Animal = la.item");

test bool tGenericosSinCovarianza() =
  !wellTyped("object Animal object Dog extends Animal object List[A](val item: A)
             'val ld: List[Dog] = new List[Dog](new Dog)
             'val la: List[Animal] = ld");

// Sin argumentos de tipo explicitos, `new` los infiere de los argumentos del
// constructor (programa de ejemplo del enunciado del proyecto 1).
test bool tGenericosInferidos() =
  wellTyped("object Animal object Dog extends Animal object Cat extends Animal
            'object List[+Animal](val item: Animal)
            'method main {
            '  val listOfDogs: List[Dog] = new List(new Dog)
            '  val listOfAnimals: List[Animal] = listOfDogs
            '  print(\"Print the line of animal dogs: ${listOfAnimals.item}\")
            '}");

test bool tGenericosInferidosIncorrecto() =
  !wellTyped("object Animal object Dog extends Animal object List[+A](val item: A)
             'val ld: List[Dog] = new List(new Animal)");

// ---------------------------------------------------------------------------
// Fragmentos del enunciado (examples/snippet*.ol)
// ---------------------------------------------------------------------------

// snippet2: Cat.talk = method ... agrega el metodo al objeto; print vale String
test bool tMetodoAgregadoAObjeto() =
  wellTyped("object Animal object Cat
            'Cat.talk = method() : String { print(\"Cats meows\") }
            'method main { val cat = new Cat cat.talk() }");

test bool tMetodoAgregadoIncompatible() =
  !wellTyped("object Counter(start: Int) { method inc(step: Int): Int = { start + step } }
             'Counter.inc = method(step: String): Int { 1 }");

// snippet3: metodo abstracto, varianza -In/+Out, getClass y metodo sin parentesis
test bool tMetodoAbstractoYVarianza() =
  wellTyped("object Animal object Dog extends Animal object Puppy extends Dog
            'object Food object DogFood extends Food
            'Food.getSimpleName = method() : String { \"${getClass}\" }
            'object Transformer [-In, +Out]
            'Transformer.transform = method(input: In): Out
            'method main {
            '  val animalFeeder: Transformer[Animal, DogFood] = new Transformer[Animal, DogFood] {
            '    override transform(animal: Animal): DogFood = { new DogFood }
            '  }
            '  val puppyFeeder: Transformer[Puppy, Food] = animalFeeder
            '  val resultantFood: Food = puppyFeeder.transform(new Puppy)
            '  print(\"Resulting food type: ${resultantFood.getSimpleName}\")
            '}");

test bool tContravarianzaIncorrecta() =
  !wellTyped("object Animal object Dog extends Animal object Food
             'object Transformer [-In, +Out]
             'Transformer.transform = method(input: In): Out
             'val dogFeeder: Transformer[Dog, Food] = new Transformer[Dog, Food] {
             '  override transform(d: Dog): Food = { new Food }
             '}
             'val animalFeeder: Transformer[Animal, Food] = dogFeeder");

test bool tMetodoSinParentesis() =
  wellTyped("object A { method name(): String = { \"a\" } } val a = new A val s: String = a.name");

// snippet4: if como expresion e interpolacion corta $nombre
test bool tIfExpresion() =
  program([valDecl("a", [], intLit(1)), valDecl("b", [], intLit(2)),
           valDecl("max", [],
             ifExpr(greaterThan(callExpr(invocation(["a"], [], [])), callExpr(invocation(["b"], [], []))),
                    callExpr(invocation(["a"], [], [])),
                    callExpr(invocation(["b"], [], []))))]) :=
    loadAST("val a = 1 val b = 2 val max = if a \> b then a else b");

test bool tIfExpresionTipo() =
  wellTyped("val a = 1 val b = 2 val max: Int = if a \> b then a else b");

test bool tIfExpresionTipoIncorrecto() = !wellTyped("val max: String = if true then 1 else 2");

test bool tIfExpresionPrecedencia() =
  program([valDecl("x", [], ifExpr(trueLit(), intLit(1), add(intLit(2), intLit(3))))]) :=
    loadAST("val x = if true then 1 else 2 + 3");

test bool tIfExpresionComoOperando() =
  program([valDecl("x", [], add(intLit(1), ifExpr(trueLit(), intLit(2), intLit(3))))]) :=
    loadAST("val x = 1 + if true then 2 else 3");

test bool tIfConBloques() =
  wellTyped("val x: Int = if true then { 1 } else { val y = 2 y + 1 }");

test bool tBloqueComoExpresion() =
  program([valDecl("x", [], blockExpr(block([valDecl("y", [], intLit(1)),
                                             exprStmt(add(callExpr(invocation(["y"], [], [])), intLit(1)))])))]) :=
    loadAST("val x = { val y = 1 y + 1 }");

test bool tInterpolacionCorta() =
  wellTyped("object Ratings(Inception: Int, Matrix: Int) val ratings = new Ratings(9, 8)
            'for ((name, rating) \<- ratings) print(\"Movie: $name, Rating: $rating\")");

test bool tInterpolacionCortaNoDefinida() = !wellTyped("print(\"Hola $nadie\")");

test bool tHerenciaOverride() =
  wellTyped("object Animal { method speak(): String = { \"...\" } }
            'object Dog extends Animal { override speak(): String = { \"Guau\" } }
            'val d: Dog = new Dog
            'val s: String = d.speak()");

// Regla 6: los elementos usados en una definicion de objeto deben existir
test bool tReglaPadreInexistente() = !wellTyped("object Dog extends Animal");

test bool tReglaTipoInexistente() = !wellTyped("object Box(content: Thing)");

test bool tReglaParametroDeTipoInexistente() = !wellTyped("object Pair[A](first: A, second: B)");

test bool tReglaCampoInexistente() =
  !wellTyped("object Counter(start: Int) val c = new Counter(1) println(c.total)");

test bool tReglaMetodoInexistente() =
  !wellTyped("object Counter(start: Int) val c = new Counter(1) c.reset = method(): Int { 0 }");

test bool tReglaObjetoInexistente() = !wellTyped("val p = new Person");

test bool tMiembroDeNoObjeto() = !wellTyped("val x: Int = 1 println(x.f)");

// Resta despues de una declaracion (ambiguedad reportada en el Proyecto 2)

test bool tRestaEnDeclaracion() =
  program([valDecl("x", [], subtract(intLit(1), intLit(2)))]) :=
    loadAST("val x = 1 - 2");

test bool tRestaConVariable() = wellTyped("val a = 5\nval x: Int = a - 2");

test bool tRestaEnBloque() = parses("method f(): Int = { val y = 4 - 1\n y }");

test bool tRestaEnRamaElse() =
  program([valDecl("x", [], ifExpr(trueLit(), intLit(1), subtract(intLit(2), intLit(3))))]) :=
    loadAST("val x = if true then 1 else 2 - 3");

test bool tNegativoSigueSiendoSentencia() =
  program([valDecl("x", [], intLit(1)), exprStmt(negate(intLit(2)))]) :=
    loadAST("val x = 1\n(-2)");
