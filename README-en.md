# FoxEnv
A Visual Foxpro library that reads `key-value` pairs from a `.env` file and loads them as environment variables.


`.env` files it's basically a variable text file in which we set a variable with a value *(also known as key-value pair)*, the purpose of this file is to keep your development data *(database access, API keys, etc)* as secret and secure.

`FoxEnv` loads these variables in memory and you can reference it through `_screen.env` object.

## Usage
```xBase
   DO FoxEnv WITH "c:\my\file\.env"
   ? _screen.env.my_variable
```

## Variable naming convention

A variable name consist of solely letters, digits and the underscore `_` and cannot start with digit. eg: `^[a-zA-Z_]+[a-zA-Z0-9_]*$`

## Example variable names

```.env
MYSQL_HOST # valid
api_key # valid
user-name # invalid
1password # invalid
```

## Values
All values can be delimited by double quotes or single quotes. Double quote can be used in case you need to interpolate your content with a previous variable value.

## Examples

```.env
MYSQL_HOST = localhost #without quotation (ok)
USER_NAME = 'root' #with single quote (no interpolation occurs)
URL = "${USER_NAME}@${MYSQL_HOST}" #double quote indicates the string can be interpolated.
PASSWORD = 12345
EMAIL = ${USER_NAME}@example.org #you can also interpolate without double quotes
```

## Multi-line values
In order to use multi-line values you must use the `triple-quote heredoc syntax`
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

## Parsing special data types
Besides referencing variables, you can parse primitive types like `boolean`, `number` and `null` again wrapping it with double quotes

```.env
IS_DEBUG_MODE = "TRUE" # when parsed will be casted as boolean (.t.)
NOT_TRUE = 'false' # this cannot be casted so it will keep their literal form due single quote.
FALSE = "false" # this will be casted as .F.
NONE = "NULL" # this will be casted as .NULL.
SALARY = 1234.56 # this is a string (dont get confused)
TOTAL_AMOUNT = "3845.348" # this will be casted into Number data type.
```

## Non-interpolated
If you want to keep the `${}` in your value the wrap your content with single quotes.

```.env
PASSWORD = '!@34${sdr}'
CUSTOM_MESSAGE = '''
  Warning: This is a ${warning} message.
'''
```

## Comments
Use the hash-tag `#` symbol to denotes a comment. All comments end with the `line-feed` character.
```.env
# comment at the very begining of the line
SECRET_HASH = "this-is-the-secret-hash-#-and-this-is-not-a-comment" # this last one it is.
```