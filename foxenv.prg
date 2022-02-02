* ======================================================================== *
* foxenv	: Parse .env files and loads them as environment variables
* author 	: Irwin Rodríguez <rodriguez.irwin@gmail.com>, 2022-02-01
* language 	: Visual Foxpro 9.0
* ======================================================================== *
lparameters tcFileName

#define CR chr(13)
#define LF chr(10)
#define TAB chr(9)
#define FORM_FEED chr(12)
#define BACKSPACE chr(8)
#define NIL  chr(255)

#define ILLEGAL 	 0
#define FIN		     1
#define NEWLINE 	 2
#define IDENT 		 3
#define NUMBER 		 4
#define INTERP_STR 	 5
#define STRING 		 6
#define ASSIGN 		 7
#define DOLLAR 		 8
#define LBRACE 		 9
#define RBRACE 		 10

if !file(tcFileName)
	wait "File not found: " + tcFileName window nowait
	return
endif

local loLexer, loParser, lTest
loLexer = createobject("envLexer", tcFileName)
loParser = createobject("envParser", loLexer)
loParser.parse()
release loLexer, loParser

* ======================================================================== *
* envLexer.prg
* ======================================================================== *
define class envLexer as custom
	nCurPos = 0
	nPeekPos = 0
	nLine = 0
	nCol = 0
	ch = ''
	cInput = ''
	nPrevToken = 0
	cFileName = ''
	lScanningKey = .f.
	nBeginColIdentifier = 0
	dimension aState[4]
	nCurState = 0
	hidden oRegEx
		
	function init(tcFileName)
		this.cInput = strconv(filetostr(tcFileName), 11)
		this.cFileName = tcFileName
		this.nCurPos = 0
		this.nPeekPos = 1
		this.nLine = 1
		
		this.oRegEx = createobject("VBScript.RegExp")
		this.oRegEx.IgnoreCase = .t.
		this.oRegEx.global = .t.
		
		this.aState[1] = .T.
		this.aState[2] = .F.
		this.aState[3] = .F.
		this.aState[4] = .F.
		
		this.advance()
	endfunc

	hidden function getState
		this.nCurState = this.nCurState + 1
		if this.nCurState > alen(this.aState)
			this.nCurState = 1
		endif
		return this.aState[this.nCurState]
	endfunc

	hidden function advance
		if this.ch == LF
			this.nLine = this.nLine + 1
			this.nCol = 1
		else
			this.nCol = this.nCol + 1
		endif
		if this.nPeekPos > len(this.cInput)
			this.ch = NIL
		else
			this.ch = substr(this.cInput, this.nPeekPos, 1)
		endif
		this.nCurPos = this.nPeekPos
		this.nPeekPos = this.nPeekPos + 1
	endfunc

	hidden function peek
		if this.nPeekPos > len(this.cInput)
			return NIL
		endif
		return substr(this.cInput, this.nPeekPos, 1)
	endfunc

	hidden function skipWhitespace
		do while !this.isAtEnd() and this.isSpace(this.ch)
			this.advance()
		enddo
	endfunc

	hidden function skipComments(tlDontEatEnter)
		do while !this.isAtEnd() and this.ch != LF
			this.advance()
		enddo
		if this.ch == LF and !tlDontEatEnter
			this.advance()
		endif
	endfunc

	function nextToken
		local loTok
		this.lScanningKey = this.getState()
		do while !this.isAtEnd()
			this.nBeginColIdentifier = 0
			if this.isSpace(this.ch)
				this.skipWhitespace()
				loop
			endif
			if this.ch == '#'
				this.skipComments()
				loop
			endif
			if this.lScanningKey and !this.isAtEnd()
				this.nBeginColIdentifier = this.nCol
				return this.newToken(IDENT, this.readIdent(), this.nBeginColIdentifier)
			endif
			if this.isIdent(this.ch)
				this.nBeginColIdentifier = this.nCol
				if this.nPrevToken != ASSIGN
					return this.newToken(IDENT, this.readIdent(), this.nBeginColIdentifier)
				else
					return this.newToken(INTERP_STR, this.readString(), this.nBeginColIdentifier)
				endif
			endif
			if this.isString(this.ch)
				local lnKind
				this.nBeginColIdentifier = this.nCol
				lnKind = iif(this.ch == '"', INTERP_STR, STRING)
				return this.newToken(lnKind, this.readString(), this.nBeginColIdentifier)
			endif
			if this.ch == LF
				if this.nPrevToken != NEWLINE
					this.nBeginColIdentifier = this.nCol
					this.advance()
					return this.newToken(NEWLINE, '', this.nBeginColIdentifier)
				endif
				this.advance()
				loop
			endif
			if this.ch == '='
				this.nBeginColIdentifier = this.nCol
				this.advance()
				return this.newToken(ASSIGN, '=', this.nBeginColIdentifier)
			endif
			if this.ch == '$' and this.nPrevToken == ASSIGN
				this.nBeginColIdentifier = this.nCol
				return this.newToken(INTERP_STR, this.readString(), this.nBeginColIdentifier)
			endif
			this.reportError("illegal character [" + transform(this.ch) + "]")
		enddo
		if this.nPrevToken != NEWLINE
			return this.newToken(NEWLINE, "", 0)
		else
			return this.newToken(FIN, "", 0)
		endif
	endfunc

	hidden function readIdent
		local lnPos
		lnPos = this.nCurPos
		if this.lScanningKey
			do while !this.isAtEnd() and this.ch != '='
				this.advance()
			enddo
			local lcLex
			lcLex = alltrim(substr(this.cInput, lnPos, this.nCurPos-lnPos))
			if !this.testRegEx("^[a-zA-Z_]+[a-zA-Z0-9_]*$", lcLex)
				this.reportError("invalid name [" + lcLex + "] for identifier")
			endif
			return lcLex
		else
			do while !this.isAtEnd() and this.isIdent(this.ch)
				this.advance()
			enddo
			return substr(this.cInput, lnPos, this.nCurPos-lnPos)
		endif
	endfunc

	hidden function readString
		local lcLex, lcPeek, lcStrDelim, lMulStr, lReadToEnd
		store '' to lcLex, lcPeek
		
		if inlist(this.ch, "'", '"')
			if this.peek() == this.ch && treat it like multiple quote
				lcStrDelim = replicate(this.ch, 3)
				lMulStr = substr(this.cInput, this.nCurPos, 3) == '"""'
				if !lMulStr
					lMulStr = substr(this.cInput, this.nCurPos, 3) == "'''"
				endif
				if !lMulStr
					this.reportError("invalid string format")
				endif
				this.advance() && skip 1x " or '
				this.advance() && skip 2x " or '
				this.advance() && skip 3x " or '
			else && it's just a conventional string delimiter
				lcStrDelim = this.ch
				this.advance() && skip 1x"
			endif
		else
			lcStrDelim = chr(13)
			lReadToEnd = .T.
		endif
		
		do while !this.isAtEnd()
			if this.ch = '\'
				lcPeek = this.peek()
				do case
				case lcPeek = 'n'
					this.advance()
					lcLex = lcLex + LF
				case lcPeek = 'r'
					this.advance()
					lcLex = lcLex + CR
				case lcPeek = 't'
					this.advance()
					lcLex = lcLex + TAB
				case lcPeek = 'f'
					this.advance()
					lcLex = lcLex + FORM_FEED
				case lcPeek = 'b'
					this.advance()
					lcLex = lcLex + BACKSPACE
				case lcPeek = '"'
					this.advance()
					lcLex = lcLex + '"'
				case lcPeek = "'"
					this.advance()
					lcLex = lcLex + "'"
				case lcPeek = '\'
					this.advance()
					lcLex = lcLex + '\'
				case lcPeek = 'u'
					this.advance()
					lcLex = lcLex + this.getUnicode()
				otherwise
					lcLex = lcLex + '\'
				endcase
			else
				if (lMulStr and substr(this.cInput, this.nCurPos, 3) == lcStrDelim) or this.ch == lcStrDelim
					this.advance()
					if lMulStr
						this.advance()
						this.advance()
					endif
					exit
				else
					if lReadToEnd and this.ch == '#' && stop reading string
						this.skipComments(.t.)
						exit
					endif
					lcLex = lcLex + this.ch
				endif
			endif
			this.advance()
		enddo
		return lcLex
	endfunc

	hidden function getUnicode
		local lcLex, lcUnicode, lcHexStr
		lcHexStr = '\u'
		lcLex = ''
		lcUnicode = "0x"
		this.advance() && eat the 'u'
		do while !this.isAtEnd() and (this.isHex(this.ch) or isdigit(this.ch))
			if len(lcUnicode) = 6
				exit
			endif
			lcUnicode = lcUnicode + this.ch
			lcHexStr = lcHexStr + this.ch
			lcLex = lcLex + this.ch
			this.advance()
		enddo
		this.pos = this.pos - 1 && shift back the character.
		try
			lcUnicode = chr(&lcUnicode)
		catch
			try
				lcUnicode = strconv(lcHexStr, 16)
			catch
				this.reportError("invalid hex format '" + transform(lcUnicode) + "'")
			endtry
		endtry
		return lcUnicode
	endfunc

	hidden function isHex(tcLook)
		return between(asc(tcLook), asc("A"), asc("F")) or between(asc(tcLook), asc("a"), asc("f"))
	endfunc

	hidden function isIdent(tch)
		return this.isLetter(tch) or isdigit(tch)
	endfunc

	hidden function isString(tch)
		return inlist(tch, '"', "'")
	endfunc

	hidden function newToken(tnKind, tvLexeme, tnCol)
		local loToken
		loToken = createobject("Empty")
		=addproperty(loToken, "kind", tnKind)
		=addproperty(loToken, "lexeme", tvLexeme)
		=addproperty(loToken, "col", tnCol)
		=addproperty(loToken, "line", this.nLine)
		this.nPrevToken = tnKind
		return loToken
	endfunc

	hidden function isAtEnd
		return this.ch == NIL
	endfunc

	hidden function isSpace(tch)
		return tch == space(1) or tch == CR or tch == TAB
	endfunc

	hidden function isLetter(tch)
		return ('a' <= tch and tch <= 'z') or ('A' <= tch and tch <= 'Z') or tch == '_'
	endfunc
	
	function str(toToken)
		local lcTokenStr
		lcTokenStr = ''
		do case
		case toToken.Kind = 0
			lcTokenStr = "ILLEGAL"
		case toToken.Kind = 1
			lcTokenStr = "END"
		case toToken.Kind = 2
			lcTokenStr = "NEWLINE"
		case toToken.Kind = 3
			lcTokenStr = "IDENT"
		case toToken.Kind = 4
			lcTokenStr = "NUMBER"
		case toToken.Kind = 5
			lcTokenStr = "INTERP_STR"
		case toToken.Kind = 6
			lcTokenStr = "STRING"
		case toToken.Kind = 7
			lcTokenStr = "ASSIGN"
		case toToken.Kind = 8
			lcTokenStr = "DOLLAR"
		case toToken.Kind = 9
			lcTokenStr = "LBRACE"
		case toToken.Kind = 10
			lcTokenStr = "RBRACE"
		endcase

		return "<" + lcTokenStr + ", '" + alltrim(transform(tok.Lexeme)) + "'>"
	endfunc

	hidden function testRegEx(tcPattern, tcTest)
		this.oRegEx.pattern = tcPattern
		return this.oRegEx.test(tcTest)
	endfunc
	
	hidden function reportError(tcErrMsg)
		tcErrMsg = this.cFileName + ':' + alltrim(str(this.nLine)) + ':' + alltrim(str(this.nBeginColIdentifier)) + ": error " + tcErrMsg
		wait tcErrMsg window nowait
	endfunc
enddefine

* ======================================================================== *
* envParser.prg
* ======================================================================== *
define class envParser as Custom
	#if .f.
		local this as envParser of env_parser.prg
	#endif

	hidden oLexer
	hidden oCurToken
	hidden oPeekToken
	
	function init(toLexer)
		this.oLexer = toLexer
		this.nextToken()
		this.nextToken()
	endfunc
	
	hidden function nextToken
		this.oCurToken = this.oPeekToken
		this.oPeekToken = this.oLexer.NextToken()
	endfunc
	
	* variable ::= IDENTIFIER '=' STRING | NUMBER
	function parse
		local loEnv, lcVarName, lvValue, lcMacro
		loEnv = createobject("Empty")
		lcMacro = ''
		do while this.oCurToken.Kind != FIN
			lcVarName = this.oCurToken.lexeme
			lvValue = ''
			this.nextToken()
			
			* create the property in env objetct
			this.match(ASSIGN, "expected symbol '='")
			if type('loEnv.' + lcVarName) = 'U'
				addproperty(loEnv, lcVarName, .f.)
			endif
		
			* check for string interpolation
			if this.oCurToken.Kind == INTERP_STR
				local i, j, lcName, lvNewVal
				lvNewVal = this.oCurToken.Lexeme
				j = occurs("${", this.oCurToken.Lexeme)
				if j > 0
					for i = 1 to j
						lcName = strextract(this.oCurToken.Lexeme, "${", "}", i)
						if type('loEnv.' + lcName) = 'U'
							this.reportError("variable '" + lcName + "' not declared")
							return
						endif
						lcMacro = "loEnv." + lcName
						* replace the string with the new value found at lcMacro
						lvNewVal = strtran(lvNewVal, "${" + lcName + "}", alltrim(transform(&lcMacro)))
					endfor
					lvValue = lvNewVal
				else
					* we try to parse boolean
					do case
					case lower(lvNewVal) == "true"
						lvNewVal = .T.
					case lower(lvNewVal) == "false"
						lvNewVal = .F.
					case lower(lvNewVal) == "null"
						lvNewVal = .NULL.
					case this.isNumber(lvNewVal)
						lvValue = val(lvNewVal)
					otherwise
						lvValue = lvNewVal
					endcase					
				endif
			else
				lvValue = this.oCurToken.lexeme
			endif
			lcMacro = "loEnv." + lcVarName + "=lvValue"
			&lcMacro
			this.nextToken()
			if this.oCurToken.Kind == NEWLINE
				this.nextToken()
			endif
		enddo
		if type('_screen.env') != 'U'
			removeproperty(_screen, 'env')
		endif
		addproperty(_screen,'env', loEnv)
	endfunc
	
	hidden function match(tnKind, tcErrorMsg)
		if this.oCurToken.Kind == tnKind
			this.nextToken()
		else
			this.reportError(tcErrorMsg)
		endif
	endfunc
	
	hidden function reportError(tcErrMsg)
		tcErrMsg = this.oLexer.cFileName + ':' + alltrim(str(this.oCurToken.Line)) + ':' + alltrim(str(this.oCurToken.Col)) + ": error " + tcErrMsg
		wait tcErrMsg window nowait
	endfunc
	
	hidden function isNumber(tcValue)
		local i
		for i = 1 to len(tcValue)
			if !isdigit(substr(tcValue, i, 1))
				return .f.
			endif
		endfor
		return .t.
	endfunc
enddefine