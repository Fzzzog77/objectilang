// Programa con errores de tipos

object Counter(start: Int) {
  method increment(step: Int): Int = { start + step }
}

val a: Int = "no soy un entero"        // String donde se espera Int
val b: Boolean = 1 + 2                 // Int donde se espera Boolean
val c: Char = "x"                      // String donde se espera Char
val d: String = 'x'                    // Char donde se espera String

if a then println("si") else println("no")   // la condicion no es Boolean

val k = new Counter(5)
val k2 = new Counter("cinco")          // argumento del constructor de tipo incorrecto
val r: String = k.increment(1)         // el metodo retorna Int, no String
val s = k.increment(true)              // argumento de tipo incorrecto
val t = 1 + true                       // operandos incompatibles
