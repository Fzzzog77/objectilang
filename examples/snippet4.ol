// Declaraciones necesarias para que el fragmento del enunciado tenga sentido:
// a y b son los numeros a comparar; ratings es un objeto cuyos campos son las
// peliculas (nombre -> calificacion), que es lo que recorre for ((name, rating) <- ratings)
val a = 7
val b = 3
object Ratings(Inception: Int, Matrix: Int, Alien: Int)
val ratings = new Ratings(9, 8, 7)

val max = if a > b then a else b
for (( name , rating ) <- ratings ) println (" Movie : $name , Rating : $rating ")