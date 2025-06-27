#include "TinyC3_22CS30051_22CS30052_translator.h"
#include <iomanip>
using namespace std;

// Global variables defined in header
Symbol* currentSymbol = nullptr;
SymbolTable* activeSymbolTable = nullptr;
SymbolTable* globalSymbolTable = nullptr;
QuadArray quadTable;
int symbolTableCount = 0;
string currentBlock;

// Type class implementation
Type::Type(string base, Type* subtype, int width)
    : base(base), width(width), subtype(subtype) {}

string Type::toString() const {
    if (subtype) {
        if (base == "arr")
            return "array(" + to_string(width) + ", " + subtype->toString() + ")";
        if (base == "ptr")
            return "ptr(" + subtype->toString() + ")";
    }
    return base;
}

// Symbol class implementation
Symbol::Symbol(string name, string base, Type* subtype, int width)
    : name(name), initValue("null"), offset(0), nestedTable(nullptr) {
    type = new Type(base, subtype, width);
    size = getSize(type);
}

Symbol* Symbol::update(Type* newType) {
    type = newType;
    size = getSize(newType);
    return this;
}

// SymbolNode struct constructor
SymbolNode::SymbolNode(const Symbol& sym) : symbol(sym), next(nullptr) {}

// SymbolTable class with linked list
SymbolTable::SymbolTable(string name)
    : name(name), symbolCount(0), head(nullptr), parent(nullptr) {}

Symbol* SymbolTable::lookup(const string& name) {
    // Step 1: Check the current symbol table
    SymbolNode* current = head;
    while (current) {
        if (current->symbol.name == name) {
            return &(current->symbol);  // Found in current table
        }
        current = current->next;
    }

    // Step 2: If not found, recursively check in parent table
    Symbol* foundSymbol = nullptr;
    if (parent) {
        foundSymbol = parent->lookup(name);
    }

    // Step 3: If still not found and we are in the active symbol table, create a new symbol
    if (activeSymbolTable == this && foundSymbol == nullptr) {
        Symbol* newSymbol = new Symbol(name); // Create a new symbol
        SymbolNode* newNode = new SymbolNode(*newSymbol); // Create a new node with the symbol
        
        // Insert at the head of the list in the current table
        newNode->next = head;
        head = newNode;
        
        return &(newNode->symbol); // Return the newly added symbol
    }
    
    // Return symbol if found in parent table or nullptr if not found
    return foundSymbol;
}


Symbol* SymbolTable::createTemp(Type* type, const string& initValue) {
    string name = "t" + intToStr(activeSymbolTable->symbolCount++);
    Symbol tempSymbol(name);
    tempSymbol.initValue = initValue;
    tempSymbol.type = type;

    SymbolNode* newNode = new SymbolNode(tempSymbol);
    newNode->next = activeSymbolTable->head;
    activeSymbolTable->head = newNode;
    return &(newNode->symbol);
}

void SymbolTable::updateOffsets() {
    int offset = 0;
    SymbolNode* current = head;
    while (current) {
        current->symbol.offset = offset;
        offset += current->symbol.size;
        if (current->symbol.nestedTable) {
            current->symbol.nestedTable->updateOffsets();
        }
        current = current->next;
    }
}

void SymbolTable::printTable() {
    cout << "Symbol Table: " << name << ", Parent: "
         << (parent ? parent->name : "None") << endl;

    SymbolNode* current = head;
    while (current) {
        cout << setw(15) << current->symbol.name << setw(20) << displayType(current->symbol.type)
             << setw(10) << current->symbol.initValue << setw(10) << current->symbol.size
             << setw(10) << current->symbol.offset << endl;
        if(current->symbol.nestedTable != NULL) current->symbol.nestedTable->printTable();
        current = current->next;
    }
}

SymbolTable::~SymbolTable() {
    SymbolNode* current = head;
    while (current) {
        SymbolNode* temp = current;
        current = current->next;
        delete temp;
    }
}

// Quad class implementation
Quad::Quad(string res, string arg1_, string op, string arg2_)
    : op(op), arg1(arg1_), arg2(arg2_), result(res) {}

Quad::Quad(string res, int arg1_, string op, string arg2_)
    : op(op), arg2(arg2_), result(res) {
    arg1 = intToStr(arg1_);
}

Quad::Quad(string res, float arg1_, string op, string arg2_)
    : op(op), arg2(arg2_), result(res) {
    arg1 = floatTostr(arg1_);
}

void Quad::printQuad() {
    if (op == "=")
        cout << result << " = " << arg1;
    else if (op == "=*")
        cout << "*" << result << " = " << arg1;
    else if (op == "[]=")
        cout << result << "[" << arg1 << "] = " << arg2;
    else if (op == "=[]")
        cout << result << " = " << arg1 << "[" << arg2 << "]";
    else if (op == "goto" || op == "param" || op == "return")
        cout << op << " " << result;
    else if (op == "call")
        cout << result << " = call " << arg1 << ", " << arg2;
    else if (op == "label")
        cout << result << ": ";
    else if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%" ||
             op == "^" || op == "|" || op == "&" || op == "<<" || op == ">>")
        cout << result << " = " << arg1 << " " << op << " " << arg2;
    else if (op == "==" || op == "!=" || op == "<" || op == ">" ||
             op == "<=" || op == ">=")
        cout << "if " << arg1 << " " << op << " " << arg2 << " goto " << result;
    else if(op == "/=" || op == "*=" || op == "-=" || op == "+="|| op == "!=" || op == "^=" || op == "|=" || op == "&=" || op == "<<=" || op == ">>=")
        cout << result << " = " << result << ' ' << op[0] << ' ' << arg1;
    else if(op == "= +" || op == "= -" || op == "= &" || op == "= *" || op == "= ~" || op == "= !")
        cout << result << ' ' << op << ' ' << arg1;
    else{
        cout << "op = " << op << endl;
        cout << "Unknown operator\n";
    }

}

// QuadArray class implementation
void QuadArray::printQuads() {
    cout << "THREE ADDRESS CODE (TAC):" << endl;
    int cnt = 0;
    for (auto& q : quads) {
        if (q.op != "label") {
            cout << setw(4) << cnt << ": ";
            q.printQuad();
        } else {
            cout << endl << setw(4) << cnt << ": ";
            q.printQuad();
        }
        cout << endl;
        cnt++;
    }
}

// Emit functions to add new quads to the quad array
void emit(string op, string result, string arg1, string arg2) {
    quadTable.quads.emplace_back(result, arg1, op, arg2);
}

void emit(string op, string result, int arg1, string arg2) {
    quadTable.quads.emplace_back(result, arg1, op, arg2);
}

void emit(string op, string result, float arg1, string arg2) {
    quadTable.quads.emplace_back(result, arg1, op, arg2);
}

// Helper functions for type conversion and backpatching
list<int> makelist(int i) {
    return list<int>(1, i);
}

list<int> merge(list<int>& list1, list<int>& list2) {
    list1.merge(list2);
    return list1;
}

void backpatch(list<int> patchList, int addr) {
    string strAddr = intToStr(addr);
    for (int index : patchList) {
        quadTable.quads[index].result = strAddr;
    }
}

// Implementation of the typecheck functions
bool typecheck(Symbol* &s1, Symbol* &s2) {
    Type* t1 = s1->type;
    Type* t2 = s2->type;

    if(typecheck(t1, t2))
        return true;
    else if(s1 == convType(s1, t2->base))
        return true;
    else if(s2 == convType(s2, t1->base))
        return true;
    else
        return false;
}

bool typecheck(Type* t1, Type* t2) {
    if(t1 == NULL && t2 == NULL)
        return true;
    else if(t1 == NULL || t2 == NULL)
        return false;
    else if(t1->base != t2->base)
        return false;

    return typecheck(t1->subtype, t2->subtype);
}

// Implementation of the convType function
Symbol* convType(Symbol* s, string t) {
    Symbol* temp = SymbolTable::createTemp(new Type(t));
    if(s->type->base == "float") {
        if(t == "int") {
            emit("=", temp->name, "float2int(" + s->name + ")");
            return temp;
        }
        else if(t == "char") {
            emit("=", temp->name, "float2char(" + s->name + ")");
            return temp;
        }
        return s;
    }
    else if(s->type->base == "int") {
        if(t == "float") {
            emit("=", temp->name, "int2float(" + s->name + ")");
            return temp;
        }
        else if(t == "char") {
            emit("=", temp->name, "int2char(" + s->name + ")");
            return temp;
        }
        return s;
    }
    else if(s->type->base == "char") {
        if(t == "float") {
            emit("=", temp->name, "char2float(" + s->name + ")");
            return temp;
        }
        else if(t == "int") {
            emit("=", temp->name, "char2int(" + s->name + ")");
            return temp;
        }
        return s;
    }
    return s;
}

string intToStr(int n) {
    return to_string(n);
}

string floatTostr(float f) {
    return to_string(f);
}

Expression* intToBool(Expression* expr) {
    if (expr->exprType != "bool") {
        expr->falseList = makelist(nextinstr());
        emit("==", expr->addr->name, "0");
        expr->trueList = makelist(nextinstr());
        emit("goto", "");
    }
    return expr;
}

Expression* boolToInt(Expression* expr) {
    if (expr->exprType == "bool") {
        expr->addr = SymbolTable::createTemp(new Type("int"));
        backpatch(expr->trueList, nextinstr());
        emit("=", expr->addr->name, "true");
        emit("goto", intToStr(nextinstr() + 1));
        backpatch(expr->falseList, nextinstr());
        emit("=", expr->addr->name, "false");
    }
    return expr;
}

void switchActiveTable(SymbolTable* newTable) {
    activeSymbolTable = newTable;
}

int nextinstr() {
    return quadTable.quads.size();
}

int getSize(Type* type) {
    if (type->base == "void") return SIZE_VOID;
    if (type->base == "char") return SIZE_CHAR;
    if (type->base == "int") return SIZE_INT;
    if (type->base == "ptr") return SIZE_POINTER;
    if (type->base == "float") return SIZE_FLOAT;
    if (type->base == "arr") return type->width * getSize(type->subtype);
    return -1;
}

string displayType(Type* type) {
    if (!type) return "null";
    if (type->base == "ptr") return "ptr(" + displayType(type->subtype) + ")";
    if (type->base == "arr") return "arr(" + intToStr(type->width) + ", " + displayType(type->subtype) + ")";
    return type->base;
}

int main() {
    symbolTableCount = 0;
    globalSymbolTable = new SymbolTable("Global");
    activeSymbolTable = globalSymbolTable;
    currentBlock = "";
    yyparse();
    globalSymbolTable->updateOffsets();
    quadTable.printQuads();
    cout << endl;
    globalSymbolTable->printTable();
    
    return 0;
}
