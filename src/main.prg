* ======================================================================== *
* foxenv	: Parse .env files and loads them as environment variables
* author 	: Irwin Rodríguez <rodriguez.irwin@gmail.com>, 2022-02-01
* language 	: Visual Foxpro 9.0
* ======================================================================== *
lparameters tcFileName
#include "foxenv.h"
set procedure to "env_lexer" additive

local loLexer
loLexer = createobject("envLexer", tcFileName)

tok = loLexer.NextToken()
do while tok.kind != FIN
	str1 = "<" + transform(tok.kind) + ", '" + transform(tok.Lexeme) + "'>"
	?loLexer.str(tok)
	tok = loLexer.NextToken()
enddo
?loLexer.str(tok)