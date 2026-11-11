//El snippet requiere crear objeto Cat y Animal
//Requiere método main para ejecutar el método

object Animal
object Cat

Cat.talk = method() : String {
    println("Cats meows")
}

method main {
    val cat = new Cat
    cat.talk()
}
