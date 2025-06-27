#include <bits/stdc++.h>

using namespace std;

/* Sizes for data types */
#define SIZE_VOID 0
#define SIZE_CHAR 1
#define SIZE_INT 4
#define SIZE_FLOAT 8
#define SIZE_POINTER 4

/* Forward declarations */
class Symbol;          // Symbol Table Record
class Type;            // Type of a symbol
class SymbolTable;     // Symbol Table
class Quad;            // Quad to store TAC
class QuadArray;       // Array of Quads

/* Global Variables */
extern Symbol* currentSymbol;               // Points to the current symbol
extern SymbolTable* activeSymbolTable;      // Points to the currently active symbol table
extern SymbolTable* globalSymbolTable;      // Points to the global symbol table
extern QuadArray quadTable;                 // Points to the quad array
extern int symbolTableCount;                // Counts number of symbol tables
extern string currentBlock;                 // Current block name

/* Lexical objects */
extern int yyparse();
extern char* yytext;

class Type {
public:
    string base;      // Base type, e.g., "int"
    int width;        // Width, for arrays or pointers
    Type* subtype;    // Subtype for arrays/pointers

    Type(string base, Type* subtype = nullptr, int width = 0); // Constructor
    string toString() const; // Returns a string representation of the type
};

class Symbol {
public:
    string name;           // Symbol name
    Type* type;            // Symbol type
    string initValue;    // Initial value, if any
    int size;              // Size in bytes
    int offset;            // Offset in memory
    SymbolTable* nestedTable; // Nested symbol table for functions or structs

    Symbol(string name, string baseType = "int", Type* subtype = nullptr, int width = 0); // Constructor
    Symbol* update(Type* newType); // Update symbol type
};

struct SymbolNode {
    Symbol symbol;           // Symbol data
    SymbolNode* next;        // Pointer to the next node in the list

    SymbolNode(const Symbol& sym); // Constructor
};

class SymbolTable {
public:
    string name;              // Name of the symbol table
    int symbolCount;               // Number of symbols in the table
    SymbolNode* head;              // Pointer to the head of the linked list
    SymbolTable* parent;           // Pointer to the parent symbol table

    SymbolTable(string name = "");  // Constructor
    Symbol* lookup(const string& name); // Look up a symbol by name
    static Symbol* createTemp(Type* type, const string& initValue = ""); // Create a temporary symbol
    void updateOffsets();          // Update offsets for symbols
    void printTable();             // Print the symbol table
    ~SymbolTable();                // Destructor to free memory
};

class Quad {
public:
    string op;       // Operation code (e.g., "+", "=")
    string arg1;            // First argument
    string arg2;            // Second argument
    string result;          // Result

    Quad(string res, string arg1_, string op = "=", string arg2_ = ""); // Constructor with string args
    Quad(string res, int arg1_, string op = "=", string arg2_ = "");    // Constructor with int arg
    Quad(string res, float arg1_, string op = "=", string arg2_ = "");  // Constructor with float arg
    void printQuad();       // Print the quad
};

class QuadArray {
public:
    vector<Quad> quads;     // Vector of quads
    void printQuads();      // Print all quads
};

// Emit functions for adding new quads
void emit(string op, string result, string arg1 = "", string arg2 = "");
void emit(string op, string result, int arg1, string arg2 = "");
void emit(string op, string result, float arg1, string arg2 = "");

// Array and pointer management classes
class Array {
public:
    string arrType;        // "array" or "pointer"
    Symbol* addr;   // Base address in the symbol table
    Symbol* location;      // Address of the array
    Type* type;            // Type of the array elements
};

// Statement management for next-list handling
class Statement {
public:
    list<int> nextList;    // List of next instructions
};

// Expression management for true/false-lists
class Expression {
public:
    string exprType;       // Expression type ("bool" or other)
    Symbol* addr;          // Base address of the expression in symbol table
    list<int> trueList;    // List of true branch instructions
    list<int> falseList;   // List of false branch instructions
    list<int> nextList;    // List of next instructions
};

/* Helper functions */
list<int> makelist(int i); // Create a new list with one element
list<int> merge(list<int>& list1, list<int>& list2); // Merge two lists
void backpatch(list<int> l, int i); // Backpatch list with an address
bool typecheck(Symbol* &s1, Symbol* &s2); // Check if two symbols are compatible
bool typecheck(Type* t1, Type* t2); // Check if types t1 and t2 are compatible (called by typecheck(symbol, symbol) to check types of symbols and compatible types)
Symbol* convType(Symbol* s, const string t);  // Convert type of symbol s to t, which calls
string intToStr(int n); // Convert int to string
string floatTostr(float f); // Convert float to string
Expression* intToBool(Expression* e); // Convert int expression to bool
Expression* boolToInt(Expression* e); // Convert bool expression to int
void switchActiveTable(SymbolTable* newTable); // Switch to a new symbol table
int nextinstr(); // Get index of the next instruction
int getSize(Type* t); // Get the size of a given type
string displayType(Type* t); // Display the type as a string