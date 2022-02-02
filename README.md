# FoxEnv
Es una librería de Visual Foxpro capaz de leer pares `clave-valor` desde un fichero `.env` y cargarlas en memoria como variables de entorno.


Los ficheros `.env` son básicamente ficheros de variables en el que establecemos una variable con un valor *(también conocido como par clave-valor)*, el propósito de este archivo es mantener sus datos de desarrollo *(acceso a la base de datos, claves API, etc.)* de forma secreta y segura.

`FoxEnv` carga estas variables en memoria y las puedes acceder a través del objeto `_screen.env`.

## Ejemplo de uso
```xBase
   DO FoxEnv WITH "c:\my\file\.env"
   ? _screen.env.my_variable
```

## Convención de nombre para las Variables

Un nombre de variable consta únicamente de letras, dígitos y el guión bajo `_` y no puede comenzar con un dígito. eg: `^[a-zA-Z_]+[a-zA-Z0-9_]*$`

## Ejemplos de nombres válidos e inválidos

```.env
MYSQL_HOST # válido
api_key # válido
user-name # inválido
1password # inválido
```

## Valores
Todos los valores se pueden delimitar con comillas dobles o simples *(o sin delimitar)* Se pueden usar comillas dobles en caso de que necesite interpolar su contenido con un valor de una variable previamente declarada. Las comillas simples no causan interpolación por lo tanto su contenido será tratado de forma literal.

## Ejemplos

```.env
MYSQL_HOST = localhost # Sin delimitar con comillas (válido)
USER_NAME = 'root' # con comillas simples (no ocurre la interpolación)
URL = "${USER_NAME}@${MYSQL_HOST}" # comillas dobles, indican que puede ocurrir una interpolación.
PASSWORD = 12345
EMAIL = ${USER_NAME}@example.org # también se puede interpolar sin delimitar con comillas.
```

## Valores multi-linea
Para indicar un valor multi linea tienes que encerrarlo con comillas triples.
```.env
PRIVATE_KEY = """
---- BEGIN SSH2 PUBLIC KEY ----
AAAAB3NzaC1yc2EAAAABJQAAAQB/nAmOjTmezNUDKYvEeIRf2YnwM9/uUG1d0BYs
c8/tRtx+RGi7N2lUbp728MXGwdnL9od4cItzky/zVdLZE2cycOa18xBK9cOWmcKS
0A8FYBxEQWJ/q9YVUgZbFKfYGaGQxsER+A0w/fX8ALuk78ktP31K69LcQgxIsl7r
NzxsoOQKJ/CIxOGMMxczYTiEoLvQhapFQMs3FL96didKr/QbrfB1WT6s3838SEaX
fgZvLef1YB2xmfhbT9OXFE3FXvh2UPBfN+ffE7iiayQf/2XR+8j4N4bW30DiPtOQ
LGUrH1y5X/rpNZNlWW2+jGIxqZtgWg7lTy3mXy5x836Sj/6L
---- END SSH2 PUBLIC KEY ----
"""
```

## Special parsing
Además de referenciar variables, también puedes parsear tipos primitivos como  `boolean`, `number` y `null` encerrando con comillas dobles.

```.env
IS_DEBUG_MODE = "TRUE" # será convertido a .T. (boolean)
NOT_TRUE = 'false' # no se convierte porque está encerrado con comillas simples.
FALSE = "false" # será convertido a .F.
NONE = "NULL" # será convertido a .NULL.
SALARY = 1234.56 # esto es un string, no se convierte a number.
TOTAL_AMOUNT = "3845.348" # este si que será convertido a number.
```

## Sin interpolar
Si quieres conservar los caracteres usados en la interpolación `${}` solo tienes que encerrar tu contenido en comillas simples.

```.env
PASSWORD = '!@34${sdr}'
CUSTOM_MESSAGE = '''
  Warning: This is a ${warning} message.
'''
```

## Comentarios
Para escribir comentarios debes usar la almohadilla `#`. Todos los comentarios finalizan con el salto de línea.
```.env
# comentario al inicio de la línea
SECRET_HASH = "secreto#esto no es comentario" # este si es comentario
```