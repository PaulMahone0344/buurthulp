import 'hh_fout.dart';

/// Gelukt of mislukt met een nette [HhFout]. Voorkomt dat exceptions door
/// de schermen reizen; een scherm kijkt alleen naar Ok of Err.
sealed class Result<T> {
  const Result();

  factory Result.ok(T waarde) = Ok<T>;
  factory Result.err(HhFout fout) = Err<T>;
}

class Ok<T> extends Result<T> {
  const Ok(this.waarde);
  final T waarde;
}

class Err<T> extends Result<T> {
  const Err(this.fout);
  final HhFout fout;
}
