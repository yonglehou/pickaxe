/* Copyright 2015 Brock Reeve
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

grammar Scrape;

options {
  language=CSharp3;
  output=AST;
  ASTLabelType=CommonTree;
  TokenLabelType=CommonToken;
  backtrack=true; 
  }

  
tokens { 
  PROGRAM;
  FILE_TABLE;
  BUFFER_TABLE;
  MSSQL_TABLE;
  TABLE_COLUMN_ARGS;
  TABLE_COLUMN_ARG;
  TABLE_VARIABLE_REFERENCE;
  TABLE_MEMBER_REFERENCE;
  TABLE_ALIAS;
  ROW_REFERENCE;
  MEMBER_REFERENCE;
  BLOCK;
  SELECT_ID;
  SELECT_ALL;
  VARIABLE_REFERENCE;
  VARIABLE_DECLARATION;
  VARIABLE_ASSIGNMENT;
  SELECT_STATEMENT;
  SELECT_ARG;
  TAKE_ATTRIBUTE;
  TAKE_TEXT;
  TAKE_HTML;
  PRE_PICK;
  POST_PICK;
  INSERT_INTO_DIRECTORY;
  EXPAND_INTERATION_VARIABLE;
  PROXY_LIST;
  WHEN_LITERAL_STATEMENT;
  WHEN_BOOL_STATEMENT;
  CASE_BOOL;
  CASE_VAR;
  CASE_EXPRESSION;
}

/*
 * Parser Rules
 */
 
public program
	: noBraceBlock EOF -> ^(PROGRAM noBraceBlock)
	| proxyStatement noBraceBlock EOF -> ^(PROGRAM proxyStatement noBraceBlock)
	| procedureDefinition -> ^(PROGRAM procedureDefinition)
	;

procedureDefinition
	: PROCEDURE ID OPENPAREN tableColumnArgs* CLOSEPAREN block -> ^(PROCEDURE ID block tableColumnArgs* ) 	 
	;

statement
	: createTableStatement
	| sqlStatement
	| updateStatment
	| variableDeclarationStatement
	| variableAssignmentStatement
	| insertStatement
	| eachStatement
	| whileStatement
	| procedureCall
	| truncateTable
	;

truncateTable
	: TRUNCATE TABLE ID -> ^(TRUNCATE TABLE_VARIABLE_REFERENCE[$ID])
	;


procedureCall
	:  EXEC ID OPENPAREN procedureCallList* CLOSEPAREN -> ^(EXEC ID procedureCallList*)
	;

procedureCallList
	: (callArgs COMMA)* callArgs -> callArgs*
	;

callArgs
	: expandVar
	| STRING_LITERAL
	;

proxyStatement
	: PROXIES OPENPAREN proxyList CLOSEPAREN proxyTest -> ^(PROXIES proxyList proxyTest)
	;

proxyList
	: (STRING_LITERAL COMMA)* STRING_LITERAL -> ^(PROXY_LIST STRING_LITERAL*)
	;

proxyTest
	: WITH TEST OPENBRACE sqlStatement CLOSEBRACE -> sqlStatement
	;

whileStatement
	: WHILE OPENPAREN ID CLOSEPAREN block -> ^(WHILE TABLE_VARIABLE_REFERENCE[$ID] block)
	;

eachStatement
	: EACH OPENPAREN VAR v=ID IN t=ID CLOSEPAREN block -> ^(EACH VARIABLE_DECLARATION[$v] TABLE_VARIABLE_REFERENCE[$t] block)
	;

noBraceBlock
	: statement* -> ^(BLOCK statement*)
	;

block
	: OPENBRACE statement* CLOSEBRACE -> ^(BLOCK statement*)
	;

expandExpression
	: EXPAND OPENPAREN expandVar TO expandVar CLOSEPAREN expandBlock* -> ^(EXPAND expandVar expandVar expandBlock*)
	;

expandBlock
	: OPENBRACE mathExpression* CLOSEBRACE -> mathExpression*
	;

expandVar
	: INT
	| variableReference
	;

downloadExpression
	: downloadPageExpresssion
	| downloadImageExpression
	;

downloadPageExpresssion
	: DOWNLOAD_PAGE^ downloadExpressionArg tableHint?
	;

downloadImageExpression
	: DOWNLOAD_IMAGE^ downloadExpressionArg
	;

downloadExpressionArg
	: STRING_LITERAL
	| OPENPAREN! sqlStatement CLOSEPAREN!
	| variableReference
	;
	
variableReference
	: ID -> VARIABLE_REFERENCE[$ID]
	| COMMAND_VAR
	| IDENTITY_VAR
	| tableMemberReference
	;	

tableMemberReference
	: t=ID DOT m=ID -> ^(TABLE_MEMBER_REFERENCE ROW_REFERENCE[$t] MEMBER_REFERENCE[$m])
	;

variableDeclarationStatement 
	: VAR ID EQUALS assignmentExpression -> ^(VARIABLE_DECLARATION ID assignmentExpression)
	;

variableAssignmentStatement
	: variableReference EQUALS assignmentExpression -> ^(VARIABLE_ASSIGNMENT variableReference assignmentExpression)
	;

nullOperator
	: COMMAND_VAR NULL_OPERATOR^ (COMMAND_VAR|literal)
	;

assignmentExpression
	: mathExpression
	| downloadExpression
	| expandExpression
	| sqlStatement
	| nullOperator
	| variableReference
	;

mathExpression
    	:  mathExpressionGroup (( PLUS | MINIS )^ mathExpressionGroup)*
    	;
 
mathExpressionGroup
	: atom (( ASTERISK | DIV )^ atom)*
  	;
  
atom
    	: variableReference
		| '$' -> ^(EXPAND_INTERATION_VARIABLE)
		| literal
    	| OPENPAREN! mathExpression CLOSEPAREN!
    	;

literal
	: INT
	| STRING_LITERAL
	| NULL
	;
	

/************* INSERT ****************/

insertStatement
	: INSERT_INTO ID sqlStatement-> ^(INSERT_INTO TABLE_VARIABLE_REFERENCE[$ID] sqlStatement)
	| INSERT_DIRECTORY mathExpression sqlStatement-> ^(INSERT_INTO_DIRECTORY mathExpression sqlStatement)
	| INSERT_OVERWRITE ID sqlStatement-> ^(INSERT_OVERWRITE TABLE_VARIABLE_REFERENCE[$ID] sqlStatement)
	;


/*************** UPDATE ******************/

updateStatment
	: UPDATE ID setArgs fromStatement? whereStatement? -> ^(UPDATE ^(TABLE_ALIAS ID) setArgs fromStatement? whereStatement?)
	;

setArgs
	: SET (setArg COMMA)* setArg -> ^(SET setArg*)
	;

setArg
	: selectArg EQUALS selectArgs -> ^(VARIABLE_ASSIGNMENT selectArg selectArgs)
	;

/************* SELECTS *******************/

sqlStatement
	: selectStatement fromStatement? whereStatement? -> ^(SELECT_STATEMENT selectStatement fromStatement? whereStatement?)
	;

whereStatement
	:  WHERE boolExpression -> ^(WHERE boolExpression) 
	;

fromStatement
	: FROM t=ID a=ID? innerJoinStatement? -> ^(FROM TABLE_VARIABLE_REFERENCE[$t] ^(TABLE_ALIAS $a)? innerJoinStatement?) 
	| FROM^ tableGenerationClause
	| FROM OPENPAREN tableGenerationClause CLOSEPAREN ID tableHint? -> ^(FROM tableGenerationClause ^(TABLE_ALIAS ID) tableHint?)
	;

tableHint
	: WITH OPENPAREN (hint PIPE)* hint CLOSEPAREN -> hint*
	;

hint
	: THREAD OPENPAREN INT CLOSEPAREN -> ^(THREAD INT)
	| JS (OPENPAREN (jsArg COMMA)* jsArg CLOSEPAREN)? -> ^(JS jsArg*)
	;

jsArg
	: STRING_LITERAL
	| INT
	;


innerJoinStatement
	: innerJoin t=ID a=ID? 'on' boolExpression innerJoinStatement? -> ^(INNER_JOIN TABLE_VARIABLE_REFERENCE[$t] ^(TABLE_ALIAS $a)? boolExpression innerJoinStatement?)
	;

tableGenerationClause
	: downloadPageExpresssion
	| downloadImageExpression
	| expandExpression
	;

innerJoin
	: JOIN
	| INNER_JOIN
	;

selectStatement
	: SELECT (selectArgs COMMA)* selectArgs -> ^(SELECT selectArgs*)
	| SELECT ASTERISK -> ^(SELECT ^(SELECT_ARG SELECT_ALL[$ASTERISK]))
	;


selectArgs
	: (selectArg PLUS)* selectArg -> ^(SELECT_ARG selectArg*)
	| caseStatement -> ^(SELECT_ARG caseStatement)
	;

/*******CASE STATEMENT********/

caseStatement
	: CASE whenBoolStatement+ (ELSE caseExpression)? END -> ^(CASE_BOOL whenBoolStatement+ caseExpression?)
	| CASE selectArg whenLiteralStatement+ (ELSE caseExpression)? END -> ^(CASE_VAR selectArg whenLiteralStatement+ caseExpression?)
	;

caseExpression
	: selectArg -> ^(CASE_EXPRESSION selectArg)
	;

whenLiteralStatement
	: WHEN literal THEN caseExpression -> ^(WHEN_LITERAL_STATEMENT literal caseExpression)
	;

whenBoolStatement
	: WHEN boolExpression THEN caseExpression -> ^(WHEN_BOOL_STATEMENT boolExpression caseExpression)
	;

boolExpression
	: andExpression (OR^ andExpression)*
	;

andExpression
	:  boolTerm (AND^ boolTerm)* 
	;
	
boolTerm
	: NODES EQUALS STRING_LITERAL -> ^(NODES SELECT_ID[$NODES] STRING_LITERAL)
	| selectArg (boolOperator^ selectArg)? 
	| OPENPAREN! boolExpression CLOSEPAREN!
	;

boolOperator
	: EQUALS
	| LESSTHAN
	| LESSTHANEQUAL
	| GREATERTHAN
	| GREATERTHANEQUAL
	| NOTEQUAL
	| LIKE
	| NOTLIKE
	;

selectArg
	: pickStatement
	| literal
	| selectVariable
	| primitiveFunction
	;

primitiveFunction
	: GETDATE^ OPENPAREN! CLOSEPAREN!
	;

selectVariable
	: ID -> ^(SELECT_ID[$ID])
	| COMMAND_VAR
	| IDENTITY_VAR
	| tableMemberReference
	;
	
pickStatement
	: PICK STRING_LITERAL takeStatement? matchStatement? -> ^(PICK STRING_LITERAL takeStatement? matchStatement? )
	;

takeStatement
	: TAKE ATTRIBUTE STRING_LITERAL -> ^(TAKE_ATTRIBUTE STRING_LITERAL)
	| TAKE TEXT -> ^(TAKE_TEXT)
	| TAKE HTML -> ^(TAKE_HTML)
	;

matchStatement	
	: MATCH STRING_LITERAL replaceStatement? -> ^(MATCH STRING_LITERAL replaceStatement?)
	;

replaceStatement
	: REPLACE STRING_LITERAL -> ^(REPLACE STRING_LITERAL)
	;
/************ CREATE TABLES ****************/

createTableStatement
	: CREATE FILE ID OPENPAREN tableColumnArgs* CLOSEPAREN fileTableWithStatement? fileTableLocation -> ^(FILE_TABLE ID tableColumnArgs* fileTableWithStatement? fileTableLocation)
	| CREATE BUFFER ID OPENPAREN tableColumnArgs* CLOSEPAREN -> ^(BUFFER_TABLE ID tableColumnArgs*)
	| CREATE MSSQL ID OPENPAREN tableColumnArgs* CLOSEPAREN sqlTableWithStatement -> ^(MSSQL_TABLE ID tableColumnArgs* sqlTableWithStatement)
	;

fileTableLocation
	: LOCATION^ mathExpression 
	;

sqlTableWithStatement
	: WITH OPENPAREN sqlTableWithVariablesStatement CLOSEPAREN -> ^(WITH sqlTableWithVariablesStatement)
	;

sqlTableWithVariablesStatement 
	: (sqlTableWithVariableStatement COMMA)* sqlTableWithVariableStatement -> sqlTableWithVariableStatement*
	;

sqlTableWithVariableStatement 
	: (CONNECTIONSTRING | DBTABLE)^ EQUALS! STRING_LITERAL
	;

fileTableWithStatement
	: WITH OPENPAREN fileTableWithVariablesStatement* CLOSEPAREN -> ^(WITH fileTableWithVariablesStatement*)
	;	

fileTableWithVariablesStatement 
	: (fileTableWithVariableStatement COMMA)* fileTableWithVariableStatement -> fileTableWithVariableStatement*
	;

fileTableWithVariableStatement
	: (FIELD_TERMINATOR | ROW_TERMINATOR)^ EQUALS! STRING_LITERAL
	;

tableColumnArgs
	: (tableColumnArg COMMA)* tableColumnArg -> ^(TABLE_COLUMN_ARGS tableColumnArg*)
	;

tableColumnArg 
	: ID dataType -> ^(TABLE_COLUMN_ARG ID dataType)
	;	

dataType 
	: STRING
	| INTEGER
	| FLOAT
	| IDENTITY
	| DATETIME 
	;
	
/*
 * Lexer Rules
 */

PROCEDURE: 'procedure';
GETDATE : 'getdate';
EXEC: 'exec';
CASE: 'case';
WHEN: 'when';
THEN: 'then';
END: 'end';
ELSE: 'else';

VAR: 'var';

AND : 'and';
OR : 'or';

EQUALS : '=';
LESSTHAN : '<';
LESSTHANEQUAL: '<=';
GREATERTHAN: '>';
GREATERTHANEQUAL: '>=';
NOTEQUAL: '!=';
LIKE: 'like';
NOTLIKE: 'not like';

NULL_OPERATOR: '??';

UPDATE : 'update';
SET : 'set';
INSERT_INTO : 'insert into';
INSERT_OVERWRITE : 'insert overwrite';
INSERT_DIRECTORY : 'insert file into';
TRUNCATE : 'truncate';
THREAD : 'thread';
JS : 'js';
WHILE : 'while';
EACH : 'each';
IN : 'in';
SELECT : 'select';
FROM : 'from';
INNER_JOIN : 'inner join';
JOIN: 'join';
NODES: 'nodes';
WHERE : 'where';
PICK : 'pick';
TAKE : 'take';
MATCH	: 'match';
REPLACE : 'replace';
ATTRIBUTE : 'attribute';
TEXT : 'text';
HTML : 'html';
DOWNLOAD_IMAGE : 'download image';	
DOWNLOAD_PAGE : 'download page';
IDENTITY : 'identity';
EXPAND : 'expand';
TO : 'to';
PROXIES: 'proxies';
TEST : 'test';
NULL : 'null';

CREATE : 'create';
FILE : 'file';
BUFFER : 'buffer';
MSSQL : 'mssql';
WITH : 'with';
STRING : 'string';
INTEGER: 'int';
FLOAT: 'float';
DATETIME : 'datetime';
FIELD_TERMINATOR : 'fieldterminator';
ROW_TERMINATOR : 'rowterminator';
LOCATION : 'location';
CONNECTIONSTRING : 'connectionstring';
TABLE : 'table';
DBTABLE : 'dbtable';

STRING_LITERAL: APOSTRAPHE ~(APOSTRAPHE)* APOSTRAPHE;
IDENTITY_VAR : '@@identity';
COMMAND_VAR : '@' DIGIT+;
ID : LETTER+;
ASTERISK : '*';
DOT : '.';
OPENPAREN : '(';
CLOSEPAREN : ')';
OPENBRACE : '{';
CLOSEBRACE : '}';
PIPE : '|';
PLUS	: '+';
MINIS 	: '-';
DIV 	: '/'; 
COMMA : ',';
QUOTE : '"';
APOSTRAPHE : '\'';
INT : DIGIT+;
fragment NEWLINE : ('\n'|'\r');
fragment DIGIT: '0'..'9';
fragment LETTER :('a'..'z' | 'A'..'Z'); 
fragment OTHERCHARS : ('.' | '|' | '-' | '&' | ',' | '\\' | ':'); 
WS :  (' '|'\t'|NEWLINE)+ {$channel = Hidden;};
COMMENT : '/*' .* '*/' {$channel = Hidden;};
LINE_COMMENT_SLASH : '//' ~NEWLINE* {$channel = Hidden;};
LINE_COMMENT_DASH : '--' ~NEWLINE* {$channel = Hidden;};


