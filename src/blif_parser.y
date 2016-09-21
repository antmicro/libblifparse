/* C++ parsers require Bison 3 */
%require "3.0"
%language "C++"

/* Write-out tokens header file */
%defines

/* Use Bison's 'variant' to store values. 
 * This allows us to use non POD types (e.g.
 * with constructors/destrictors), which is
 * not possible with the default mode which
 * uses unions.
 */
%define api.value.type variant

/* 
 * Use the 'complete' symbol type (i.e. variant)
 * in the lexer
 */
%define api.token.constructor

/*
 * Add a prefix the make_* functions used to
 * create the symbols
 */
%define api.token.prefix {TOKEN_}

/*
 * Use a re-entrant (no global vars) parser
 */
/*%define api.pure full*/

/* Wrap everything in our namespace */
%define api.namespace {blifparse}

/* Name the parser class */
%define parser_class_name {Parser}

/* Match the flex prefix */
%define api.prefix {blifparse_}

/* Extra checks for correct usage */
%define parse.assert

/* Enable debugging info */
%define parse.trace

/* Better error reporting */
%define parse.error verbose

/* 
 * Fixes inaccuracy in verbose error reporting.
 * May be slow for some grammars.
 */
/*%define parse.lac full*/

/* Track locations */
/*%locations*/

/* Generate a table of token names */
%token-table

%lex-param {Lexer& lexer}
%parse-param {Lexer& lexer}
%parse-param {Callback& callback}


%code requires {
    #include <memory>
    #include "blifparse.hpp"
    #include "blif_lexer_fwd.hpp"
}

%code top {
    #include "blif_lexer.hpp"
    //Bison calls blifparse_lex() to get the next token.
    //We use the Lexer class as the interface to the lexer, so we
    //re-defined the function to tell Bison how to get the next token.
    static blifparse::Parser::symbol_type blifparse_lex(blifparse::Lexer& lexer) {
        return lexer.next_token();
    }
}

%{

#include <stdio.h>
#include "assert.h"

#include "blifparse.hpp"
#include "blif_common.hpp"
#include "blif_error.hpp"

using namespace blifparse;

%}

/* Declare constant */
%token DOT_NAMES ".names"
%token DOT_LATCH ".latch"
%token DOT_MODEL ".model"
%token DOT_SUBCKT ".subckt"
%token DOT_INPUTS ".inputs"
%token DOT_OUTPUTS ".outputs"
%token DOT_CLOCK ".clock"
%token DOT_END ".end"
%token DOT_BLACKBOX ".blackbox"
%token LATCH_FE "fe"
%token LATCH_RE "re"
%token LATCH_AH "ah"
%token LATCH_AL "al"
%token LATCH_AS "as"
%token NIL "NIL"
%token LATCH_INIT_2 "2"
%token LATCH_INIT_3 "3"
%token LOGIC_FALSE "0"
%token LOGIC_TRUE "1"
%token LOGIC_DONT_CARE "-"
%token EQ "="
%token EOL "end-of-line"
%token EOF 0 "end-of-file"

/* declare variable tokens */
%token <std::string> STRING
%token <std::string> CHAR

/* declare types */
%type <std::shared_ptr<BlifData>> blif_data
%type <std::vector<std::string>> string_list
%type <std::vector<LogicValue>> so_cover_row
%type <LogicValue> latch_init
%type <std::string> latch_control
%type <LatchType> latch_type

/* Top level rule */
%start blif_data

%%

blif_data: /*empty*/ {}
    | blif_data DOT_MODEL STRING EOL { callback.start_model($3); }
    | blif_data DOT_INPUTS string_list EOL { callback.inputs($3); }
    | blif_data DOT_OUTPUTS string_list EOL { callback.outputs($3); }
    | blif_data DOT_NAMES string_list EOL { callback.start_names($3); }
    | blif_data so_cover_row EOL { callback.single_output_cover_row($2); }
    | blif_data latch EOL { }
    | blif_data subckt EOL { callback.end_subckt(); }
    | blif_data DOT_BLACKBOX EOL { callback.blackbox(); }
    | blif_data DOT_END EOL { callback.end_model(); }
    ;

subckt: DOT_SUBCKT STRING { callback.start_subckt($2); }
    | subckt STRING EQ STRING { callback.port_connection($2, $4); }
    ;

latch: DOT_LATCH STRING STRING {
                                    //Input and output only
                                    callback.latch($2, $3, LatchType::UNSPECIFIED, "", LogicValue::UNKOWN);
                               }
    | DOT_LATCH STRING STRING latch_type latch_control {
                                    //Input, output, type and control
                                    callback.latch($2, $3, $4, $5, LogicValue::UNKOWN);
                               }
    | DOT_LATCH STRING STRING latch_type latch_control latch_init {
                                    //Input, output, type, control and init-value
                                    callback.latch($2, $3, $4, $5, $6);
                               }
    | DOT_LATCH STRING STRING latch_init {
                                    //Input, output, and init-value
                                    callback.latch($2, $3, LatchType::UNSPECIFIED, "", $4);
                               }
    ;

latch_init: LOGIC_TRUE { $$ = LogicValue::TRUE; }
    | LOGIC_FALSE { $$ = LogicValue::FALSE; }
    | LATCH_INIT_2 { $$ = LogicValue::DONT_CARE; }
    | LATCH_INIT_3 { $$ = LogicValue::UNKOWN; }
    ;

latch_control: STRING { $$ = $1;}
    | NIL { $$ = ""; }
    ;

latch_type: LATCH_FE { $$ = LatchType::FALLING_EDGE; }
    | LATCH_RE { $$ = LatchType::RISING_EDGE; }
    | LATCH_AH { $$ = LatchType::ACTIVE_HIGH; }
    | LATCH_AL { $$ = LatchType::ACTIVE_LOW; }
    | LATCH_AS { $$ = LatchType::ASYNCHRONOUS; }
    ;

so_cover_row: /* empty */ { $$ = std::vector<LogicValue>(); }
    | so_cover_row LOGIC_TRUE { $$ = $1; $$.push_back(LogicValue::TRUE); }
    | so_cover_row LOGIC_FALSE { $$ = $1; $$.push_back(LogicValue::FALSE); }
    | so_cover_row LOGIC_DONT_CARE {$$ = $1; $$.push_back(LogicValue::DONT_CARE); }
    ;

string_list: /*empty*/ { $$ = std::vector<std::string>(); }
    | string_list STRING { $$ = $1; $$.push_back($2); }
    ;

%%


void blifparse::Parser::error(const std::string& msg) {
    blif_error_wrap(lexer.lineno(), lexer.text(), msg.c_str());
}
