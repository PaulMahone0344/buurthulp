Kernlaag, gevuld in M2.
config.dart          serveradres, meldkamernummer, wachtwoordlengte
result.dart          Result<T> = Ok | Err(HhFout)
hh_fout.dart         foutsoorten + vertaling van PocketBase-antwoorden
key_value_store.dart secure storage achter een interface (+ geheugenfake)
pb/                  PocketBaseGateway (enige plek met het pocketbase-pakket),
                     AuthGateway (+ PocketBase- en Fake-implementatie), providers
Zelfde indeling als ObyCom/app/lib/core.
