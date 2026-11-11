object Animal
object Dog extends Animal
object Cat extends Animal

object List[+A](val item: A)

method main {
    val listOfDogs: List[Dog] = new List(new Dog)
    val listOfAnimals: List[Animal] = listOfDogs

    println("Print the line of animal dogs: ${listOfAnimals.item}")
}
