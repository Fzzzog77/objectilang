// Programa bien tipado, no debería reportar errores

object Animal(name: String) {
  method speak(): String = { "..." }
  method describe(): String = { "${name} dice ${speak()}" }
}

object Dog extends Animal {
  override speak(): String = { "Guau" }
}

object Cat extends Animal {
  override speak(): String = { "Miau" }
}

object List [+A] (val item: A)

object Counter(start: Int) {
  var count: Int = start

  method increment(step: Int): Int = {
    val next: Int = count + step
    println("Counter: ${next}")
    next * 2
  }
}

val entero: Int = 1 + 2 * 3
val real: Float = 3.14 * 2 ** 2
val letra: Char = 'a'
val texto: String = "hola"
val ok: Boolean = neg false and (entero >= 0 or entero <> 5)

println("entero = ${entero}, real = ${real}, letra = ${letra}, texto = ${texto}, ok = ${ok}")

if entero > 0 then println("positivo") else println("no positivo")

for (i = 0, i < 3, i++) println("i = ${i}")

val c: Counter = new Counter(5)
println(c.increment(2))
c.increment = method(step: Int): Int { step + 1 }
println(c.increment(2))

val perro: Dog = new Dog("Firulais")
println(perro.describe())

val gatoRaro = new Cat("Michi") {
  override speak(): String = { "Hola" }
}
println(gatoRaro.describe())

for ((k, v) in c) println("${k} -> ${v}")

method main {
  val listOfDogs: List[Dog] = new List[Dog](new Dog("Rex"))
  val listOfAnimals: List[Animal] = listOfDogs
  println("Print the line of animal dogs: ${listOfAnimals.item.describe()}")
}
