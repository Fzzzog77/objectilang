object Animal
object Dog extends Animal
object Puppy extends Dog

object Food
object DogFood extends Food

Food.getSimpleName = method() : String {
    "${getClass}"
}

object Transformer [-In , +Out] 
Transformer.transform = method ( input : In): Out

method main {
    val animalFeeder : Transformer [Animal , DogFood] = new Transformer [ Animal , DogFood ] {
        override transform ( animal : Animal ): DogFood = {
            println (" Preparing specialized food for an animal ...")
            new DogFood
        }
    }
    val puppyFeeder : Transformer [Puppy , Food ] = animalFeeder
    val myPuppy = new Puppy
    val resultantFood : Food = puppyFeeder.transform ( myPuppy )
    println (" Resulting food type : ${resultantFood.getSimpleName}")
}