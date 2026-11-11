module lang::objectilang::AST

/*
 * Objectilang - sintaxis abstracta (AST)
 *
 * Los nombres de los constructores coinciden con las etiquetas de las
 * producciones de Syntax.rsc, que es lo que necesita implode().
 * Los ADT llevan prefijo "A" para no chocar con los no-terminales.
 *
 * Convencion: las partes opcionales de la gramatica (X?) se representan
 * como list[X] con 0 o 1 elemento.
 */

data AProgram
  = program(list[AStatement] statements)
  ;

data AStatement
  = objectStmt(AObjectDef objDef)
  | methodStmt(AMethodDef mDef)
  | valDecl(str name, list[ATypeAnn] annotation, AExpression expr)
  | varDecl(str name, list[ATypeAnn] annotation, AExpression expr)
  | forEach(str loopVar, str generator, AInvocation iterable, AStatement body)
  | forEachTuple(list[str] loopVars, str generator, AInvocation iterable, AStatement body)
  | forRange(str loopVar, AExpression initial, AExpression cond, str stepVar, AStatement body)
  | exprStmt(AExpression expr)
  | emptyStmt()
  ;

data ABlock
  = block(list[AStatement] statements)
  ;

data AObjectDef
  = objectDef(str name, list[AExtension] parent, list[ATypeParams] tparams,
              list[AParams] parameters, list[ABlock] body)
  ;

data AExtension
  = extension(str parentName)
  ;

data AMethodDef
  = methodAssign(str objName, list[str] path, AParams requiredParameters,
                 list[ATypeAnn] returnType, ABlock body)
  | methodDecl(str objName, list[str] path, AParams requiredParameters,
               list[ATypeAnn] returnType)                  // sin cuerpo (abstracto)
  | methodDef(list[str] name, list[AParams] parameters,
              list[ATypeAnn] returnType, ABlock body)
  | overrideDef(list[str] name, list[AParams] parameters,
                list[ATypeAnn] returnType, ABlock body)
  ;

data AObjectBody
  = objectBody(list[AMethodDef] methods)
  ;

data AParams
  = params(list[AParam] items)
  ;

data AParam
  = param(str name, ATypeExpr typ)
  | valParam(str name, ATypeExpr typ)
  ;

data ATypeParams
  = typeParams(list[ATypeParam] items)
  ;

data ATypeParam
  = invariant(str name)
  | covariant(str name)
  | contravariant(str name)
  ;

data ATypeArgs
  = typeArgs(list[ATypeExpr] items)
  ;

data ATypeAnn
  = typeAnn(ATypeExpr typ)
  ;

data ATypeExpr
  = simpleType(str name)
  | genericType(str name, ATypeArgs targs)
  ;

data AInvocation
  = invocation(list[str] path, list[ATypeArgs] targs, list[ACallArgs] args)
  ;

data ACallArgs
  = callArgs(list[AExpression] args)
  ;

// Cadenas: el texto conserva las comillas y los delimitadores ${ }
data AStringLit
  = plain(str text)
  | templateStr(str prefix, AStringTail tail)
  ;

data AStringTail
  = tailEnd(AExpression expr, str suffix)
  | tailMore(AExpression expr, str middle, AStringTail rest)
  ;

data AExpression
  = intLit(int n)
  | floatLit(real r)
  | charLit(str c)
  | stringLit(AStringLit text)
  | trueLit()
  | falseLit()
  | callExpr(AInvocation call)
  | newObject(str className, list[ATypeArgs] targs, list[ACallArgs] args,
              list[AObjectBody] body)
  | blockExpr(ABlock blk)
  | printExpr(list[AExpression] arg)
  | printlnExpr(list[AExpression] arg)
  | ifExpr(AExpression cond, AExpression thenExpr, AExpression elseExpr)
  | negate(AExpression operand)
  | logicalNot(AExpression operand)
  | power(AExpression lhs, AExpression rhs)
  | multiply(AExpression lhs, AExpression rhs)
  | divide(AExpression lhs, AExpression rhs)
  | modulo(AExpression lhs, AExpression rhs)
  | add(AExpression lhs, AExpression rhs)
  | subtract(AExpression lhs, AExpression rhs)
  | lessThan(AExpression lhs, AExpression rhs)
  | greaterThan(AExpression lhs, AExpression rhs)
  | lessEq(AExpression lhs, AExpression rhs)
  | greaterEq(AExpression lhs, AExpression rhs)
  | notEqual(AExpression lhs, AExpression rhs)
  | equals(AExpression lhs, AExpression rhs)
  | andExpr(AExpression lhs, AExpression rhs)
  | orExpr(AExpression lhs, AExpression rhs)
  ;
