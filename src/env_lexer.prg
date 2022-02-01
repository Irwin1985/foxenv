* ======================================================================== *
* env_lexer.prg
* ======================================================================== *
#include "foxenv.h"
define class envLexer as custom
	nCurPos = 0
	nPeekPos = 0
	nLine = 0
	nCol = 0
	ch = ''
	cInput = ''
	nPrevToken = 0
	cFileName = ''

	function init(tcFileName)
		this.cInput = filetostr(tcFileName)
		this.cFileName = tcFileName
		this.nCurPos = 0
		this.nPeekPos = 1
		this.nLine = 1
		this.advance()
	endfunc


	hidden function advance
		if this.ch == LF
			this.nLine = this.nLine + 1
			this.nCol = 1
		else
			this.nCol = this.nCol + 1
		endif
		if this.nPeekPos >= len(this.cInput)
			this.ch = FIN
		else
			this.ch = substr(this.cInput, this.nPeekPos, 1)
		endif
		this.nCurPos = this.nPeekPos
		this.nPeekPos = this.nPeekPos + 1
	endfunc

	hidden function peek
		if this.nPeekPos > len(this.cInput)
			return FIN
		endif
		return substr(this.cInput, this.nPeekPos, 1)
	endfunc

	hidden function skipWhitespace
		do while !this.isAtEnd() and this.isSpace(this.ch)
			this.advance()
		enddo
	endfunc

	hidden function skipComments
		do while !this.isAtEnd() and this.ch != LF
			this.advance()
		enddo
		if this.isAtEnd()
			error "Lexer Error: unexpected EOF"
		endif
		if this.ch == LF
			this.advance()
		endif
	endfunc

	function nextToken
		local lnCol, loTok
		do while !this.isAtEnd()
			lnCol = 0
			if this.isSpace(this.ch)
				this.skipWhitespace()
				loop
			endif
			if this.ch == '#'
				this.skipComments()
				loop
			endif
			if this.isLetter(this.ch)
				lnCol = this.nCol
				return this.newToken(IDENT, this.readIdent(), lnCol)
			endif
			if isdigit(this.ch)
				lnCol = this.nCol
				return this.newToken(number, this.readNumber(), lnCol)
			endif
			if this.isString(this.ch)
				local lnKind
				lnCol = this.nCol
				lnKind = iif(this.ch == '"', INTERP_STR, STRING)
				return this.newToken(STRING, this.readString(), lnCol)
			endif
			if this.ch == LF
				if this.nPrevToken != NEWLINE
					lnCol = this.nCol
					this.advance()
					return this.newToken(NEWLINE, '', lnCol)
				endif
				this.advance()
				loop
			endif
			if this.ch == '='
				lnCol = this.nCol
				this.advance()
				return this.newToken(ASSIGN, '=', lnCol)
			endif
			loTok = this.newToken(ILLEGAL, this.ch, this.nCol)
			this.advance()
			return loTok
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
		do while !this.isAtEnd() and this.isIdent(this.ch)
			this.advance()
		enddo
		if this.isAtEnd()
			error "Lexer Error: unexpected EOF"
		endif
		return substr(this.cInput, lnPos, this.nCurPos-1)
	endfunc

	hidden function readNumber
		local lnValue, lnDigit, lnScale
		store 0 to lnValue, lnDigit, lnScale
		do while !this.isAtEnd() and isdigit(this.ch)
			lnDigit = val(this.ch)
			lnValue = lnValue * 10 + lnDigit
			this.advance()
		enddo

		if this.ch == '.'
			this.advance()
			lnScale = 1
			do while !this.isAtEnd() and isdigit(this.ch)
				lnScale = lnScale * 0.1
				lnDigit = val(this.ch)
				lnValue = lnValue + (lnScale * lnDigit)
				this.advance()
			enddo
		endif
		if this.isAtEnd()
			error "Lexer Error: unexpected EOF"
		endif
		return lnValue
	endfunc

	hidden function readString
		local lcLex, lcPeek, lcStrDelim
		store '' to lcLex, lcPeek
		lcStrDelim = this.ch
		this.advance()
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
				if this.ch == lcStrDelim
					this.advance()
					exit
				else
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
				error "Lexer Error: invalid hex format '" + transform(lcUnicode) + "'"
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
		return this.nCurPos >= len(this.cInput)
	endfunc

	hidden function isSpace(tch)
		return tch == space(1) or tch == CR or tch == TAB
	endfunc

	hidden function isLetter(tch)
		return isalpha(tch) or tch == '_'
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
		case toToken.Kind = 5 or toToken.Kind = 6
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
enddefine