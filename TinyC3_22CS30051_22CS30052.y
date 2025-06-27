%{
    #include <bits/stdc++.h>
    #include "TinyC3_22CS30051_22CS30052_translator.h"
    using namespace std;
    string data_type;
    extern int yylex(); // in lex.yy.c : Lexical analyser
    extern int yylineno; // in lex.yy.c : Line number
    extern char *yytext;    // in lex.yy.c : Identified lexeme
    void yyerror(string s);  // in lex.yy.c : Error function 
%}


%union {
    Symbol *symb;       // Symbol
    Type *symbType;   // Symbol type
    int iValue;     // Integer value
    char *sValue;   // String value
    Expression *expr;   // Expression
    Statement *statem;  // Statement
    Array *arr; // Array
    int instr_ind;  // Keep track of instruction number
    char unary_op;  // Unary operator
    int param_count;   // Parameter count for functions
}

// TOKENS
%token PLUS MINUS TILDE EXCLAMATION AMPERSAND ASTERISK SLASH PERCENT PERIOD ARROW INCR DECR VOID CASE FLOAT SHORT VOLATILE
%token OPEN_SQ_BRACKET CLOSE_SQ_BRACKET CURLY_BRACKET_OPEN OPEN_PAREN CLOSE_PAREN ASSIGN MULTIPLY_ASSIGN DIVIDE_ASSIGN MOD_ASSIGN
%token PLUS_ASSIGN MINUS_ASSIGN LEFT_SHIFT_ASSIGN RIGHT_SHIFT_ASSIGN AND_ASSIGN XOR_ASSIGN OR_ASSIGN COMMA HASH CURLY_BRACKET_CLOSE
%token AUTO ENUM RESTRICT UNSIGNED BREAK EXTERN RETURN CHAR FOR SIGNED WHILE CONST GOTO SIZEOF BOOL CONTINUE IF STATIC COMPLEX 
%token LOGICAL_AND IMAGINARY DO INT SWITCH DOUBLE LONG TYPEDEF ELSE LOGICAL_OR QUESTION COLON SEMICOLON ELLIPSIS DEFAULT INLINE STRUCT
%token GREATER_THAN LESS_THAN_EQUAL GREATER_THAN_EQUAL EQUAL NOT_EQUAL CARET PIPE LEFT_SHIFT RIGHT_SHIFT LESS_THAN REGISTER UNION INVALID_TOKEN


%token <sValue> LITERAL         // String literal
%token <symb> IDENTIFIER        // Identifier, taken as symbol
%token <sValue> CONSTANT_CHAR   // Character constant
%token <sValue> CONSTANT_FLOAT  // Floating point constant
%token <iValue> CONSTANT_INT    // Integer constant

%start START

%right THEN ELSE    // Checks if Else can be matched with If

/* Types for all non-terminals */
%type <symb> constant initializer direct_declarator init_declarator declarator  // Symbol non-terminals
%type <symbType> pointer   // Pointer non-terminal
%type <expr> expression primary_expression multiplicative_expression additive_expression shift_expression relational_expression equality_expression AND_expression exclusive_OR_expression inclusive_OR_expression logical_AND_expression logical_OR_expression conditional_expression assignment_expression expression_statement   // Expression type non-terminals
%type <statem> statement labeled_statement compound_statement selection_statement iteration_statement jump_statement loop_statement block_item block_item_list block_item_list_opt  // Statement type non-terminals
%type<sValue> assignment_operator
%type <unary_op> unary_operator // Unary operator non-terminals
%type <param_count> argument_expression_list argument_expression_list_opt   // Number of parameters non-terminals
%type <instr_ind> M // Augmented non-terminal to help with backpatching by storing next instruction index
%type <statem> N    // Augmented non-terminal to help with control flow
%type <arr> postfix_expression unary_expr cast_expression // Array non-terminals
%type<void> TU Statements

%%

START:  
        TU{}
        | TU Statements{}
        ;

TU: 
        TU Statements translation_unit{}
        | translation_unit{}
        | /* epsilon */{}
        ;

Statements:  
        Statements statement{}
        | statement{}
        ;

primary_expression  : IDENTIFIER    {
                        $$ = new Expression();  // New expression
                        $$->addr = $1;      // Store pointer in Symbol Table
                        $$->exprType = "not_bool";   // Non bool expression
                    }
                    | constant      {
                        $$ = new Expression();  // New expression
                        $$->addr = $1;      // Store pointer in Symbol Table
                    }
                    | LITERAL       {
                        $$ = new Expression();  // New expression
                        $$->addr = SymbolTable::createTemp(new Type("ptr"), $1); // Create new temp with type ptr and store value
                        $$->addr->type->subtype = new Type("char");
                        emit("=", $$->addr->name, $1); // literal = $1
                    }
                    | OPEN_PAREN expression CLOSE_PAREN { $$ = $2; } // Assignment
                    ;

constant            : CONSTANT_INT  {
                        $$ = SymbolTable::createTemp(new Type("int"), intToStr($1)); // Create new temp with type int and store value
                        emit("=", $$->name, $1);
                    }
                    | CONSTANT_FLOAT{
                        $$ = SymbolTable::createTemp(new Type("float"), string($1));  // Create new temp with type double and store value
                        emit("=", $$->name, string($1));
                    }
                    | CONSTANT_CHAR {
                        $$ = SymbolTable::createTemp(new Type("char"), string($1));   // Create new temp with type char and store value
                        emit("=", $$->name, string($1));
                    }
                    ;

postfix_expression  : primary_expression {
                        $$ = new Array();   // New Array
                        $$->type = $1->addr->type;  // Update type
                        $$->location = $1->addr;   // Store pointer in Symbol Table
                        $$->addr = $$->location;   // Update location
                    }
                    | postfix_expression OPEN_PAREN argument_expression_list_opt CLOSE_PAREN {
                        $$ = new Array();   // Make new array
                        $$->location = SymbolTable::createTemp($1->type); // Get return type
                        string ln0, ln1;
                        ln0 = $$->location->name;
                        ln1 = $1->location->name;
                        emit("call", ln0, ln1, intToStr($3)); // call name param_count
                    }
                    | postfix_expression OPEN_SQ_BRACKET expression CLOSE_SQ_BRACKET {
                        $$ = new Array();   // New Array
                        $$->type = $1->type->subtype;   // Update type
                        $$->location = $1->location;  // Copy the incoming symbol
                        $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in location which will have the address of the array element
                        $$->arrType = "arr"; // A type is array

                        if ($1->arrType == "arr") { // Array of array
                            Symbol* temp = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in temp
                            int sz = getSize($$->type);  // Get size of type of current
                            emit("*", temp->name, $3->addr->name, intToStr(sz)); // temp = expression * sz
                            emit("+", $$->addr->name, $1->addr->name, temp->name); // post = post1 + temp
                        }
                        else {
                            int sz = getSize($$->type);  // Get size of type of current
                            emit("*", $$->addr->name, $3->addr->name, intToStr(sz)); // post = expression * sz
                        }
                    }
                    | postfix_expression PERIOD IDENTIFIER {}
                    | postfix_expression ARROW IDENTIFIER {}
                    | postfix_expression INCR {
                        emit("+", $1->location->name, $1->location->name, "1");   // post1 = post1 + 1
                    }
                    | postfix_expression DECR {
                        emit("-", $1->location->name, $1->location->name, "1");   // post1 = post1 - 1
                    }
                    | OPEN_PAREN type_name CLOSE_PAREN CURLY_BRACKET_OPEN initializer_list COMMA CURLY_BRACKET_CLOSE {}                    
                    | OPEN_PAREN type_name CLOSE_PAREN CURLY_BRACKET_OPEN initializer_list CURLY_BRACKET_CLOSE {}
                    ;

argument_expression_list_opt : argument_expression_list {$$ = $1;} // Copy the number of parameters
                            |  {$$ = 0;}   // No parameters
                            ;

argument_expression_list    : assignment_expression {
                                $$ = 1;
                                string an = $1->addr->name;
                                emit("param", an);  // Emit param
                            }
                            | argument_expression_list COMMA assignment_expression {
                                $$ = $1 + 1;
                                string an = $3->addr->name;
                                emit("param", an);  // Emit param
                            }
                            ;

unary_expr          : postfix_expression { $$ = $1;} // Pass the expression
                    | INCR unary_expr {
                        string ln2 = $2->location->name;
                        emit("+", ln2, ln2, "1");   // unary1 = unary1 + 1
                        $$ = $2;    // unary = unary1
                    }
                    | DECR unary_expr {
                        string ln2 = $2->location->name;
                        emit("-", ln2, ln2, "1");   // unary1 = unary1 - 1
                        $$ = $2;
                    }
                    | unary_operator cast_expression {
                        $$ = new Array();
                        if ($1 == '&') {
                            $$->location = SymbolTable::createTemp(new Type("ptr")); // Create new temp with type ptr and store in addr
                            $$->location->type->subtype = $2->location->type;
                            emit("= &", $$->location->name, $2->location->name); // unary = &unary1
                        }
                        else if ($1 == '*') {
                            $$->arrType = "ptr"; // Pointer type
                            $$->addr = SymbolTable::createTemp($2->location->type->subtype); // Create new temp with type of current and store in location
                            $$->location = $2->location;    // Copy the incoming symbol
                            string an=$$->addr->name;
                            string ln = $2->location->name;
                            emit("= *", an, ln); // unary = *unary1
                        }
                        else if ($1 == '+'){
                            $$ = $2;
                        }
                        else if ($1 == '-') {
                            $$->location = SymbolTable::createTemp(new Type($2->location->type->base)); // Create new temp with type of current and store in addr
                            string ln0, ln1;
                            ln0 = $$->location->name;
                            ln1 = $2->location->name;
                            emit("= -", ln0, ln1); // unary = $1 unary1
                        }
                        else if ($1 == '~')  {
                            $$->location = SymbolTable::createTemp(new Type($2->location->type->base)); // Create new temp with type of current and store in addr
                            string ln0, ln1;
                            ln0 = $$->location->name;
                            ln1 = $2->location->name;
                            emit("= ~", ln0, ln1); // unary = $1 unary1
                        }
                        else if ($1 == '!') {
                            $$->location = SymbolTable::createTemp(new Type($2->location->type->base)); // Create new temp with type of current and store in addr
                            string ln0, ln1;
                            ln0 = $$->location->name;
                            ln1 = $2->location->name;
                            emit("= !", ln0, ln1); // unary = $1 unary1
                        }
                    }
                    | SIZEOF unary_expr {}
                    | SIZEOF OPEN_PAREN type_name CLOSE_PAREN {}
                    ;

unary_operator      : AMPERSAND {$$ = '&';}
                    | ASTERISK  {$$ = '*';}
                    | PLUS      {$$ = '+';}
                    | MINUS     {$$ = '-';}
                    | TILDE     {$$ = '~';}
                    | EXCLAMATION {$$ = '!';}
                    ;

cast_expression     : unary_expr {$$ =  $1;} 
                    | OPEN_PAREN type_name CLOSE_PAREN cast_expression {
                        $$ = new Array();
                        Symbol *loc_4 = $4->location;
                        $$->location = convType(loc_4, data_type);
                    }
                    ;

multiplicative_expression : cast_expression {
                            $$ = new Expression(); // new expression
                            if ($1->arrType == "arr") {
                                $$->addr = SymbolTable::createTemp($1->addr->type); // Create new temp with type of current and store in addr
                                emit("=[]", $$->addr->name, $1->location->name, $1->addr->name); // multexpr = castexpr [ castexpr->Array->name ]
                            }
                            else if($1->arrType == "ptr") {
                                $$->addr = $1->addr; // Copy the incoming symbol
                            }
                            else $$->addr = $1->location; // Copy the incoming symbol
                          }
                          | multiplicative_expression SLASH cast_expression {
                            if (typecheck($1->addr, $3->location)) {
                                $$ = new Expression();
                                $$->addr = SymbolTable::createTemp(new Type($1->addr->type->base)); // Create new temp with type int and store in addr
                                emit("/", $$->addr->name, $1->addr->name, $3->location->name); // multexpr = multexpr1 / castexpr
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                          }
                          | multiplicative_expression ASTERISK cast_expression {
                            if (typecheck($1->addr, $3->location)) {
                                $$ = new Expression();
                                $$->addr = SymbolTable::createTemp(new Type($1->addr->type->base)); // Create new temp with type int and store in addr
                                emit("*", $$->addr->name, $1->addr->name, $3->location->name); // multexpr = multexpr1 * castexpr
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                          }
                          
                          | multiplicative_expression PERCENT cast_expression {
                            if (typecheck($1->addr, $3->location)) {
                                $$ = new Expression();
                                $$->addr = SymbolTable::createTemp(new Type($1->addr->type->base)); // Create new temp with type int and store in addr
                                emit("%", $$->addr->name, $1->addr->name, $3->location->name); // multexpr = multexpr1 % castexpr
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                          }
                          ;

additive_expression : multiplicative_expression { $$ = $1; } // Pass 
                    | additive_expression PLUS multiplicative_expression {
                        if (typecheck($1->addr, $3->addr)) {
                            $$ = new Expression();
                            $$->addr = SymbolTable::createTemp(new Type($1->addr->type->base)); // Create new temp with type int and store in addr
                            string an0, an1, an2;
                            an0 = $$->addr->name;
                            an1 = $1->addr->name;
                            an2 = $3->addr->name;
                            emit("+", an0, an1, an2); // addexpr = addexpr1 + multexpr
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    | additive_expression MINUS multiplicative_expression {
                        if (typecheck($1->addr, $3->addr)) {
                            $$ = new Expression();
                            $$->addr = SymbolTable::createTemp(new Type($1->addr->type->base)); // Create new temp with type int and store in addr
                            string an0, an1, an2;
                            an0 = $$->addr->name;
                            an1 = $1->addr->name;
                            an2 = $3->addr->name;
                            emit("-", an0, an1, an2); // addexpr = addexpr1 - multexpr
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    ;

shift_expression    : additive_expression {$$ = $1;} // Pass
                    | shift_expression LEFT_SHIFT additive_expression {
                        if ($3->addr->type->base == "int") {
                            $$ = new Expression();
                            $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in addr
                            string an0, an1, an2;
                            an0 = $$->addr->name;
                            an1 = $1->addr->name;
                            an2 = $3->addr->name;
                            emit("<<", an0, an1, an2); // shiftexpr = shiftexpr1 << addexpr
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    | shift_expression RIGHT_SHIFT additive_expression {
                        if ($3->addr->type->base == "int") {
                            $$ = new Expression();
                            $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in addr
                            string an0, an1, an2;
                            an0 = $$->addr->name;
                            an1 = $1->addr->name;
                            an2 = $3->addr->name;
                            emit(">>", an0, an1, an2); // shiftexpr = shiftexpr1 >> addexpr
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    ;

relational_expression   : shift_expression { $$ = $1; }
                        | relational_expression GREATER_THAN shift_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                $$ = new Expression();
                                $$->exprType = "bool";   // Boolean type
                                $$->trueList = makelist(nextinstr()); // Make list of next instruction
                                $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                                emit(">", "", $1->addr->name, $3->addr->name); // if relexpr > shiftexpr
                                emit("goto", ""); // goto
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        | relational_expression LESS_THAN shift_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                $$ = new Expression();
                                $$->exprType = "bool";   // Boolean type
                                $$->trueList = makelist(nextinstr()); // Make list of next instruction
                                $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                                emit("<", "", $1->addr->name, $3->addr->name); // if relexpr < shiftexpr
                                emit("goto", ""); // goto
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        
                        | relational_expression LESS_THAN_EQUAL shift_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                $$ = new Expression();
                                $$->exprType = "bool";   // Boolean type
                                $$->trueList = makelist(nextinstr()); // Make list of next instruction
                                $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                                emit("<=", "", $1->addr->name, $3->addr->name); // if relexpr <= shiftexpr
                                emit("goto", ""); // goto
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        | relational_expression GREATER_THAN_EQUAL shift_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                $$ = new Expression();
                                $$->exprType = "bool";   // Boolean type
                                $$->trueList = makelist(nextinstr()); // Make list of next instruction
                                $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                                emit(">=", "", $1->addr->name, $3->addr->name); // if relexpr >= shiftexpr
                                emit("goto", ""); // goto
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        ;

equality_expression : relational_expression {$$ = $1;} // Pass
                    | equality_expression EQUAL relational_expression {
                        if (typecheck($1->addr, $3->addr)) {
                            boolToInt($1);
                            boolToInt($3);
                            $$ = new Expression();
                            $$->exprType = "bool";   // Boolean type
                            $$->trueList = makelist(nextinstr()); // Make list of next instruction
                            $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                            emit("==", "", $1->addr->name, $3->addr->name); // if eqexpr == relexpr
                            emit("goto", ""); // goto
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    | equality_expression NOT_EQUAL relational_expression {
                        if (typecheck($1->addr, $3->addr)) {
                            boolToInt($1);
                            boolToInt($3);
                            $$ = new Expression();
                            $$->exprType = "bool";   // Boolean type
                            $$->trueList = makelist(nextinstr()); // Make list of next instruction
                            $$->falseList = makelist(nextinstr()+1); // Make list of next instruction
                            emit("!=", "", $1->addr->name, $3->addr->name); // if eqexpr != relexpr
                            emit("goto", ""); // goto
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    ;

AND_expression      : equality_expression {$$ = $1;} // Pass
                    | AND_expression AMPERSAND equality_expression {
                        if (typecheck($1->addr, $3->addr)) {
                            boolToInt($1);
                            boolToInt($3);
                            $$ = new Expression();
                            $$->exprType = "not_bool"; // Not boolean
                            $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in addr
                            emit("&", $$->addr->name, $1->addr->name, $3->addr->name); // andexpr = andexpr1 & eqexpr
                        }
                        else {
                            yyerror("Type mismatch");
                        }
                    }
                    ;
            
exclusive_OR_expression : AND_expression {$$ = $1;} // Pass
                        | exclusive_OR_expression CARET AND_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                boolToInt($1);
                                boolToInt($3);
                                $$ = new Expression();
                                $$->exprType = "not_bool"; // Not boolean
                                $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in addr
                                emit("^", $$->addr->name, $1->addr->name, $3->addr->name); // xorexpr = xorexpr1 ^ andexpr
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        ;

inclusive_OR_expression : exclusive_OR_expression {$$ = $1;} // Pass
                        | inclusive_OR_expression PIPE exclusive_OR_expression {
                            if (typecheck($1->addr, $3->addr)) {
                                boolToInt($1);
                                boolToInt($3);
                                $$ = new Expression();
                                $$->exprType = "not_bool"; // Not boolean
                                $$->addr = SymbolTable::createTemp(new Type("int")); // Create new temp with type int and store in addr
                                emit("|", $$->addr->name, $1->addr->name, $3->addr->name); // orexpr = orexpr1 | xorexpr
                            }
                            else {
                                yyerror("Type mismatch");
                            }
                        }
                        ;

logical_AND_expression  : inclusive_OR_expression {$$ = $1;} // Pass
                        | logical_AND_expression LOGICAL_AND M inclusive_OR_expression {    // M is augmented non-terminal
                            intToBool($1);
                            intToBool($4);
                            $$ = new Expression();
                            $$->exprType = "bool";   // Boolean type
                            backpatch($1->trueList, $3); // Backpatch
                            $$->trueList = $4->trueList; // Copy true list
                            $$->falseList = merge($1->falseList, $4->falseList); // Merge false lists
                        }
                        ;

logical_OR_expression   : logical_AND_expression {$$ = $1;} // Pass
                        | logical_OR_expression LOGICAL_OR M logical_AND_expression {   // M is augmented non-terminal
                            intToBool($1);
                            intToBool($4);
                            $$ = new Expression();
                            $$->exprType = "bool";   // Boolean type
                            backpatch($1->falseList, $3); // Backpatch
                            $$->falseList = $4->falseList; // Copy false list
                            $$->trueList = merge($1->trueList, $4->trueList); // Merge true lists
                        }
                        ;

conditional_expression  : logical_OR_expression {$$ = $1;} // Pass
                        | logical_OR_expression N QUESTION M expression N COLON M conditional_expression {  // M and N are augmented non-terminals
                            $$->addr = SymbolTable::createTemp($5->addr->type); // Create new temp with type of current and store in addr
                            $$->addr->update($5->addr->type);
                            emit("=", $$->addr->name, $9->addr->name); // condexpr = condexpr1
                            list <int> templist1 = makelist(nextinstr());
                            emit("goto", "");   // goto
                            backpatch($6->nextList, nextinstr());   // For N2
                            emit("=", $$->addr->name, $5->addr->name); // condexpr = expr
                            list <int> templist2 = makelist(nextinstr());
                            templist1 = merge(templist1, templist2);
                            emit("goto", "");   // goto
                            backpatch($2->nextList, nextinstr());   // For N1
                            intToBool($1);
                            backpatch($1->trueList, $4); // Backpatch to M1 when true
                            backpatch($1->falseList, $8); // Backpatch to M2 when false
                            backpatch(templist1, nextinstr());
                        }
                        ;

/* AUGMENTED EMPTY NON-TERMINALS */
M:  { $$ = nextinstr(); } // Has next instruction for backpatching

N:  { $$ = new Statement(); $$->nextList = makelist(nextinstr()); emit("goto", ""); } // Has next list for control flow

assignment_expression   : conditional_expression {$$ = $1;} // Pass
                        | unary_expr assignment_operator assignment_expression {
                            if ($1->arrType == "arr") { // convert array
                                $3->addr = convType($3->addr, $1->type->base);
                                emit("[]=", $1->location->name, $1->addr->name, $3->addr->name); // unary[unary1] = asgnexpr1
                            }
                            else if ($1->arrType == "ptr") emit("=*", $1->location->name, $3->addr->name);  // Pointer type, *unary = asgnexpr1
                            else {
                                $3->addr = convType($3->addr, $1->location->type->base);
                                if($2 == "=") emit("=", $1->location->name, $3->addr->name); // unary = asgnexpr1
                                else if($2 == "*=") emit("*=", $1->location->name, $3->addr->name); // unary *= asgnexpr1
                                else if($2 == "/=") emit("/=", $1->location->name, $3->addr->name); // unary /= asgnexpr1
                                else if($2 == "%=") emit("%=", $1->location->name, $3->addr->name); // unary %= asgnexpr1
                                else if($2 == "+=") emit("+=", $1->location->name, $3->addr->name); // unary += asgnexpr1
                                else if($2 == "-=") emit("-=", $1->location->name, $3->addr->name); // unary -= asgnexpr1
                                else if($2 == "<<=") emit("<<=", $1->location->name, $3->addr->name); // unary <<= asgnexpr1
                                else if($2 == ">>=") emit(">>=", $1->location->name, $3->addr->name); // unary >>= asgnexpr1
                                else if($2 == "&=") emit("&=", $1->location->name, $3->addr->name); // unary &= asgnexpr1
                                else if($2 == "^=") emit("^=", $1->location->name, $3->addr->name); // unary ^= asgnexpr1
                                else if($2 == "|=") emit("|=", $1->location->name, $3->addr->name); // unary |= asgnexpr1
                            }
                            $$ = $3;
                        }
                        ;

assignment_operator     : ASSIGN {$$ = "=";}
                        | MULTIPLY_ASSIGN {$$ = "*=";}
                        | DIVIDE_ASSIGN {$$ = "/=";}
                        | MOD_ASSIGN {$$ = "%=";}
                        | PLUS_ASSIGN {$$ = "+=";}
                        | MINUS_ASSIGN {$$ = "-=";}
                        | AND_ASSIGN {$$ = "&=";}
                        | XOR_ASSIGN {$$ = "^=";}
                        | OR_ASSIGN {$$ = "|=";}
                        | LEFT_SHIFT_ASSIGN {$$ = "<<=";}
                        | RIGHT_SHIFT_ASSIGN {$$ = ">>=";}
                        
                        ;

expression  : assignment_expression {$$ = $1;} // Pass
            | expression COMMA assignment_expression {}
            ;

constant_expression : conditional_expression {}
                    ;



declaration : declaration_specifiers init_declarator_list SEMICOLON {}
            | declaration_specifiers SEMICOLON {}
            ;

declaration_specifiers  : storage_class_specifier declaration_specifiers {}
                        | storage_class_specifier {}
                        | type_specifier declaration_specifiers {}
                        | type_specifier {}
                        | type_qualifier declaration_specifiers {}
                        | type_qualifier {}
                        | function_specifier declaration_specifiers {}
                        | function_specifier {}
                        ;

init_declarator_list: init_declarator_list COMMA init_declarator {}
                    | init_declarator {}
                    ;

init_declarator : declarator {$$ = $1;} // Pass
                | declarator ASSIGN initializer {
                    if ($3->initValue != ""){
                        $1->initValue = $3->name;
                    }
                    emit("=", $1->name, $3->name);
                }
                ;

storage_class_specifier : EXTERN {}
                        | STATIC {}
                        | AUTO {}
                        | REGISTER {}
                        ;

// Void, char, int and float are the only valid data types to be provided.
type_specifier  : VOID {data_type = "void";}
                | CHAR {data_type = "char";}
                | SHORT {}
                | INT {data_type = "int";}
                | LONG {}
                | FLOAT {data_type = "float";}
                | DOUBLE {}
                | SIGNED {}
                | UNSIGNED {}
                | BOOL {}
                | enum_specifier {}
                | COMPLEX {}
                | IMAGINARY {}
                ;

specifier_qualifier_list    : type_specifier specifier_qualifier_list_opt {}
                            | type_qualifier specifier_qualifier_list_opt {}
                            ;

specifier_qualifier_list_opt    : specifier_qualifier_list {}
                                |  {}
                                ;

enum_specifier  : ENUM identifier_opt CURLY_BRACKET_OPEN enumerator_list CURLY_BRACKET_CLOSE {}
                | ENUM identifier_opt CURLY_BRACKET_OPEN enumerator_list COMMA CURLY_BRACKET_CLOSE {}
                | ENUM IDENTIFIER {}
                ;

identifier_opt  : IDENTIFIER {}
                | {}
                ;

enumerator_list : enumerator {}
                | enumerator_list COMMA enumerator {}
                ;
// can't use CONSTANT_ENUM as it would conflict with IDENTIFIER
enumerator  : IDENTIFIER {}
            | IDENTIFIER ASSIGN constant_expression {}
            ;

type_qualifier  : CONST {}
                | VOLATILE {}
                | RESTRICT {}
                ;

function_specifier  : INLINE {}
                    ;

declarator  :
            direct_declarator {};
            |
            pointer direct_declarator {
                Type* t = $1;
                while(t->subtype != NULL){
                    t = t->subtype;
                }
                t->subtype = $2->type;  // Assign type
                $$ = $2->update($1);    // Update
            }
            ;

direct_declarator   : IDENTIFIER {
                        $$ = $1->update(new Type(data_type));   // Get data type of identifier
                        currentSymbol = $1;                     // Update current symbol
                    }
                    | OPEN_PAREN declarator CLOSE_PAREN { $$ = $2;} // Assignment
                    | direct_declarator OPEN_SQ_BRACKET type_qualifier_list CLOSE_SQ_BRACKET {}
                    | direct_declarator OPEN_SQ_BRACKET type_qualifier_list assignment_expression CLOSE_SQ_BRACKET {} 
                    | direct_declarator OPEN_SQ_BRACKET assignment_expression CLOSE_SQ_BRACKET {
                        Type* t = $1->type;
                        Type* prev = NULL;
                        while(t->base == "arr") {
                            prev = t;
                            t = t->subtype;
                        }
                        if (prev == NULL) {
                            int temp = atoi($3->addr->initValue.c_str()); 
                            Type* tp = new Type("arr", $1->type, temp);   // Create new array type
                            $$ = $1->update(tp);   
                        }
                        else {
                            int temp = atoi($3->addr->initValue.c_str());   // Init value
                            prev->subtype = new Type("arr", t, temp);  // Create new array type
                            $$ = $1->update($1->type);  // Update
                        }
                    }
                    | direct_declarator OPEN_SQ_BRACKET CLOSE_SQ_BRACKET {
                        Type* t = $1->type;
                        Type* prev = NULL;
                        while(t->base == "arr") {
                            prev = t;
                            t = t->subtype;
                        }
                        if (prev == NULL) {
                            Type* tp = new Type("arr", $1->type, 0);   // Create new array type
                            $$ = $1->update(tp);    // Update
                        }
                        else {
                            prev->subtype = new Type("arr", t, 0);  // Create new array type
                            $$ = $1->update($1->type);  // Update
                        }
                    }
                    | direct_declarator OPEN_SQ_BRACKET ASTERISK CLOSE_SQ_BRACKET {}
                    | direct_declarator OPEN_SQ_BRACKET STATIC type_qualifier_list assignment_expression CLOSE_SQ_BRACKET {}
                    | direct_declarator OPEN_SQ_BRACKET type_qualifier_list ASTERISK CLOSE_SQ_BRACKET {}
                    | direct_declarator OPEN_SQ_BRACKET type_qualifier_list STATIC assignment_expression CLOSE_SQ_BRACKET {}
                    | direct_declarator OPEN_SQ_BRACKET STATIC assignment_expression CLOSE_SQ_BRACKET {}
                    
                    | direct_declarator OPEN_PAREN change_table parameter_type_list CLOSE_PAREN {   // change_table non terminal is used to change the symbol table
                        activeSymbolTable->name = $1->name; // Update name
                        if ($1->type->base != "void") {
                            Symbol* s = activeSymbolTable->lookup("return");   // Find return symbol
                            s->update($1->type);    // Update return type
                        }
                        $1->nestedTable = activeSymbolTable;    // Update nested table
                        activeSymbolTable->parent = globalSymbolTable;   // Update parent
                        switchActiveTable(globalSymbolTable);  // Switch to global symbol table
                        currentSymbol = $$; // Update current symbol
                    }
                    | direct_declarator OPEN_PAREN identifier_list CLOSE_PAREN {}
                    | direct_declarator OPEN_PAREN change_table CLOSE_PAREN {
                        activeSymbolTable->name = $1->name; // Update name
                        if ($1->type->base != "void") {
                            Symbol* s = activeSymbolTable->lookup("return");   // Find return symbol
                            s->update($1->type);    // Update return type
                        }
                        $1->nestedTable = activeSymbolTable;    // Update nested table
                        activeSymbolTable->parent = globalSymbolTable;   // Update parent
                        switchActiveTable(globalSymbolTable);  // Switch to global symbol table
                        currentSymbol = $$; // Update current symbol
                    }
                    ;

type_qualifier_list_opt : type_qualifier_list {}
                        | {}
                        ;

pointer : ASTERISK type_qualifier_list_opt {$$ =  new Type("ptr");} // Create new pointer type
        | ASTERISK type_qualifier_list_opt pointer {$$ = new Type("ptr", $3);} // Create new pointer type
        ;

type_qualifier_list : type_qualifier {}
                    | type_qualifier_list type_qualifier {}
                    ;

type_name   : specifier_qualifier_list {}
            ;

parameter_type_list : parameter_list {}
                    | parameter_list COMMA ELLIPSIS {}
                    ;

identifier_list : IDENTIFIER {}
                | identifier_list COMMA IDENTIFIER {}
                ;

parameter_list  : parameter_declaration {}
                | parameter_list COMMA parameter_declaration {}
                ;

parameter_declaration   : declaration_specifiers declarator {}
                        | declaration_specifiers {}
                        ;

initializer : assignment_expression {$$ = $1->addr;}
            | CURLY_BRACKET_OPEN initializer_list CURLY_BRACKET_CLOSE {}
            | CURLY_BRACKET_OPEN initializer_list COMMA CURLY_BRACKET_CLOSE {}
            ;

initializer_list    : designation_opt initializer {}
                    | initializer_list COMMA designation_opt initializer {}
                    ;

designation_opt : designation {}
                | {}
                ;

designation : designator_list ASSIGN {}
            ;

designator_list : designator {}
                | designator_list designator {}
                ;

designator  : OPEN_SQ_BRACKET constant_expression CLOSE_SQ_BRACKET {}
            | PERIOD IDENTIFIER {}
            ;


statement   : labeled_statement {}
            | compound_statement { $$ = $1; }
            | expression_statement {
                $$ = new Statement();
                $$->nextList = $1->nextList;
            }
            | selection_statement { $$ = $1; }
            | iteration_statement { $$ = $1; }
            | jump_statement { $$ = $1; }
            ;

// Added new non-terminal for loops
loop_statement: labeled_statement {}
            | expression_statement {
                $$ = new Statement();
                $$->nextList = $1->nextList;
            }
            | selection_statement { $$ = $1; }
            | iteration_statement { $$ = $1; }
            | jump_statement { $$ = $1; }
            ;

labeled_statement   : IDENTIFIER COLON statement {}
                    | CASE constant_expression COLON statement {}
                    | DEFAULT COLON statement {}
                    ;

compound_statement  : CURLY_BRACKET_OPEN X change_table block_item_list_opt CURLY_BRACKET_CLOSE {   // X and change_table are augmented non-terminals
                        $$ = $4;
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    ;

block_item_list_opt : block_item_list { $$ = $1; }
                    | { $$ = new Statement();}
                    ;

block_item_list : block_item {$$ = $1;}
                | block_item_list M block_item {    // M is augmented non-terminal
                    $$ = $3;
                    backpatch($1->nextList, $2);    // Backpatch to jump to 2
                }
                ;

block_item  : declaration { $$ = new Statement(); }
            | statement { $$ = $1; }
            ;

expression_statement    : expression SEMICOLON { $$ = $1; }
                        | SEMICOLON { $$ = new Expression(); }
                        ;

selection_statement : IF OPEN_PAREN expression N CLOSE_PAREN M statement N %prec THEN { // M, N and THEN augmented to help with control flow
                        backpatch($4->nextList, nextinstr());   // Backpatch to next instruction
                        intToBool($3);
                        $$ = new Statement();
                        backpatch($3->trueList, $6);    // Backpatch to M
                        list<int> temp = merge($3->falseList, $7->nextList); // Merge false lists
                        $$->nextList = merge($8->nextList, temp); // Merge false lists
                    }
                    | IF OPEN_PAREN expression N CLOSE_PAREN M statement N ELSE M statement {
                        backpatch($4->nextList, nextinstr());   // Backpatch to next instruction
                        intToBool($3);
                        $$ = new Statement();
                        backpatch($3->trueList, $6);    // Backpatch to M1
                        backpatch($3->falseList, $10);   // Backpatch to M2
                        list<int> temp = merge($7->nextList, $8->nextList); // Merge false lists
                        $$->nextList = merge($11->nextList, temp); // Merge false lists
                    }
                    | SWITCH OPEN_PAREN expression CLOSE_PAREN statement {}
                    ;

iteration_statement : WHILE W OPEN_PAREN X change_table M expression CLOSE_PAREN M loop_statement { // W, X, M and change_table are augmented non-terminals
                        $$ = new Statement(); // new statement
                        intToBool($7);
                        backpatch($10->nextList, $6);   // Backpatch to M1
                        backpatch($7->trueList, $9);    // Backpatch to M2
                        $$->nextList = $7->falseList;  // Copy false list
                        emit("goto", intToStr($6)); // goto
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    | WHILE W OPEN_PAREN X change_table M expression CLOSE_PAREN CURLY_BRACKET_OPEN M block_item_list_opt CURLY_BRACKET_CLOSE { // W, X, M and change_table are augmented non-terminals
                        $$ = new Statement(); // new statement
                        intToBool($7);
                        backpatch($11->nextList, $6);   // Backpatch to M1
                        backpatch($7->trueList, $10);    // Backpatch to M2
                        $$->nextList = $7->falseList;  // Copy false list
                        emit("goto", intToStr($6)); // goto
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    | DO D M loop_statement M WHILE OPEN_PAREN expression CLOSE_PAREN SEMICOLON {   // D and M are augmented non-terminals
                        $$ = new Statement();
                        intToBool($8);
                        backpatch($8->trueList, $3);    // Backpatch to D
                        backpatch($4->nextList, $5);    // Backpatch to M
                        $$->nextList = $8->falseList;  // Copy false list
                        currentBlock = "";
                    }
                    | DO D CURLY_BRACKET_OPEN M block_item_list_opt CURLY_BRACKET_CLOSE M WHILE OPEN_PAREN expression CLOSE_PAREN SEMICOLON {  // D and M are augmented non-terminals
                        $$ = new Statement();
                        intToBool($10);
                        backpatch($10->trueList, $4);    // Backpatch to M1
                        backpatch($5->nextList, $7);    // Backpatch to M2
                        $$->nextList = $10->falseList;  // Copy false list
                        currentBlock = "";
                    }
                    | FOR F OPEN_PAREN X change_table declaration M expression_statement M expression N CLOSE_PAREN M loop_statement {  // F, X, M, N and change_table are augmented non-terminals
                        $$ = new Statement();
                        intToBool($8);
                        backpatch($8->trueList, $13); // Backpatch to M3
                        backpatch($11->nextList, $7); // Backpatch to M1
                        backpatch($14->nextList, $9); // Backpatch to N
                        emit("goto", intToStr($9)); // goto
                        $$->nextList = $8->falseList;  // Copy false list
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    | FOR F OPEN_PAREN X change_table expression_statement M expression_statement M expression N CLOSE_PAREN M loop_statement {  // F, X, M, N and change_table are augmented non-terminals
                        $$ = new Statement();
                        intToBool($8);
                        backpatch($8->trueList, $13); // Backpatch to M3
                        backpatch($11->nextList, $7); // Backpatch to M1
                        backpatch($14->nextList, $9); // Backpatch to N
                        emit("goto", intToStr($9)); // goto
                        $$->nextList = $8->falseList;  // Copy false list
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    | FOR F OPEN_PAREN X change_table declaration M expression_statement M expression N CLOSE_PAREN M CURLY_BRACKET_OPEN block_item_list_opt CURLY_BRACKET_CLOSE {  // F, X, M, N and change_table are augmented non-terminals
                        $$ = new Statement();
                        intToBool($8);
                        backpatch($8->trueList, $13); // Backpatch to M3
                        backpatch($11->nextList, $7); // Backpatch to M1
                        backpatch($15->nextList, $9); // Backpatch to N
                        emit("goto", intToStr($9)); // goto
                        $$->nextList = $8->falseList;  // Copy false list
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    | FOR F OPEN_PAREN X change_table expression_statement M expression_statement M expression N CLOSE_PAREN M CURLY_BRACKET_OPEN block_item_list_opt CURLY_BRACKET_CLOSE { // F, X, M, N and change_table are augmented non-terminals
                        $$ = new Statement();
                        intToBool($8);
                        backpatch($8->trueList, $13); // Backpatch to M3
                        backpatch($11->nextList, $7); // Backpatch to M1
                        backpatch($15->nextList, $9); // Backpatch to N
                        emit("goto", intToStr($9)); // goto
                        $$->nextList = $8->falseList;  // Copy false list
                        currentBlock = "";
                        switchActiveTable(activeSymbolTable->parent);
                    }
                    ;

// Augmented empty non-terminals
F   : { currentBlock = "FOR"; }
    ;
W   : { currentBlock = "WHILE"; }
    ;
D   : { currentBlock = "DO"; }
    ;
X   : { 
        string newSymbolTableName = activeSymbolTable->name + "." + currentBlock + "$" + to_string(symbolTableCount++); // Name the new table
        Symbol* symbolFound = activeSymbolTable->lookup(newSymbolTableName); // Find the symbol
        symbolFound->nestedTable = new SymbolTable(newSymbolTableName); // Create new symbol table
        symbolFound->name = newSymbolTableName; // Update name
        symbolFound->nestedTable->parent = activeSymbolTable; // Update parent
        symbolFound->type = new Type("block"); // Update type
        currentSymbol = symbolFound; // Update current symbol
    }
    ;
change_table    : {
                    // Switch to new symbol table, if it does not exist, create it
                    if (currentSymbol->nestedTable != NULL) {
                        switchActiveTable(currentSymbol->nestedTable); // Switch to nested table
                        emit("label", activeSymbolTable->name);
                    }
                    else switchActiveTable(new SymbolTable(""));
                }
                ;

jump_statement  : GOTO IDENTIFIER SEMICOLON {}
                | CONTINUE SEMICOLON { $$ = new Statement(); }
                | BREAK SEMICOLON { $$ = new Statement(); }
                | RETURN expression SEMICOLON {
                    $$ = new Statement();
                    emit("return", $2->addr->name); // return \$ 2->Array->name
                }
                | RETURN SEMICOLON {
                    $$ = new Statement();
                    emit("return", ""); // return
                }
                ;



translation_unit    : external_declaration {}
                    | translation_unit external_declaration {}
                    ;

external_declaration    : function_definition {}
                        | declaration {}
                        ;

function_definition : declaration_specifiers declarator declaration_list_opt change_table CURLY_BRACKET_OPEN block_item_list_opt CURLY_BRACKET_CLOSE {
                        activeSymbolTable->parent = globalSymbolTable;
                        symbolTableCount = 0;
                        switchActiveTable(globalSymbolTable);  // End of function, switch to global symbol table
                    }
                    ;

declaration_list_opt    : declaration_list {}
                        | {}
                        ;

declaration_list    : declaration {}
                    | declaration_list declaration {}
                    ;
%%

// ERROR
void yyerror(string s) {
    cout << "ERROR : " << s << endl;
    cout << "At line no.: " << yylineno << endl;
    cout << "Near : " << yytext << endl;
}