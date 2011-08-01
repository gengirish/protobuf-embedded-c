/*-----------------------------------------------------------------------+
 | edu.tum.cs.ccts.protobuf.embedded
 |                                                                       |
 |                                                                       |
 | Copyright (c)  2004-2011 Technische Universitaet Muenchen             |
 |                                                                       |
 | Technische Universitaet Muenchen               #########  ##########  |
 | Institut fuer Informatik - Lehrstuhl IV           ##  ##  ##  ##  ##  |
 | Prof. Dr. Dr. h.c. Manfred Broy                   ##  ##  ##  ##  ##  |
 | Boltzmannstr. 3                                   ##  ##  ##  ##  ##  |
 | 85748 Garching bei Muenchen                       ##  ##  ##  ##  ##  |
 | Germany                                           ##  ######  ##  ##  |
 +-----------------------------------------------------------------------*/

/**
 * A tree grammar that walks an Proto-language AST and checks syntactic and
 * semantic constraints.
 *
 * @author wolfgang.schwitzer
 * @author nvpopa
 */

tree grammar ConstraintChecker;

options {
	tokenVocab=Proto;
	ASTLabelType=CommonTree;
}

@header {
package edu.tum.cs.ccts.protobuf.embedded;

import java.util.HashSet;
import java.util.Arrays;
}

@members {
private HashSet<String> nameScope = new HashSet<String>();
private HashSet<Integer> valueScope = new HashSet<Integer>();
String[] types = { "int32", "bool", "string", "float" };
private final HashSet<String> dataTypes = new HashSet<String>(Arrays.asList(types));
private HashSet<String> globalNameScope = new HashSet<String>();
public int constraintErrors = 0;
protected void constraintError(int line, String msg) { 
  System.err.println("Error in line " + line + ": " + msg);
  constraintErrors++;
}
private HashSet<String> annotations = new HashSet<String>();

}

proto 
	:	^(PROTO packageDecl? importDecl* declaration*)
	;
                
packageDecl
	:	^(PACKAGE qualifiedID) 
	;

importDecl
	:	^(IMPORT STRING) 	
	;

declaration
	:	optionDecl 
	| enumDecl
	|	messageDecl
	|	annotationDecl
	;

optionDecl 
  : ^(OPTION ID STRING)  
  ;

enumDecl
  @init { nameScope.clear(); valueScope.clear(); }
	:	^(ENUM ID enumElement*)
	  {
	    dataTypes.add($ID.text);
	    if (globalNameScope.contains($ID.text))
		    constraintError($ID.line, "duplicate enum name " + $ID.text);
	    globalNameScope.add($ID.text);
	  }
	;

enumElement
	:	^(ASSIGN ID INTEGER)
		{
		  int index = Integer.parseInt($INTEGER.text);
		  if (index < 0 || index > 127)
		    constraintError($INTEGER.line, "enum element " + index + " out of valid range [0..127]");
		  if (nameScope.contains($ID.text))
		    constraintError($ID.line, "duplicate element name " + $ID.text);
		  nameScope.add($ID.text);
		  if (valueScope.contains(index))
		    constraintError($INTEGER.line, "duplicate element value " + index);
		  valueScope.add(index);
		}
	;

messageDecl
  @init { nameScope.clear(); valueScope.clear(); }
	:	^(MESSAGE ID messageElement*)
		{
		  if (globalNameScope.contains($ID.text))
        constraintError($ID.line, "duplicate message name " + $ID.text);
      globalNameScope.add($ID.text);
		}
	;

annotationDecl
	:	^(ANNOTATION ID INTEGER)
		{
			if (!globalNameScope.isEmpty())
				constraintError($ID.line, "cannot use annotations after message/enum declarations");
			String name = $ID.text;
			if (!name.equals("max_repeated_length") && !name.equals("max_string_length"))
				constraintError($ID.line, "unknown annotation " + name);
			if (annotations.contains(name))
				constraintError($ID.line, "duplicate annotation " + name);
			/* 
			 * 2^7 * 2^7 == 2^14 for "repated string".
			 * That's OK for size (maximum 2 byte varint), which has 14bit payload.
			 */
			int v = Integer.parseInt($INTEGER.text);
			if (v < 2 || v > 127)
				constraintError($ID.line, name + " must be within [2..127], but was " + v);
			annotations.add(name);
		}
	;

messageElement
	:	^(ASSIGN MODIFIER (t=TYPE | t=ID) n=ID INTEGER )
	   {
	     int tag = Integer.parseInt($INTEGER.text);
	     if (tag <= 0 || tag > 4095)
	       constraintError($INTEGER.line, "tag: " + tag + " out of valid range [1..4095]");
	     if (nameScope.contains($n.text))
         constraintError($n.line, "duplicate element name " + $n.text);
	     nameScope.add($n.text);
	     if (valueScope.contains(tag))
         constraintError($INTEGER.line, "duplicate tag value " + tag);
       valueScope.add(tag);
       if (!dataTypes.contains($t.text))
         constraintError($t.line, "unsupported data type: " + $t.text + "\nData types must be natives or enums ");
	   }
	;

qualifiedID
	:	(i+=ID)+
	;
