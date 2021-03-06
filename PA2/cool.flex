/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

int curr_len;
bool str_overflow_flag;
bool str_has_null = false;

int comment_level = 0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

void check_str(int curr_len);

%}
%x IN_COMMENT
%x IN_STRING
%x STR_OVERFLOW
%x NULL_IN_STR

NUM [0-9]+
IDOBJ [a-z]([A-z]|[0-9]|_)*
IDCLASS [A-Z]([A-z]|[0-9]|_)*
%%

[cC][lL][aA][sS][sS]    { return (CLASS);  }
[eE][lL][sS][eE]        { return (ELSE); }
[fF][iI]                { return (FI); }
[iI][fF]                { return (IF); }
[iI][nN]                { return (IN); }
[Ii][Nn][Hh][Ee][Rr][Ii][Tt][Ss] { return (INHERITS); }
[Ll][Ee][Tt] { return (LET); }
[Ll][Oo][Oo][Pp] { return (LOOP); }
[Pp][Oo][Oo][Ll] { return (POOL); }
[Tt][Hh][Ee][Nn] { return (THEN); }
[Ww][Hh][Ii][Ll][Ee] { return (WHILE); }
[Cc][Aa][Ss][Ee] { return (CASE); }
[Ee][Ss][Aa][Cc] { return (ESAC); }
[Oo][Ff] { return (OF); }
[Nn][Ee][Ww] { return (NEW); }
[Ii][Ss][Vv][Oo][Ii][Dd] { return (ISVOID); }
[Nn][Oo][Tt] { return (NOT); }

"=>" { return (DARROW); }
"<" { return ('<'); }
"=" { return ('='); }
"~" { return ('~'); }
"<=" {return (LE); }
":" { return (':'); }
"{" { return ('{'); }
"}" { return ('}'); }
";" { return (';'); }
"(" { return ('('); }
")" { return (')'); }
"." { return ('.'); }
"," { return (','); }
"@" { return ('@'); }
"+" { return ('+'); }
"-" { return ('-'); }
"*" { return ('*'); }
"/" { return ('/'); }
"<-" { return (ASSIGN); }

<INITIAL,IN_COMMENT>"(*" { 
    comment_level++;
    BEGIN(IN_COMMENT);
 }

<IN_COMMENT>"*)" {
    comment_level--;
    if (comment_level == 0) {
        BEGIN(INITIAL);
    }
 }
<IN_COMMENT>.
<IN_COMMENT>\n curr_lineno++;
<IN_COMMENT><<EOF>> {
    cool_yylval.error_msg = "EOF in comment";
    BEGIN(INITIAL);
    return (ERROR);
 }

<INITIAL>"*)" {
    cool_yylval.error_msg = "Unmatched *)";
    return (ERROR);
 }

<INITIAL>\" {
    curr_len = 0;
    str_overflow_flag = false;
    str_has_null = false;
    string_buf_ptr = string_buf;
    BEGIN(IN_STRING);
 }
<IN_STRING>"\\\\" {
    *string_buf_ptr++ = '\\';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\\n {
    *string_buf_ptr++ = '\n';
    curr_lineno++;
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\n {
    *string_buf_ptr++ = '\n';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\t {
    *string_buf_ptr++ = '\t';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\f {
    *string_buf_ptr++ = '\f';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\b {
    *string_buf_ptr++ = '\b';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\0 {
    *string_buf_ptr++ = '0';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\0 {
    str_has_null = true;
    BEGIN(NULL_IN_STR);
 }
<IN_STRING>\\\" {
    *string_buf_ptr++ = '"';
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING>\\[^\0] {
    *string_buf_ptr++ = yytext[1];
    curr_len++;
    check_str(curr_len);
 }
<IN_STRING,STR_OVERFLOW,NULL_IN_STR>\n {
    if (str_overflow_flag) {
        cool_yylval.error_msg = "String constant too long";
    } else if (str_has_null) {
        cool_yylval.error_msg = "String contains null character";
    } else {
        cool_yylval.error_msg = "Unterminated string constant";
    }
    curr_lineno++;
    BEGIN(INITIAL);
    return (ERROR);
 }
<IN_STRING><<EOF>> {
    cool_yylval.error_msg = "EOF in string constant";
    BEGIN(INITIAL);
    return (ERROR);
 }
<IN_STRING,STR_OVERFLOW,NULL_IN_STR>\" {
    if (str_overflow_flag) {
        cool_yylval.error_msg = "String constant too long";
        BEGIN(INITIAL);
        return (ERROR);
    } else if (str_has_null) {
        cool_yylval.error_msg = "String contains null character";
        BEGIN(INITIAL);
        return (ERROR);
    }

    *string_buf_ptr = 0;
    cool_yylval.symbol = inttable.add_string(string_buf);
    BEGIN(INITIAL);
    return (STR_CONST);
 }

<STR_OVERFLOW,NULL_IN_STR>.

<IN_STRING>. {
    *string_buf_ptr++ = *yytext;
    curr_len++;
    check_str(curr_len);
 }
   
t[rR][uU][eE] {
    cool_yylval.boolean = true;
    return (BOOL_CONST);
}

f[Aa][Ll][Ss][Ee] {
    cool_yylval.boolean = false;
    return (BOOL_CONST);
}

{IDCLASS} { 
    cool_yylval.symbol = inttable.add_string(yytext);
    return (TYPEID);
}

{IDOBJ} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (OBJECTID);
}

{NUM} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}


"--".*

[ \t\f\r\v]+
\n curr_lineno++;

. {
    cool_yylval.error_msg = yytext;
    return (ERROR);
}

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


%%

void check_str(int curr_len)
{
    str_overflow_flag = (curr_len >= MAX_STR_CONST);
    if (str_overflow_flag) {
        BEGIN(STR_OVERFLOW);
    }
}
