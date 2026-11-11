//Programa con errores de objeto

object Dog extends Animal              // Animal no esta definido

object Box(content: Thing)             // el tipo Thing no existe

object Pair[A](first: A, second: B)    // B no es un parametro de tipo declarado

object Counter(start: Int) {
  method increment(step: Int): Int = { start + step }
}

val c = new Counter(1)
println(c.total)                       // Counter no tiene un campo total
println(c.decrement(1))                // Counter no tiene un metodo decrement
c.reset = method(): Int { 0 }          // no se puede asignar un metodo que no existe
val p = new Person("ana")              // Person no esta definido
